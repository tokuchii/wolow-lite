"""
WOLOW Lite PC Agent
====================
Lightweight HTTP server that runs on the target PC and executes remote commands.

Endpoints:
  POST /action    - Execute a command (JSON body: {"action": "...", "token": "..."})
  GET  /status    - Health check (no auth required)

UDP Discovery:
  Listens on UDP port 8221 for "WOLOW_DISCOVER" packets.
  Responds with JSON: {"hostname": "...", "port": 8220, "platform": "..."}

Actions: reboot, shutdown, sleep, hibernate, lock
"""

import json
import logging
import platform
import socket
import threading
from functools import wraps

from flask import Flask, jsonify, request

from actions import get_status, get_mac_address, hibernate, lock, reboot, shutdown, sleep
from config import load_config

cfg = load_config()
app = Flask(__name__)

logging.basicConfig(
    level=getattr(logging, cfg["logging"]["level"].upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("wolow-agent")

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


def require_token(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        data = request.get_json(silent=True) or {}
        token = data.get("token", "")
        if token != EXPECTED_TOKEN:
            log.warning("Unauthorized request from %s", request.remote_addr)
            return jsonify({"ok": False, "error": "unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated


@app.route("/status", methods=["GET"])
def status():
    result = get_status()
    result["token"] = EXPECTED_TOKEN
    return jsonify(result)


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

if __name__ == "__main__":
    host = cfg["server"]["host"]
    port = cfg["server"]["port"]

    # Start UDP discovery in background thread
    disc_thread = threading.Thread(target=_discovery_listener, daemon=True)
    disc_thread.start()

    log.info("Starting WOLOW agent on %s:%d", host, port)
    log.info("Token: %s...%s", EXPECTED_TOKEN[:4], EXPECTED_TOKEN[-4:])
    app.run(host=host, port=port, debug=False)
