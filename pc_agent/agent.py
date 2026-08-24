"""
WOLOW Lite PC Agent
====================
Lightweight HTTP server that runs on the target PC and executes remote commands.

Endpoints:
  POST /action      - Execute a command (JSON body: {"action": "...", "token": "..."})
  GET  /status      - Health check (no auth required)
  POST /register    - Register an app instance as the owner (requires token)
  POST /unregister  - Unregister the owner (requires token + matching device_id)
  GET  /stats       - System stats: CPU, RAM, disk (requires token)
  GET  /processes   - Running processes sorted by CPU (requires token)
  POST /media       - Send media key: play_pause, next, prev, stop, vol_up, vol_down, mute

UDP Discovery:
  Listens on UDP port 8221 for "WOLOW_DISCOVER" packets.
  Responds with its connection details and authentication token.

Actions: reboot, shutdown, sleep, hibernate, lock
"""

import json
import logging
import os
import platform
import socket
import subprocess
import threading
import urllib.parse
from functools import wraps
from logging.handlers import RotatingFileHandler
from pathlib import Path

from flask import Flask, jsonify, request, send_file
from flask_cors import CORS

from actions import (
    get_status, get_mac_address, hibernate, lock, reboot, shutdown, sleep,
    get_audio_devices, get_volume, set_volume, set_mute, set_default_audio_device,
    get_system_stats, get_processes, send_media_key,
    get_installed_apps, launch_app, get_app_icon_png,
)
from config import load_config

cfg = load_config()
app = Flask(__name__)
CORS(app)

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
# System Stats
# ---------------------------------------------------------------------------

@app.route("/stats", methods=["GET"])
@require_token
def stats():
    log.info("Stats request from %s", request.remote_addr)
    result = get_system_stats()
    return jsonify(result)


# ---------------------------------------------------------------------------
# Running Processes
# ---------------------------------------------------------------------------

@app.route("/processes", methods=["GET"])
@require_token
def processes():
    log.info("Processes request from %s", request.remote_addr)
    limit = request.args.get("limit", 15, type=int)
    result = get_processes(limit)
    return jsonify(result)


# ---------------------------------------------------------------------------
# Media Controls
# ---------------------------------------------------------------------------

VALID_MEDIA_KEYS = {"play_pause", "next", "prev", "stop", "vol_up", "vol_down", "mute"}

@app.route("/media", methods=["POST"])
@require_token
def media():
    data = request.get_json(silent=True) or {}
    key = data.get("key", "")
    if key not in VALID_MEDIA_KEYS:
        return jsonify({"ok": False, "error": f"invalid media key: {key}"}), 400
    log.info("Media key '%s' from %s", key, request.remote_addr)
    result = send_media_key(key)
    return jsonify(result)


# ---------------------------------------------------------------------------
# Installed Apps
# ---------------------------------------------------------------------------

@app.route("/apps", methods=["GET"])
@require_token
def apps():
    log.info("Apps request from %s", request.remote_addr)
    result = get_installed_apps()
    base = f"http://{request.host}"
    for a in result.get("apps", []):
        path = a.get("path", "")
        if path:
            a["icon_url"] = (
                f"{base}/apps/icon?path={urllib.parse.quote(path)}"
                f"&token={EXPECTED_TOKEN}"
            )
    return jsonify(result)


@app.route("/apps/launch", methods=["POST"])
@require_token
def launch():
    data = request.get_json(silent=True) or {}
    path = data.get("path", "").strip()
    if not path:
        return jsonify({"ok": False, "error": "path is required"}), 400
    log.info("Launch app: %s from %s", path, request.remote_addr)
    result = launch_app(path)
    return jsonify(result)


@app.route("/apps/open", methods=["POST"])
@require_token
def open_app_by_name():
    """Find an installed app by name (fuzzy match) and launch it."""
    data = request.get_json(silent=True) or {}
    name = data.get("name", "").strip()
    if not name:
        return jsonify({"ok": False, "error": "name is required"}), 400
    return _find_and_launch(name)


@app.route("/apps/icon", methods=["GET"])
@require_token
def app_icon():
    """Return the app's icon as a PNG image."""
    app_path = request.args.get("path", "").strip()
    if not app_path:
        return jsonify({"ok": False, "error": "path is required"}), 400

    log.info("[ICON] Request for: %s", app_path)
    try:
        png_bytes = get_app_icon_png(app_path)
        if png_bytes:
            log.info("[ICON] Returning %d bytes", len(png_bytes))
            return app.response_class(
                png_bytes,
                mimetype="image/png",
                headers={"Cache-Control": "public, max-age=86400"},
            )
        log.info("[ICON] No icon found")
        return "", 204
    except Exception as e:
        log.error("[ICON] Error: %s", e)
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/command", methods=["POST"])
@require_token
def voice_command():
    """Parse natural language voice command and execute it.

    Expects: { "text": "open chrome" }
    Parses "open <app>" pattern, strips filler words, fuzzy-matches against
    installed apps using rapidfuzz, and launches the best match.
    """
    import re

    # --- Log raw request body BEFORE any parsing ---
    raw_body = request.get_data(as_text=True)
    log.info("[COMMAND] Raw request body: %s", raw_body)

    data = request.get_json(silent=True) or {}
    raw_text = data.get("text", "").strip()
    if not raw_text:
        log.warning("[COMMAND] No 'text' field in request")
        return jsonify({"status": "error", "error": "text is required"}), 400

    log.info("[COMMAND] Received text: '%s' from %s", raw_text, request.remote_addr)

    # --- NLP Parsing (with logging at each step) ---
    text = raw_text.lower().strip()
    log.info("[PARSE] After lowercase: '%s'", text)

    # Remove punctuation
    text = re.sub(r'[^\w\s]', '', text)
    log.info("[PARSE] After punctuation strip: '%s'", text)

    # Strip filler words
    fillers = [
        'please', 'can you', 'could you', 'would you',
        'hey', 'ok', 'okay', 'the', 'app', 'application',
        'program', 'for me', 'now', 'right now',
    ]
    for filler in fillers:
        text = re.sub(r'\b' + re.escape(filler) + r'\b', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    log.info("[PARSE] After filler removal: '%s'", text)

    # Extract app name from command patterns
    cmd_pattern = re.compile(r'^(?:open|launch|start|run)\s+(.+)$')
    match = cmd_pattern.match(text)
    if match:
        app_query = match.group(1).strip()
        log.info("[PARSE] Regex extracted app: '%s'", app_query)
    else:
        # No command verb — try the whole input as app name
        app_query = text
        log.info("[PARSE] No command verb found, using full text: '%s'", app_query)

    if not app_query:
        log.warning("[PARSE] Empty app query after parsing")
        return jsonify({
            "status": "error",
            "error": "Could not understand. Try saying 'open' followed by an app name.",
        }), 400

    # Check for constrained vocabulary (pinned apps from Flutter)
    constrain_to = data.get("constrain_to", [])
    if constrain_to:
        log.info("[COMMAND] Constrained to %d apps: %s", len(constrain_to), constrain_to)

    log.info("[COMMAND] Final app query: '%s' -> calling _find_and_launch", app_query)
    return _find_and_launch(app_query, constrain_to=constrain_to)


# --- App registry cache (rebuilt on startup, refreshable) ---
# Mapping: lowercase name -> list of app entries (dicts). Multiple entries
# allowed for the same display name (Start Menu + registry + UWP).
_app_registry = {}  # lowercase name -> [ {"name": str, "path": str, "source": str}, ... ]
_registry_lock = threading.Lock()


def _select_best_app_for_name(name: str):
    """Return the best app entry for a given lowercase registry name.

    Preference order:
      1. entry with path that exists on disk (file or folder)
      2. entry whose path ends with common executable extensions (.lnk, .exe, .appref-ms)
      3. source preference: startmenu > registry > uwp > others
      4. fallback: first entry
    """
    with _registry_lock:
        candidates = _app_registry.get(name, [])
    if not candidates:
        return None

    # Helper predicates
    def exists_on_disk(e):
        p = e.get("path", "")
        return bool(p) and os.path.exists(p)

    def has_exec_ext(e):
        p = e.get("path", "").lower()
        return any(p.endswith(ext) for ext in ('.lnk', '.exe', '.appref-ms', '.msi', '.bat', '.cmd'))

    # 1. Prefer existing path
    for e in candidates:
        if exists_on_disk(e):
            return e

    # 2. Prefer executable-looking path
    for e in candidates:
        if has_exec_ext(e):
            return e

    # 3. Source preference
    source_order = ['startmenu', 'registry', 'uwp']
    for src in source_order:
        for e in candidates:
            if (e.get('source') or '').lower() == src:
                return e

    # 4. Fallback
    return candidates[0]


def _build_app_registry():
    """Build the app registry from installed apps. Called at startup."""
    global _app_registry
    result = get_installed_apps()
    apps = result.get("apps", [])
    with _registry_lock:
        _app_registry = {}
        valid_count = 0
        for app in apps:
            key = app["name"].lower()
            _app_registry.setdefault(key, []).append(app)
            path = app.get("path", "")
            if path and os.path.exists(path):
                valid_count += 1
            elif path:
                log.warning("[REGISTRY] Path does not exist: %s -> %s", app["name"], path)
    log.info("[REGISTRY] Built: %d apps total, %d with valid paths", len(_app_registry), valid_count)


# Common aliases (spoken name -> canonical app name keywords)
_ALIASES = {
    "chrome": ["google chrome"],
    "google chrome": ["google chrome"],
    "firefox": ["mozilla firefox"],
    "edge": ["microsoft edge"],
    "word": ["microsoft word", "word"],
    "excel": ["microsoft excel", "excel"],
    "powerpoint": ["microsoft powerpoint", "powerpoint"],
    "outlook": ["microsoft outlook", "outlook"],
    "teams": ["microsoft teams", "teams"],
    "slack": ["slack"],
    "discord": ["discord"],
    "spotify": ["spotify"],
    "notepad": ["notepad", "notepad++"],
    "vscode": ["visual studio code", "vs code"],
    "vs code": ["visual studio code", "vs code"],
    "code": ["visual studio code", "vs code"],
    "terminal": ["windows terminal", "terminal", "powershell"],
    "cmd": ["command prompt", "cmd"],
    "explorer": ["file explorer", "explorer"],
    "photoshop": ["adobe photoshop", "photoshop"],
    "illustrator": ["adobe illustrator", "illustrator"],
    "premiere": ["adobe premiere", "premiere pro"],
    "zoom": ["zoom", "zoom workplace"],
    "steam": ["steam"],
    "epic": ["epic games launcher", "epic games"],
    "obs": ["obs studio", "obs"],
    "vlc": ["vlc media player", "vlc"],
    "paint": ["paint", "mspaint"],
    "calculator": ["calculator"],
    "settings": ["settings"],
    "store": ["microsoft store"],
}


def _find_and_launch(app_query: str, constrain_to: list = None):
    """Fuzzy-match app_query against registry and launch the best match.

    If constrain_to is provided, match ONLY against those app names first
    (much smaller set = much higher accuracy for voice commands).
    Falls back to full registry if no constrained match.
    """
    from rapidfuzz import fuzz, process as rf_process

    # Ensure registry is populated
    if not _app_registry:
        _build_app_registry()

    query = app_query.lower().strip()
    log.info("[MATCH] Query: '%s'", query)

    # Expand query with aliases
    search_terms = [query]
    if query in _ALIASES:
        alias_expansion = _ALIASES[query]
        search_terms.extend(alias_expansion)
        log.info("[MATCH] Alias expansion: %s", alias_expansion)

    # Get all registry names
    with _registry_lock:
        registry_names = list(_app_registry.keys())

    log.info("[MATCH] Registry size: %d apps", len(registry_names))

    # Phase 1: Constrained matching (pinned apps — small set, high accuracy)
    if constrain_to:
        constrain_lower = [a.lower().strip() for a in constrain_to]
        # Also add alias expansions for constrained apps
        constrain_expanded = list(constrain_lower)
        for name in constrain_lower:
            if name in _ALIASES:
                constrain_expanded.extend([a.lower() for a in _ALIASES[name]])

        log.info("[MATCH] Constrained set (%d): %s", len(constrain_expanded), constrain_expanded)

        best_constrained = None
        best_constrained_score = 0
        for term in search_terms:
            results = rf_process.extract(term, constrain_expanded, scorer=fuzz.WRatio, limit=3)
            log.info("[MATCH] Constrained candidates for '%s': %s", term,
                     [(n, round(s)) for n, s, _ in results])
            for name, score, _ in results:
                if score > best_constrained_score:
                    best_constrained_score = score
                    best_constrained = name

        # Lower threshold for constrained matching (65 — tighter set)
        if best_constrained and best_constrained_score >= 65:
            # Find the actual registry entry
            app = _select_best_app_for_name(best_constrained)
            if app:
                app_path = app.get("path", "")
                # If path is empty, try launching by name using Windows start command
                if not app_path or not app_path.strip():
                    log.info("[MATCH] CONSTRAINED match: %s (score=%.0f) — path empty, trying 'start'",
                             app["name"], best_constrained_score)
                    try:
                        subprocess.Popen(
                            f'start "" "{app["name"]}"',
                            shell=True,
                            creationflags=subprocess.CREATE_NO_WINDOW | subprocess.DETACHED_PROCESS,
                        )
                        log.info("[LAUNCH] start command sent for '%s'", app["name"])
                        return jsonify({
                            "ok": True,
                            "status": "success",
                            "app": app["name"],
                            "app_name": app["name"],
                            "score": round(best_constrained_score),
                            "match_type": "constrained",
                        })
                    except Exception as e:
                        log.error("[LAUNCH] start command failed: %s", e)
                        return jsonify({
                            "ok": False,
                            "status": "error",
                            "error": f"Failed to launch {app['name']}: {e}",
                        }), 500
                log.info("[MATCH] CONSTRAINED match: %s (score=%.0f) -> %s",
                         app.get("name"), best_constrained_score, app_path)
                result = launch_app(app_path)
                log.info("[LAUNCH] Result: %s", result)
                if result.get("ok"):
                    return jsonify({
                        "ok": True,
                        "status": "success",
                        "app": app["name"],
                        "app_name": app["name"],
                        "score": round(best_constrained_score),
                        "match_type": "constrained",
                    })
                return jsonify({
                    "ok": False,
                    "status": "error",
                    "error": f"Failed to launch {app['name']}: {result.get('error', 'unknown')}",
                }), 500

        log.info("[MATCH] No constrained match (best score=%.0f), falling back to full registry",
                 best_constrained_score)

    if not registry_names:
        log.warning("[MATCH] Registry empty — no apps found")
        return jsonify({
            "status": "not_found",
            "error": "No apps found on this PC. Run setup.bat first.",
            "suggestions": [],
        }), 404

    # Phase 2: Full registry matching (fallback)
    best_match = None
    best_score = 0

    for term in search_terms:
        results = rf_process.extract(
            term,
            registry_names,
            scorer=fuzz.WRatio,
            limit=3,
        )
        log.info("[MATCH] Full registry candidates for '%s': %s", term,
                 [(name, round(score)) for name, score, _ in results])
        for name, score, _ in results:
            if score > best_score:
                best_score = score
                best_match = name

    log.info("[MATCH] Best full match: '%s' score=%.0f (threshold=60)", best_match, best_score)

    if best_match and best_score >= 60:
        app = _select_best_app_for_name(best_match)
        if app:
            app_path = app.get("path", "")
            # Special-case: common Steam games that are installed under Steam
            # Launch via steam://rungameid/<appid> when the app name matches known mapping
            STEAM_APP_IDS = {
                'dota 2': '570',
                'dota2': '570',
            }
            nm = app.get("name", "").lower()
            if (not app_path or not app_path.strip()) and nm in STEAM_APP_IDS:
                steam_uri = f'steam://rungameid/{STEAM_APP_IDS[nm]}'
                log.info("[LAUNCH] Detected Steam game '%s', launching URI %s", nm, steam_uri)
                try:
                    if platform.system() == 'Windows':
                        os.startfile(steam_uri)
                    elif platform.system() == 'Linux':
                        subprocess.Popen(["xdg-open", steam_uri], start_new_session=True)
                    else:
                        subprocess.Popen(["open", steam_uri])
                    return jsonify({"ok": True, "status": "success", "app": app.get("name"), "app_name": app.get("name"), "score": round(best_score), "match_type": "steam"})
                except Exception as e:
                    log.error("[LAUNCH] Steam URI launch failed: %s", e)
            # If path is empty, try launching by name using Windows start command
            if not app_path or not app_path.strip():
                log.info("[LAUNCH] Path empty for '%s', trying 'start %s'", app["name"], app["name"])
                try:
                    subprocess.Popen(
                        f'start "" "{app["name"]}"',
                        shell=True,
                        creationflags=subprocess.CREATE_NO_WINDOW | subprocess.DETACHED_PROCESS,
                    )
                    log.info("[LAUNCH] start command sent for '%s'", app["name"])
                    return jsonify({
                        "ok": True,
                        "status": "success",
                        "app": app["name"],
                        "app_name": app["name"],
                        "score": round(best_score),
                        "match_type": "full_registry",
                    })
                except Exception as e:
                    log.error("[LAUNCH] start command failed: %s", e)
                    return jsonify({
                        "ok": False,
                        "status": "error",
                        "error": f"Failed to launch {app['name']}: {e}",
                    }), 500
            log.info("[LAUNCH] Launching: %s -> %s", app.get("name"), app_path)
            result = launch_app(app_path)
            log.info("[LAUNCH] Result: %s", result)
            if result.get("ok"):
                return jsonify({
                    "ok": True,
                    "status": "success",
                    "app": app["name"],
                    "app_name": app["name"],
                    "score": round(best_score),
                    "match_type": "full_registry",
                })
            return jsonify({
                "ok": False,
                "status": "error",
                "error": f"Failed to launch {app['name']}: {result.get('error', 'unknown')}",
            }), 500

    # No good match — provide suggestions
    suggestions = []
    results = rf_process.extract(query, registry_names, scorer=fuzz.WRatio, limit=5)
    for name, score, _ in results:
        if score >= 30:
            app = _select_best_app_for_name(name)
            if app:
                suggestions.append(app.get("name", name))

    log.info("[MATCH] No match. Suggestions: %s", suggestions)
    return jsonify({
        "status": "not_found",
        "error": f"No app matching '{app_query}' found",
        "suggestions": suggestions,
    }), 404


@app.route("/refresh-registry", methods=["POST"])
@require_token
def refresh_registry():
    """Manually refresh the app registry."""
    _build_app_registry()
    return jsonify({"ok": True, "count": len(_app_registry)})


@app.route("/registry", methods=["GET"])
@require_token
def get_registry():
    """Debug endpoint: return the full app registry as JSON."""
    with _registry_lock:
        registry = dict(_app_registry)
    # Validate paths exist and expand lists
    validated = []
    for name, apps in registry.items():
        for app in apps:
            path = app.get("path", "")
            exists = os.path.exists(path) if path else False
            validated.append({
                "name": app.get("name", ""),
                "path": path,
                "exists": exists,
                "source": app.get("source", ""),
            })
    return jsonify({"ok": True, "count": len(validated), "apps": validated})


# ---------------------------------------------------------------------------
# Custom Commands
# ---------------------------------------------------------------------------

COMMANDS_FILE = Path(__file__).parent / "commands.json"
_commands_lock = threading.Lock()


def _load_commands() -> list:
    if not COMMANDS_FILE.exists():
        return []
    try:
        with open(COMMANDS_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return []


def _save_commands(commands: list):
    with _commands_lock:
        with open(COMMANDS_FILE, "w") as f:
            json.dump(commands, f, indent=2)


@app.route("/commands", methods=["GET"])
@require_token
def list_commands():
    commands = _load_commands()
    return jsonify({"ok": True, "commands": commands})


@app.route("/commands", methods=["POST"])
@require_token
def add_command():
    data = request.get_json(silent=True) or {}
    name = data.get("name", "").strip()
    cmd = data.get("command", "").strip()
    if not name or not cmd:
        return jsonify({"ok": False, "error": "name and command are required"}), 400
    commands = _load_commands()
    cmd_id = str(int(__import__("time").time() * 1000))
    entry = {"id": cmd_id, "name": name, "command": cmd}
    commands.append(entry)
    _save_commands(commands)
    log.info("Command added: %s -> %s", name, cmd)
    return jsonify({"ok": True, "command": entry})


@app.route("/commands/<cmd_id>", methods=["DELETE"])
@require_token
def delete_command(cmd_id):
    commands = _load_commands()
    before = len(commands)
    commands = [c for c in commands if c.get("id") != cmd_id]
    if len(commands) == before:
        return jsonify({"ok": False, "error": "command not found"}), 404
    _save_commands(commands)
    log.info("Command deleted: %s", cmd_id)
    return jsonify({"ok": True})


@app.route("/commands/run", methods=["POST"])
@require_token
def run_command():
    data = request.get_json(silent=True) or {}
    cmd_id = data.get("id", "").strip()
    if not cmd_id:
        return jsonify({"ok": False, "error": "id is required"}), 400
    commands = _load_commands()
    target = next((c for c in commands if c.get("id") == cmd_id), None)
    if not target:
        return jsonify({"ok": False, "error": "command not found"}), 404
    try:
        cmd_str = target["command"]
        log.info("Running command: %s -> %s", target["name"], cmd_str)
        if platform.system() == "Windows":
            subprocess.Popen(
                cmd_str, shell=True,
                creationflags=subprocess.CREATE_NO_WINDOW | subprocess.DETACHED_PROCESS,
            )
        else:
            subprocess.Popen(cmd_str, shell=True, start_new_session=True)
        return jsonify({"ok": True, "name": target["name"]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# File Transfer
# ---------------------------------------------------------------------------

# Default allowed directory for file operations
DEFAULT_FILE_DIR = str(Path.home() / "WOLOW-Files")


def _get_file_root():
    """Get the file transfer root directory, creating it if needed."""
    root = DEFAULT_FILE_DIR
    os.makedirs(root, exist_ok=True)
    return root


def _safe_path(root: str, rel: str) -> str | None:
    """Resolve rel under root, rejecting path traversal."""
    target = os.path.normpath(os.path.join(root, rel))
    root_norm = os.path.normpath(root)
    if not target.startswith(root_norm):
        return None
    return target


@app.route("/files", methods=["GET"])
@require_token
def list_files():
    rel = request.args.get("path", "")
    root = _get_file_root()
    target = _safe_path(root, rel)
    if target is None:
        return jsonify({"ok": False, "error": "invalid path"}), 400
    if not os.path.isdir(target):
        return jsonify({"ok": False, "error": "not a directory"}), 400
    entries = []
    for name in sorted(os.listdir(target)):
        full = os.path.join(target, name)
        is_dir = os.path.isdir(full)
        size = 0 if is_dir else os.path.getsize(full)
        entries.append({"name": name, "is_dir": is_dir, "size": size})
    return jsonify({"ok": True, "path": rel, "entries": entries})


@app.route("/files/upload", methods=["POST"])
@require_token
def upload_file():
    rel = request.form.get("path", "")
    root = _get_file_root()
    target_dir = _safe_path(root, rel)
    if target_dir is None or not os.path.isdir(target_dir):
        return jsonify({"ok": False, "error": "invalid directory"}), 400
    if "file" not in request.files:
        return jsonify({"ok": False, "error": "no file provided"}), 400
    f = request.files["file"]
    if not f.filename:
        return jsonify({"ok": False, "error": "empty filename"}), 400
    dest = os.path.join(target_dir, os.path.basename(f.filename))
    if not dest.startswith(os.path.normpath(root)):
        return jsonify({"ok": False, "error": "invalid path"}), 400
    f.save(dest)
    log.info("File uploaded: %s (%d bytes)", f.filename, os.path.getsize(dest))
    return jsonify({"ok": True, "name": f.filename, "size": os.path.getsize(dest)})


@app.route("/files/download", methods=["GET"])
@require_token
def download_file():
    rel = request.args.get("path", "")
    root = _get_file_root()
    target = _safe_path(root, rel)
    if target is None or not os.path.isfile(target):
        return jsonify({"ok": False, "error": "file not found"}), 404
    return send_file(target, as_attachment=True)


@app.route("/files/delete", methods=["POST"])
@require_token
def delete_file():
    data = request.get_json(silent=True) or {}
    rel = data.get("path", "")
    root = _get_file_root()
    target = _safe_path(root, rel)
    if target is None:
        return jsonify({"ok": False, "error": "invalid path"}), 400
    if not os.path.exists(target):
        return jsonify({"ok": False, "error": "not found"}), 404
    try:
        if os.path.isdir(target):
            import shutil
            shutil.rmtree(target)
        else:
            os.unlink(target)
        log.info("Deleted: %s", rel)
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/files/mkdir", methods=["POST"])
@require_token
def make_dir():
    data = request.get_json(silent=True) or {}
    rel = data.get("path", "")
    root = _get_file_root()
    target = _safe_path(root, rel)
    if target is None:
        return jsonify({"ok": False, "error": "invalid path"}), 400
    os.makedirs(target, exist_ok=True)
    return jsonify({"ok": True})


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

    # Build app registry at startup
    _build_app_registry()

    # Start UDP discovery in background thread
    disc_thread = threading.Thread(target=_discovery_listener, daemon=True)
    disc_thread.start()

    log.info("Starting WOLOW agent on %s:%d", host, port)
    # threaded=True is essential: the phone requests every app icon at once,
    # and a single slow/blocking request must not freeze the whole agent
    # (which would break discovery, /status, /register, /unregister, ...).
    app.run(host=host, port=port, debug=False, threaded=True)


if __name__ == "__main__":
    main()
