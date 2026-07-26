"""
WOLOW Lite PC Agent
====================
Lightweight HTTP server that runs on the target PC and executes remote commands.

Endpoints:
  POST /action     - Execute a command (JSON body: {"action": "...", "token": "..."})
  GET  /status     - Health check (no auth required)
  POST /register   - Register an app instance as the owner (requires token)
  POST /unregister - Unregister the owner (requires token + matching device_id)

UDP Discovery:
  Listens on UDP port 8221 for "WOLOW_DISCOVER" packets.
  Responds with its connection details and authentication token.

Actions: reboot, shutdown, sleep, hibernate, lock
"""

import json
import logging
import platform
import socket
import threading
from functools import wraps
from logging.handlers import RotatingFileHandler
from pathlib import Path

from flask import Flask, jsonify, request

from actions import (
    get_status, get_mac_address, hibernate, lock, reboot, shutdown, sleep,
    get_audio_devices, get_volume, set_volume, set_mute, set_default_audio_device,
)
from config import load_config

cfg = load_config()
app = Flask(__name__)

log = logging.getLogger("wolow-agent")
log.setLevel(getattr(logging, cfg["logging"]["level"].upper(), logging.INFO))
if not log.handlers:
    handler = RotatingFileHandler(
        Path(__file__).with_name("wolow-agent.log"), maxBytes=1_000_000, backupCount=3
    )
    handler.setFormatter(logging.Formatter(
        "%(asctime)s [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
    ))
    log.addHandler(handler)

EXPECTED_TOKEN = cfg["server"]["token"]
HTTP_PORT = cfg["server"]["port"]
DISCOVER_PORT = 8221

VALID_ACTIONS = {"reboot", "shutdown", "sleep", "hibernate", "lock"}

ACTION_MAP = {
    "reboot": reboot,
    "shutdown": shutdown,
    "sleep": sleep,
    "hibernate": hibernate,
    "lock": lock,
}

# ---------------------------------------------------------------------------
# Owner persistence
# ---------------------------------------------------------------------------

OWNER_FILE = Path(__file__).parent / "owner.json"
_owner_lock = threading.Lock()


def _load_owner() -> dict | None:
    """Load the current owner from disk. Returns None if no owner."""
    if not OWNER_FILE.exists():
        return None
    try:
        with open(OWNER_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def _save_owner(device_id: str, device_name: str):
    """Persist the owner to disk."""
    with _owner_lock:
        with open(OWNER_FILE, "w") as f:
            json.dump({"device_id": device_id, "device_name": device_name}, f)
    log.info("Owner registered: %s (%s)", device_id, device_name)


def _clear_owner():
    """Remove the owner file."""
    with _owner_lock:
        if OWNER_FILE.exists():
            OWNER_FILE.unlink()
    log.info("Owner cleared")


def require_token(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        # Check JSON body first, then X-Token header, then query param
        data = request.get_json(silent=True) or {}
        token = data.get("token", "")
        if not token:
            token = request.headers.get("X-Token", "")
        if not token:
            token = request.args.get("token", "")
        if token != EXPECTED_TOKEN:
            log.warning("Unauthorized request from %s", request.remote_addr)
            return jsonify({"ok": False, "error": "unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated


@app.route("/status", methods=["GET"])
def status():
    result = get_status()
    result["token"] = EXPECTED_TOKEN
    owner = _load_owner()
    if owner:
        result["owner_device_id"] = owner["device_id"]
        result["owner_device_name"] = owner["device_name"]
    return jsonify(result)


@app.route("/register", methods=["POST"])
@require_token
def register():
    data = request.get_json(silent=True) or {}
    device_id = data.get("device_id", "").strip()
    device_name = data.get("device_name", "").strip()

    if not device_id:
        return jsonify({"ok": False, "error": "device_id is required"}), 400

    owner = _load_owner()
    if owner and owner["device_id"] != device_id:
        log.warning(
            "Registration rejected: device %s tried to claim, but %s already owns",
            device_id, owner["device_id"],
        )
        return jsonify({
            "ok": False,
            "error": "already_registered",
            "owner_device_name": owner["device_name"],
        }), 409

    _save_owner(device_id, device_name or device_id)
    return jsonify({"ok": True})


@app.route("/unregister", methods=["POST"])
@require_token
def unregister():
    data = request.get_json(silent=True) or {}
    device_id = data.get("device_id", "").strip()

    if not device_id:
        return jsonify({"ok": False, "error": "device_id is required"}), 400

    owner = _load_owner()
    if owner and owner["device_id"] != device_id:
        return jsonify({
            "ok": False,
            "error": "only_owner_can_unregister",
            "owner_device_name": owner["device_name"],
        }), 403

    _clear_owner()
    return jsonify({"ok": True})


@app.route("/action", methods=["POST"])
@require_token
def do_action():
    data = request.get_json(silent=True) or {}
    action = data.get("action", "")

    if action not in VALID_ACTIONS:
        return jsonify({"ok": False, "error": f"invalid action: {action}"}), 400

    log.info("Action '%s' requested by %s", action, request.remote_addr)
    try:
        result = ACTION_MAP[action]()
        return jsonify(result)
    except Exception as e:
        log.error("Action '%s' failed: %s", action, e)
        return jsonify({"ok": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Audio Control
# ---------------------------------------------------------------------------

@app.route("/audio-devices", methods=["GET"])
@require_token
def audio_devices():
    log.info("Audio devices request from %s", request.remote_addr)
    result = get_audio_devices()
    log.info("Audio devices: %d found", len(result.get("devices", [])))
    return jsonify(result)


@app.route("/volume", methods=["GET", "POST"])
@require_token
def volume():
    log.info("Volume %s from %s", request.method, request.remote_addr)
    if request.method == "GET":
        device_id = request.args.get("device_id", "")
        result = get_volume(device_id)
        log.info("Volume result: %s", result)
        return jsonify(result)
    data = request.get_json(silent=True) or {}
    level = data.get("level")
    device_id = data.get("device_id", "")
    muted = data.get("muted")
    if muted is not None:
        result = set_mute(bool(muted), device_id)
        log.info("Set mute to %s: %s", muted, result)
        return jsonify(result)
    if level is None:
        return jsonify({"ok": False, "error": "level is required"}), 400
    try:
        level = int(level)
    except (ValueError, TypeError):
        return jsonify({"ok": False, "error": "level must be an integer"}), 400
    result = set_volume(level, device_id)
    log.info("Set volume to %s: %s", level, result)
    return jsonify(result)


@app.route("/audio-device", methods=["POST"])
@require_token
def switch_audio_device():
    data = request.get_json(silent=True) or {}
    device_id = data.get("device_id", "").strip()
    if not device_id:
        return jsonify({"ok": False, "error": "device_id is required"}), 400
    return jsonify(set_default_audio_device(device_id))


# ---------------------------------------------------------------------------
# UDP Discovery Listener
# ---------------------------------------------------------------------------

def _discovery_listener():
    """Listen for WOLOW_DISCOVER broadcast packets and respond with agent info."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.settimeout(1.0)
    try:
        sock.bind(("0.0.0.0", DISCOVER_PORT))
    except OSError as e:
        log.warning("Discovery port %d unavailable: %s", DISCOVER_PORT, e)
        return

    log.info("Discovery listener active on UDP %d", DISCOVER_PORT)

    while True:
        try:
            data, addr = sock.recvfrom(1024)
            message = data.decode("utf-8", errors="ignore").strip()
            if message == "WOLOW_DISCOVER":
                response = json.dumps({
                    "ok": True,
                    "hostname": platform.node(),
                    "platform": platform.system(),
                    "mac": get_mac_address(),
                    "port": HTTP_PORT,
                    "token": EXPECTED_TOKEN,
                })
                sock.sendto(response.encode("utf-8"), addr)
                log.info("Discovery response sent to %s:%d", addr[0], addr[1])
        except socket.timeout:
            continue
        except Exception as e:
            log.error("Discovery error: %s", e)
            break

    sock.close()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    host = cfg["server"]["host"]
    port = cfg["server"]["port"]

    # Start UDP discovery in background thread
    disc_thread = threading.Thread(target=_discovery_listener, daemon=True)
    disc_thread.start()

    log.info("Starting WOLOW agent on %s:%d", host, port)
    app.run(host=host, port=port, debug=False)


if __name__ == "__main__":
    main()
