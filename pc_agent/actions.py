"""Platform-specific PC actions: reboot, sleep, lock, shutdown, hibernate,
audio control, system stats, processes, and media controls."""

import ctypes
import functools
import os
import platform
import subprocess
import sys
import threading
import time
from pathlib import Path


def is_windows() -> bool:
    return platform.system() == "Windows"


def is_linux() -> bool:
    return platform.system() == "Linux"


def is_macos() -> bool:
    return platform.system() == "Darwin"


# When the agent runs under pythonw.exe it has NO console window. Any console
# app spawned via subprocess (getmac, wmic, tasklist, shutdown, ...) would
# otherwise get its own visible terminal window that flashes on the PC. Always
# pass CREATE_NO_WINDOW on Windows to keep everything silent.
_NO_WINDOW = subprocess.CREATE_NO_WINDOW if is_windows() else 0


def reboot() -> dict:
    if is_windows():
        subprocess.run(["shutdown", "/r", "/t", "0"], check=True, creationflags=_NO_WINDOW)
    elif is_linux():
        subprocess.run(["sudo", "shutdown", "-r", "now"], check=True)
    elif is_macos():
        subprocess.run(["sudo", "shutdown", "-r", "now"], check=True)
    return {"ok": True, "action": "reboot"}


def shutdown() -> dict:
    if is_windows():
        subprocess.run(["shutdown", "/s", "/t", "0"], check=True, creationflags=_NO_WINDOW)
    elif is_linux():
        subprocess.run(["sudo", "shutdown", "-h", "now"], check=True)
    elif is_macos():
        subprocess.run(["sudo", "shutdown", "-h", "now"], check=True)
    return {"ok": True, "action": "shutdown"}


def sleep() -> dict:
    if is_windows():
        # SetSystemPowerState blocks until wake, so the HTTP response
        # will likely time out. The Flutter app handles this by setting
        # a "starting" state before calling this endpoint.
        result = ctypes.windll.kernel32.SetSystemPowerState(False, False, 0)
        if result == 0:
            return {"ok": False, "error": "SetSystemPowerState failed — system may be preventing sleep"}
    elif is_linux():
        subprocess.run(["systemctl", "suspend"], check=True)
    elif is_macos():
        subprocess.run(["pmset", "sleepnow"], check=True)
    return {"ok": True, "action": "sleep"}


def hibernate() -> dict:
    if is_windows():
        ctypes.windll.kernel32.SetSystemPowerState(True, False, 0)
    elif is_linux():
        subprocess.run(["sudo", "systemctl", "hibernate"], check=True)
    else:
        return {"ok": False, "error": "hibernate not supported on macOS"}
    return {"ok": True, "action": "hibernate"}


def lock() -> dict:
    if is_windows():
        ctypes.windll.user32.LockWorkStation()
    elif is_linux():
        for cmd in [["xdg-screensaver", "lock"], ["loginctl", "lock-session"]]:
            try:
                subprocess.run(cmd, check=True)
                return {"ok": True, "action": "lock"}
            except (FileNotFoundError, subprocess.CalledProcessError):
                continue
        return {"ok": False, "error": "no screen locker found"}
    elif is_macos():
        subprocess.run(
            [
                "osascript",
                "-e",
                'tell application "System Events" to keystroke "q" using '
                "{command down, control down}",
            ],
            check=True,
        )
    return {"ok": True, "action": "lock"}


@functools.lru_cache(maxsize=1)
def get_mac_address() -> str:
    """Get the primary MAC address of this machine (cached — avoids spawning
    `getmac` on every discovery packet / status poll)."""
    mac = "unknown"
    if is_windows():
        try:
            output = subprocess.check_output(
                ["getmac", "/fo", "csv", "/nh"], text=True, stderr=subprocess.DEVNULL,
                creationflags=_NO_WINDOW,
            )
            for line in output.strip().splitlines():
                parts = line.split(",")
                if len(parts) >= 1:
                    mac = parts[0].strip('"').replace("-", ":")
                    if mac and mac != "FF:FF:FF:FF:FF:FF":
                        return mac
        except Exception:
            pass
    elif is_linux() or is_macos():
        try:
            import uuid
            mac_int = uuid.getnode()
            mac = ":".join(f"{(mac_int >> (8 * i)) & 0xFF:02X}" for i in reversed(range(6)))
            if mac == "00:00:00:00:00:00":
                return "unknown"
        except Exception:
            pass
    return mac


def get_status() -> dict:
    return {
        "ok": True,
        "platform": platform.system(),
        "hostname": platform.node(),
        "mac": get_mac_address(),
        "python": platform.python_version(),
    }


# ---------------------------------------------------------------------------
# Audio control (Windows only via svcl.exe — NirSoft SoundVolumeCommandLine)
# ---------------------------------------------------------------------------

import csv
import io
import tempfile

SVCL_PATH = str(Path(__file__).parent / "svcl.exe")


def _svcl(*args):
    """Run svcl.exe with given arguments, return stdout."""
    result = subprocess.run(
        [SVCL_PATH] + list(args),
        capture_output=True, text=True, timeout=10,
        creationflags=subprocess.CREATE_NO_WINDOW if is_windows() else 0,
    )
    return result.stdout.strip(), result.returncode


def get_audio_devices() -> dict:
    """List available audio output devices using svcl.exe."""
    if not is_windows():
        return {"ok": True, "devices": [], "current": ""}

    try:
        # Export all devices to CSV
        csv_path = tempfile.mktemp(suffix='.csv')
        _svcl("/scomma", csv_path)

        # Read the CSV file
        with open(csv_path, 'r', encoding='utf-8-sig', errors='replace') as f:
            csv_content = f.read()
        try:
            import os
            os.unlink(csv_path)
        except Exception:
            pass

        if not csv_content.strip():
            return {"ok": True, "devices": [], "current": ""}

        reader = csv.DictReader(io.StringIO(csv_content))
        devices = []
        current_id = ""

        for row in reader:
            name = row.get("Name", "")
            dev_type = row.get("Type", "")
            direction = row.get("Direction", "")
            default_render = row.get("Default", "")
            state = row.get("Device State", "")
            cmd_id = row.get("Command-Line Friendly ID", "")

            # Only include Device-type Render outputs that are Active
            if dev_type != "Device":
                continue
            if direction != "Render":
                continue
            if state != "Active":
                continue
            if not cmd_id:
                continue

            is_default = "Render" in default_render
            if is_default:
                current_id = cmd_id

            # Parse volume from Volume Percent column
            vol_str = row.get("Volume Percent", "0%").replace("%", "").strip()
            try:
                volume = int(float(vol_str))
            except (ValueError, TypeError):
                volume = 0

            muted_str = row.get("Muted", "No")
            muted = muted_str.strip().lower() == "yes"

            devices.append({
                "id": cmd_id,
                "name": name,
                "volume": volume,
                "muted": muted,
                "is_default": is_default,
            })

        return {"ok": True, "devices": devices, "current": current_id}
    except Exception as e:
        return {"ok": False, "devices": [], "current": "", "error": str(e)}


def set_default_audio_device(device_id: str) -> dict:
    """Switch the default audio output device using svcl.exe."""
    if not is_windows():
        return {"ok": False, "error": "audio device switching not supported"}

    try:
        # Set as default for all roles
        _svcl("/SetDefault", device_id, "all")

        # Verify by re-listing devices
        result = get_audio_devices()
        if result.get("ok"):
            for dev in result.get("devices", []):
                if dev["id"] == device_id and dev.get("is_default"):
                    return {"ok": True, "device_id": device_id}

        return {"ok": False, "error": "device switch did not take effect — try switching manually via Windows Settings"}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def get_volume(device_id: str = "") -> dict:
    """Get volume for a device or the default device using svcl.exe."""
    if not is_windows():
        return {"ok": False, "volume": 50, "muted": False, "error": "not windows"}

    try:
        if device_id:
            stdout, rc = _svcl("/Stdout", "/GetPercent", device_id)
        else:
            stdout, rc = _svcl("/Stdout", "/GetPercent", "DefaultRenderDevice")

        vol_str = stdout.replace("%", "").strip()
        volume = int(float(vol_str)) if vol_str else None

        # Get mute state
        if device_id:
            mute_out, _ = _svcl("/Stdout", "/GetMute", device_id)
        else:
            mute_out, _ = _svcl("/Stdout", "/GetMute", "DefaultRenderDevice")
        muted = mute_out.strip().lower() == "yes"

        if volume is None:
            return {"ok": False, "volume": 50, "muted": muted, "error": "could not parse volume"}
        return {"ok": True, "volume": min(100, max(0, volume)), "muted": muted}
    except Exception as e:
        return {"ok": False, "volume": 50, "muted": False, "error": str(e)}


def set_volume(level: int, device_id: str = "") -> dict:
    """Set volume using svcl.exe."""
    level = max(0, min(100, level))

    if not is_windows():
        return {"ok": False, "error": "volume control not supported"}

    try:
        if device_id:
            _svcl("/SetVolume", device_id, str(level))
        else:
            _svcl("/SetVolume", "DefaultRenderDevice", str(level))
        return {"ok": True, "volume": level}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def set_mute(muted: bool, device_id: str = "") -> dict:
    """Mute or unmute using svcl.exe."""
    if not is_windows():
        return {"ok": False, "error": "mute control not supported"}

    try:
        target = device_id if device_id else "DefaultRenderDevice"
        if muted:
            _svcl("/Mute", target)
        else:
            _svcl("/Unmute", target)
        return {"ok": True, "muted": muted}
    except Exception as e:
        return {"ok": False, "error": str(e)}


# ---------------------------------------------------------------------------
# System stats (CPU, RAM, Disk) — cross-platform via psutil or fallback
# ---------------------------------------------------------------------------

def get_system_stats() -> dict:
    """Return CPU %, RAM usage, and disk usage for the system drive."""
    try:
        import psutil
        cpu = psutil.cpu_percent(interval=0.1)
        mem = psutil.virtual_memory()
        # Use the appropriate root partition
        if is_windows():
            disk = psutil.disk_usage("C:\\")
        else:
            disk = psutil.disk_usage("/")
        return {
            "ok": True,
            "cpu_percent": round(cpu, 1),
            "ram": {
                "total_gb": round(mem.total / (1024**3), 1),
                "used_gb": round(mem.used / (1024**3), 1),
                "percent": mem.percent,
            },
            "disk": {
                "total_gb": round(disk.total / (1024**3), 1),
                "used_gb": round(disk.used / (1024**3), 1),
                "percent": round(disk.percent, 1),
            },
        }
    except ImportError:
        # Fallback: parse system commands
        return _get_system_stats_fallback()
    except Exception as e:
        return {"ok": False, "error": str(e)}


def _get_system_stats_fallback() -> dict:
    """Fallback system stats using OS commands when psutil is not installed."""
    try:
        cpu = 0.0
        ram_total = 0
        ram_used = 0
        ram_pct = 0.0
        disk_total = 0
        disk_used = 0
        disk_pct = 0.0

        if is_windows():
            # CPU via wmic
            try:
                out = subprocess.check_output(
                    ["wmic", "cpu", "get", "loadpercentage", "/value"],
                    text=True, stderr=subprocess.DEVNULL, timeout=5,
                    creationflags=_NO_WINDOW,
                )
                for line in out.strip().splitlines():
                    if "LoadPercentage" in line and "=" in line:
                        cpu = float(line.split("=")[1].strip())
            except Exception:
                pass

            # RAM via wmic
            try:
                out = subprocess.check_output(
                    ["wmic", "OS", "get", "TotalVisibleMemorySize,FreePhysicalMemory", "/value"],
                    text=True, stderr=subprocess.DEVNULL, timeout=5,
                    creationflags=_NO_WINDOW,
                )
                vals = {}
                for line in out.strip().splitlines():
                    if "=" in line:
                        k, v = line.split("=", 1)
                        vals[k.strip()] = v.strip()
                total_kb = int(vals.get("TotalVisibleMemorySize", 0))
                free_kb = int(vals.get("FreePhysicalMemory", 0))
                ram_total = round(total_kb / (1024 * 1024), 1)
                ram_used = round((total_kb - free_kb) / (1024 * 1024), 1)
                ram_pct = round((total_kb - free_kb) / total_kb * 100, 1) if total_kb else 0
            except Exception:
                pass

            # Disk via wmic
            try:
                out = subprocess.check_output(
                    ["wmic", "logicaldisk", "where", "DeviceID='C:'", "get", "Size,FreeSpace", "/value"],
                    text=True, stderr=subprocess.DEVNULL, timeout=5,
                    creationflags=_NO_WINDOW,
                )
                vals = {}
                for line in out.strip().splitlines():
                    if "=" in line:
                        k, v = line.split("=", 1)
                        vals[k.strip()] = v.strip()
                total = int(vals.get("Size", 0))
                free = int(vals.get("FreeSpace", 0))
                disk_total = round(total / (1024**3), 1)
                disk_used = round((total - free) / (1024**3), 1)
                disk_pct = round((total - free) / total * 100, 1) if total else 0
            except Exception:
                pass
        else:
            # Unix: use /proc and df
            try:
                with open("/proc/stat") as f:
                    line = f.readline()
                vals = list(map(int, line.split()[1:]))
                idle1 = vals[3]
                total1 = sum(vals)
                time.sleep(0.3)
                with open("/proc/stat") as f:
                    line = f.readline()
                vals = list(map(int, line.split()[1:]))
                idle2 = vals[3]
                total2 = sum(vals)
                cpu = round((1 - (idle2 - idle1) / (total2 - total1)) * 100, 1) if total2 != total1 else 0
            except Exception:
                pass

            try:
                with open("/proc/meminfo") as f:
                    mem = {}
                    for line in f:
                        parts = line.split(":")
                        if len(parts) == 2:
                            key = parts[0].strip()
                            val = int(parts[1].strip().split()[0])
                            mem[key] = val
                total_kb = mem.get("MemTotal", 0)
                avail_kb = mem.get("MemAvailable", 0)
                ram_total = round(total_kb / (1024 * 1024), 1)
                ram_used = round((total_kb - avail_kb) / (1024 * 1024), 1)
                ram_pct = round((total_kb - avail_kb) / total_kb * 100, 1) if total_kb else 0
            except Exception:
                pass

            try:
                out = subprocess.check_output(["df", "-B1", "/"], text=True, stderr=subprocess.DEVNULL)
                lines = out.strip().splitlines()
                if len(lines) >= 2:
                    parts = lines[1].split()
                    disk_total = round(int(parts[1]) / (1024**3), 1)
                    disk_used = round(int(parts[2]) / (1024**3), 1)
                    disk_pct = float(parts[4].replace("%", ""))
            except Exception:
                pass

        return {
            "ok": True,
            "cpu_percent": cpu,
            "ram": {"total_gb": ram_total, "used_gb": ram_used, "percent": ram_pct},
            "disk": {"total_gb": disk_total, "used_gb": disk_used, "percent": disk_pct},
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}


# ---------------------------------------------------------------------------
# Running processes — top N by CPU
# ---------------------------------------------------------------------------

def get_processes(limit: int = 15) -> dict:
    """Return top processes sorted by CPU usage."""
    try:
        import psutil
        procs = []
        for p in psutil.process_iter(["pid", "name", "cpu_percent", "memory_percent"]):
            try:
                info = p.info
                procs.append({
                    "pid": info["pid"],
                    "name": info["name"] or "unknown",
                    "cpu": round(info["cpu_percent"] or 0, 1),
                    "mem": round(info["memory_percent"] or 0, 1),
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        # Sort by CPU descending, take top N
        procs.sort(key=lambda x: x["cpu"], reverse=True)
        return {"ok": True, "processes": procs[:limit]}
    except ImportError:
        return _get_processes_fallback(limit)
    except Exception as e:
        return {"ok": False, "error": str(e), "processes": []}


def _get_processes_fallback(limit: int = 15) -> dict:
    """Fallback process list using OS commands."""
    try:
        if is_windows():
            out = subprocess.check_output(
                ["tasklist", "/fo", "csv", "/nh"],
                text=True, stderr=subprocess.DEVNULL, timeout=10,
                creationflags=_NO_WINDOW,
            )
            procs = []
            for line in out.strip().splitlines():
                parts = line.split(",")
                if len(parts) >= 5:
                    name = parts[0].strip('"')
                    pid = parts[1].strip('"')
                    try:
                        pid_int = int(pid)
                    except ValueError:
                        continue
                    procs.append({"pid": pid_int, "name": name, "cpu": 0, "mem": 0})
            return {"ok": True, "processes": procs[:limit]}
        else:
            out = subprocess.check_output(
                ["ps", "aux", "--sort=-pcpu"],
                text=True, stderr=subprocess.DEVNULL, timeout=10,
            )
            procs = []
            for line in out.strip().splitlines()[1:]:
                parts = line.split()
                if len(parts) >= 11:
                    procs.append({
                        "pid": int(parts[1]),
                        "name": parts[10],
                        "cpu": float(parts[2]),
                        "mem": float(parts[3]),
                    })
            return {"ok": True, "processes": procs[:limit]}
    except Exception as e:
        return {"ok": False, "error": str(e), "processes": []}


# ---------------------------------------------------------------------------
# Media controls — send media key events
# ---------------------------------------------------------------------------

_MEDIA_KEYS = {
    "play_pause": 0xB3,   # VK_MEDIA_PLAY_PAUSE
    "next": 0xB0,         # VK_MEDIA_NEXT_TRACK
    "prev": 0xB1,         # VK_MEDIA_PREV_TRACK
    "stop": 0xB2,         # VK_MEDIA_STOP
    "vol_up": 0xAF,       # VK_VOLUME_UP
    "vol_down": 0xAE,     # VK_VOLUME_DOWN
    "mute": 0xAD,         # VK_VOLUME_MUTE
}


def send_media_key(key: str) -> dict:
    """Send a media key event. Valid keys: play_pause, next, prev, stop, vol_up, vol_down, mute."""
    vk = _MEDIA_KEYS.get(key)
    if vk is None:
        return {"ok": False, "error": f"unknown media key: {key}"}

    try:
        if is_windows():
            # Use ctypes to send keybd_event
            KEYEVENTF_KEYUP = 0x0002
            ctypes.windll.user32.keybd_event(vk, 0, 0, 0)  # key down
            ctypes.windll.user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)  # key up
        elif is_linux():
            # Try xdotool
            keymap = {
                "play_pause": "XF86AudioPlay", "next": "XF86AudioNext",
                "prev": "XF86AudioPrev", "stop": "XF86AudioStop",
                "vol_up": "XF86AudioRaiseVolume", "vol_down": "XF86AudioLowerVolume",
                "mute": "XF86AudioMute",
            }
            subprocess.run(["xdotool", "key", keymap.get(key, key)], check=True)
        elif is_macos():
            script_map = {
                "play_pause": 'tell application "System Events" to key code 16 using {command down}',
                "next": 'tell application "System Events" to key code 17 using {command down}',
                "prev": 'tell application "System Events" to key code 18 using {command down}',
                "stop": 'tell application "System Events" to key code 19 using {command down}',
                "vol_up": "set volume output volume (output volume of (get volume settings) + 10)",
                "vol_down": "set volume output volume (output volume of (get volume settings) - 10)",
                "mute": "set volume output muted not (output muted of (get volume settings))",
            }
            subprocess.run(["osascript", "-e", script_map.get(key, "")], check=True)
        return {"ok": True, "key": key}
    except Exception as e:
        return {"ok": False, "error": str(e)}


# ---------------------------------------------------------------------------
# Installed Apps Scanner — lists user-visible apps, filters bloatware
# ---------------------------------------------------------------------------

# Known bloatware / system packages to exclude
_BLOATWARE_KEYWORDS = {
    "microsoft.visual", "vc_redist", "vcredist", "msvc", "directx",
    "dotnet", "net framework", "c++ redistributable", "windows sdk",
    "windows adk", "windows kit", "wdk", ".net", "asp.net",
    "nuget", "powershell", "windows terminal", "windows web experience",
    "microsoft edge update", "microsoft edge webview", "edge update",
    "microsoft defender", "windows security", "windows driver",
    "intel", "nvidia", "amd", "realtek", "synaptics", "elan",
    "driver", "firmware", "bios", "uefi", "update for microsoft",
    "microsoft update", "kb[0-9]", "hotfix", "security update",
    "service pack", "microsoft visual c++", "microsoft .net",
    "msxml", "vsto", "office 16", "office 15", "click-to-run",
    "microsoft onedrive", "microsoft teams", "microsoft edge",
    "cortana", "windows mixed reality", "xbox", "get help",
    "get started", "tips", "feedback hub", "alarms", "calculator",
    "calendar", "camera", "mail", "maps", "movies", "news",
    "onenote", "paint 3d", "people", "photos", "snipping tool",
    "store", "voice recorder", "weather", "whiteboard",
    "your phone", "phone link", "clipchamp", "solitaire",
    "sticky notes", "todo", "powerautomoutlook", "powerautomate",
    "microsoft 365", "microsoft office", "skype", "onenote for windows",
}

_BLOATWARE_exact = {
    "install", "uninstall", "setup", "readme", "license",
    "help", "documentation", "update", "patch",
}


def _is_bloatware(name: str) -> bool:
    """Check if an app name looks like bloatware or a system component."""
    lower = name.lower().strip()
    # Skip very short or generic names
    if len(lower) < 3:
        return True
    if lower in _BLOATWARE_exact:
        return True
    for kw in _BLOATWARE_KEYWORDS:
        import re
        if re.search(kw, lower):
            return True
    return False


def get_installed_apps() -> dict:
    """Scan for installed user-visible apps, filtered to exclude bloatware."""
    apps = []

    if is_windows():
        apps = _scan_windows_apps()
    elif is_linux():
        apps = _scan_linux_apps()
    elif is_macos():
        apps = _scan_macos_apps()

    # Sort by name
    apps.sort(key=lambda a: a["name"].lower())
    return {"ok": True, "apps": apps}


def _scan_windows_apps() -> list:
    """Scan Start Menu shortcuts + registry for installed Windows apps."""
    import os
    found = {}  # name -> {name, path, source}

    # 1. Scan Start Menu shortcuts (most reliable for user-visible apps)
    for menu_dir in [
        os.path.join(os.environ.get("APPDATA", ""), r"Microsoft\Windows\Start Menu\Programs"),
        os.path.join(os.environ.get("PROGRAMDATA", ""), r"Microsoft\Windows\Start Menu\Programs"),
    ]:
        if not os.path.isdir(menu_dir):
            continue
        for root, dirs, files in os.walk(menu_dir):
            for f in files:
                if f.lower().endswith(".lnk"):
                    name = f[:-4]  # strip .lnk
                    if not _is_bloatware(name):
                        found[name.lower()] = {
                            "name": name,
                            "path": os.path.join(root, f),
                            "source": "startmenu",
                        }

    # 2. Scan registry uninstall keys
    try:
        import winreg
        import re as _re

        def _clean_display_path(p: str) -> str:
            """Normalize registry DisplayIcon/InstallLocation values.

            Examples:
            - '"C:\\Program Files\\App\\app.exe",0' -> 'C:\\Program Files\\App\\app.exe'
            - 'C:\\Path\\app.exe,0' -> 'C:\\Path\\app.exe'
            - 'C:\\Path with args\\app.exe -arg' -> 'C:\\Path with args\\app.exe'
            """
            if not p:
                return p
            s = p.strip()
            # Remove surrounding quotes
            if s.startswith('"') and s.endswith('"'):
                s = s[1:-1]
            # If there's a comma (resource index), take part before comma
            if ',' in s:
                s = s.split(',', 1)[0].strip()
            # If there are command-line args, try to extract the exe path
            # Look for first occurrence of .exe or .lnk and keep up to that
            m = _re.search(r".*?\.(exe|lnk)", s, _re.IGNORECASE)
            if m:
                s = s[: m.end()]
            # Strip any surrounding quotes again and whitespace
            return s.strip().strip('"')
        for hive in [winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER]:
            for subkey in [
                r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            ]:
                try:
                    key = winreg.OpenKey(hive, subkey)
                except OSError:
                    continue
                i = 0
                while True:
                    try:
                        subkey_name = winreg.EnumKey(key, i)
                        i += 1
                        try:
                            sub = winreg.OpenKey(key, subkey_name)
                            name = winreg.QueryValueEx(sub, "DisplayName")[0]
                            if name and not _is_bloatware(name):
                                display_icon = ""
                                try:
                                    display_icon = winreg.QueryValueEx(sub, "DisplayIcon")[0]
                                except OSError:
                                    display_icon = ""
                                install_loc = ""
                                try:
                                    install_loc = winreg.QueryValueEx(sub, "InstallLocation")[0]
                                except OSError:
                                    install_loc = ""

                                key_lower = name.lower()
                                candidate_path = display_icon or install_loc or ""
                                candidate_path = _clean_display_path(candidate_path)

                                # If an entry already exists from Start Menu, prefer the one
                                # that has a valid filesystem path. Otherwise replace if
                                # the registry candidate points to a real file.
                                existing = found.get(key_lower)
                                existing_path = existing.get("path", "") if existing else ""
                                if existing and existing_path and os.path.exists(existing_path):
                                    # keep existing startmenu entry
                                    pass
                                else:
                                    # prefer candidate if it exists on disk, otherwise store as-is
                                    if candidate_path and os.path.exists(candidate_path):
                                        found[key_lower] = {
                                            "name": name,
                                            "path": candidate_path,
                                            "source": "registry",
                                        }
                                    else:
                                        # store candidate even if path isn't valid; later checks
                                        # and _build_app_registry will mark missing paths
                                        if key_lower not in found:
                                            found[key_lower] = {
                                                "name": name,
                                                "path": candidate_path,
                                                "source": "registry",
                                            }
                            winreg.CloseKey(sub)
                        except OSError:
                            pass
                    except OSError:
                        break
                winreg.CloseKey(key)
    except ImportError:
        pass
    except Exception:
        pass

    # 3. Scan UWP / Microsoft Store apps via PowerShell
    try:
        ps_result = subprocess.run(
            ["powershell", "-Command", "Get-StartApps | ConvertTo-Json"],
            capture_output=True, text=True, timeout=15,
            creationflags=subprocess.CREATE_NO_WINDOW if is_windows() else 0,
        )
        if ps_result.returncode == 0 and ps_result.stdout.strip():
            import json as _json
            data = _json.loads(ps_result.stdout)
            if isinstance(data, dict):
                data = [data]
            for entry in data:
                name = entry.get("Name", "")
                app_id = entry.get("AppID", "")
                if name and app_id and "!" in app_id:
                    key = name.lower().strip()
                    if key not in found and not _is_bloatware(name):
                        found[key] = {
                            "name": name,
                            "path": app_id,
                            "source": "uwp",
                        }
    except Exception:
        pass

    return list(found.values())


def _scan_linux_apps() -> list:
    """Scan .desktop files for installed Linux apps."""
    import os
    apps = []
    dirs = [
        "/usr/share/applications",
        "/usr/local/share/applications",
        os.path.expanduser("~/.local/share/applications"),
    ]
    for d in dirs:
        if not os.path.isdir(d):
            continue
        for f in os.listdir(d):
            if not f.endswith(".desktop"):
                continue
            path = os.path.join(d, f)
            try:
                name = ""
                exec_cmd = ""
                icon = ""
                no_display = False
                with open(path, "r") as fh:
                    for line in fh:
                        line = line.strip()
                        if line.startswith("Name=") and not name:
                            name = line[5:]
                        elif line.startswith("Exec="):
                            exec_cmd = line[5:]
                        elif line.startswith("Icon="):
                            icon = line[5:]
                        elif line == "NoDisplay=true":
                            no_display = True
                if no_display or not name or not exec_cmd:
                    continue
                if _is_bloatware(name):
                    continue
                apps.append({"name": name, "path": exec_cmd, "source": "desktop"})
            except Exception:
                continue
    return apps


def _scan_macos_apps() -> list:
    """Scan /Applications for macOS apps."""
    import os
    apps = []
    for d in ["/Applications", os.path.expanduser("~/Applications")]:
        if not os.path.isdir(d):
            continue
        for item in os.listdir(d):
            if item.endswith(".app"):
                name = item[:-4]
                if not _is_bloatware(name):
                    apps.append({
                        "name": name,
                        "path": os.path.join(d, item),
                        "source": "applications",
                    })
    return apps


def launch_app(path: str) -> dict:
    """Launch an app by its path or command."""
    import logging as _logging
    _log = _logging.getLogger("wolow-agent")

    _log.info("[LAUNCH] Attempting to launch: '%s'", path)
    _log.info("[LAUNCH] Path exists: %s", os.path.exists(path))
    _log.info("[LAUNCH] Platform: %s", platform.system())

    try:
        # Handle URI schemes (steam://, ms-windows-store://, etc.)
        try:
            from urllib.parse import urlparse
            parsed = urlparse(path)
        except Exception:
            parsed = None
        if parsed and parsed.scheme:
            _log.info("[LAUNCH] Detected URI scheme: %s", parsed.scheme)
            if is_windows():
                try:
                    # os.startfile supports URI schemes on Windows
                    os.startfile(path)
                    return {"ok": True}
                except Exception as e:
                    _log.error("[LAUNCH] startfile for URI failed: %s", e)
            else:
                # Linux/macOS: use xdg-open / open
                if is_linux():
                    subprocess.Popen(["xdg-open", path], start_new_session=True)
                    return {"ok": True}
                elif is_macos():
                    subprocess.Popen(["open", path])
                    return {"ok": True}

        if is_windows():
            if path.lower().endswith(".lnk"):
                _log.info("[LAUNCH] Resolving .lnk for launch: %s", path)
                resolved = _resolve_lnk_target(path)
                _log.info("[LAUNCH] Resolved .lnk -> %s", resolved)

                # If resolved contains Steam arguments like -applaunch <id>, use steam URI
                try:
                    import re as _re
                    m = _re.search(r"-applaunch\s+(\d+)", resolved, _re.IGNORECASE)
                    if m:
                        appid = m.group(1)
                        steam_uri = f"steam://rungameid/{appid}"
                        _log.info("[LAUNCH] Detected Steam -applaunch %s, launching %s", appid, steam_uri)
                        os.startfile(steam_uri)
                        return {"ok": True}
                    # Also check for direct steam:// URIs in arguments
                    m2 = _re.search(r"steam://rungameid/(\d+)", resolved, _re.IGNORECASE)
                    if m2:
                        appid = m2.group(1)
                        steam_uri = f"steam://rungameid/{appid}"
                        _log.info("[LAUNCH] Detected steam URI in shortcut, launching %s", steam_uri)
                        os.startfile(steam_uri)
                        return {"ok": True}
                except Exception:
                    pass

                # No steam app id found; try to execute the resolved command string.
                try:
                    _log.info("[LAUNCH] Executing resolved shortcut command")
                    proc = subprocess.Popen(resolved, shell=True, creationflags=subprocess.CREATE_NO_WINDOW | subprocess.DETACHED_PROCESS)
                    _log.info("[LAUNCH] Popen PID: %s", getattr(proc, 'pid', None))
                    return {"ok": True}
                except Exception as e:
                    _log.error("[LAUNCH] Executing resolved shortcut failed: %s", e)
            elif "!" in path and not os.path.exists(path):
                # UWP app (AppID contains "!" and isn't a file path)
                _log.info("[LAUNCH] UWP app detected, using 'start' command")
                subprocess.Popen(
                    f'start "" "{path}"',
                    shell=True,
                    creationflags=subprocess.CREATE_NO_WINDOW | subprocess.DETACHED_PROCESS,
                )
                _log.info("[LAUNCH] start command sent")
            else:
                _log.info("[LAUNCH] Using subprocess.Popen for exe")
                proc = subprocess.Popen(path, shell=True,
                    creationflags=subprocess.CREATE_NO_WINDOW | subprocess.DETACHED_PROCESS)
                _log.info("[LAUNCH] Popen PID: %s", proc.pid)
        elif is_linux():
            _log.info("[LAUNCH] Using subprocess.Popen (Linux)")
            proc = subprocess.Popen(path, shell=True, start_new_session=True)
            _log.info("[LAUNCH] Popen PID: %s", proc.pid)
        elif is_macos():
            _log.info("[LAUNCH] Using open -a (macOS)")
            proc = subprocess.Popen(["open", "-a", path])
            _log.info("[LAUNCH] Popen PID: %s", proc.pid)
        return {"ok": True}
    except FileNotFoundError as e:
        _log.error("[LAUNCH] FileNotFoundError: %s", e)
        return {"ok": False, "error": f"File not found: {e}"}
    except PermissionError as e:
        _log.error("[LAUNCH] PermissionError: %s", e)
        return {"ok": False, "error": f"Permission denied: {e}"}
    except OSError as e:
        _log.error("[LAUNCH] OSError: %s", e)
        return {"ok": False, "error": f"OS error: {e}"}
    except Exception as e:
        _log.error("[LAUNCH] Unexpected error: %s (%s)", e, type(e).__name__)
        return {"ok": False, "error": f"{type(e).__name__}: {e}"}


# ---------------------------------------------------------------------------
# App Icon Extraction (Windows only — 256x256 via SHGetImageList)
# ---------------------------------------------------------------------------

import io
import ctypes
from ctypes import wintypes, Structure, POINTER, c_void_p, c_int

_icon_cache = {}  # path -> PNG bytes

# Serialize icon extraction. The phone app requests an icon for every app at
# once, and running hundreds of concurrent COM/GDI calls can deadlock the
# entire agent process. This lock makes them run one at a time.
_icon_lock = threading.Lock()

# Win32 constants for SHGetFileInfo / SHGetImageList
_SHGFI_SYSICONINDEX = 0x000004000
_SHGFI_USEFILEATTRIBUTES = 0x000000010
_SHIL_EXTRALARGE = 0x2  # 48x48
_SHIL_JUMBO = 0x4       # 256x256
_FILE_ATTRIBUTE_NORMAL = 0x80


class _SHFILEINFO(Structure):
    _fields_ = [
        ("hIcon", c_void_p),
        ("iIcon", c_int),
        ("dwAttributes", wintypes.DWORD),
        ("szDisplayName", wintypes.WCHAR * 260),
        ("szTypeName", wintypes.WCHAR * 80),
    ]


# IImageList GUID: {46EB5926-582E-4017-9FDF-E8998DAA0950}
class _GUID(Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

def _make_guid(s):
    """Parse '{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}' into a _GUID struct."""
    import re
    h = re.sub(r'[^0-9a-fA-F]', '', s)
    g = _GUID()
    g.Data1 = int(h[0:8], 16)
    g.Data2 = int(h[8:12], 16)
    g.Data3 = int(h[12:16], 16)
    for i in range(8):
        g.Data4[i] = int(h[16 + i*2:18 + i*2], 16)
    return g

_IID_IImageList = _make_guid("{46EB5926-582E-4017-9FDF-E8998DAA0950}")


def _get_system_icon_hicon(exe_path: str, size: int = 256) -> "c_void_p | None":
    """Get an HICON at the requested size from the Windows shell image list."""
    shfi = _SHFILEINFO()
    flags = _SHGFI_SYSICONINDEX | _SHGFI_USEFILEATTRIBUTES
    ctypes.windll.shell32.SHGetFileInfoW(
        exe_path, _FILE_ATTRIBUTE_NORMAL,
        ctypes.byref(shfi), ctypes.sizeof(shfi), flags,
    )
    icon_index = shfi.iIcon
    if icon_index < 0:
        return None

    # Try JUMBO (256px) first, fall back to EXTRALARGE (48px)
    for il_size in (_SHIL_JUMBO, _SHIL_EXTRALARGE):
        pImageList = c_void_p()
        hr = ctypes.windll.shell32.SHGetImageList(
            il_size, ctypes.byref(_IID_IImageList), ctypes.byref(pImageList),
        )
        if hr != 0 or not pImageList:
            continue

        # IImageList::GetIcon — vtable index 10 (not 12!)
        # Read vtable pointer from COM object, then function pointer at index 10
        hicon = c_void_p()
        try:
            vtable_ptr = c_void_p()
            ctypes.memmove(ctypes.byref(vtable_ptr), pImageList, ctypes.sizeof(c_void_p))
            fn_ptr = c_void_p()
            src = c_void_p(vtable_ptr.value + 10 * ctypes.sizeof(c_void_p))
            ctypes.memmove(ctypes.byref(fn_ptr), src, ctypes.sizeof(c_void_p))

            # Call: HRESULT GetIcon(HIMAGELIST, int i, UINT flags, HICON *picon)
            GetIconProto = ctypes.WINFUNCTYPE(
                ctypes.c_long, c_void_p, c_int, wintypes.UINT, POINTER(c_void_p),
            )
            get_icon = GetIconProto(fn_ptr.value)
            hr2 = get_icon(pImageList, icon_index, 0x1, ctypes.byref(hicon))
            if hr2 == 0 and hicon.value:
                return hicon
        except Exception:
            continue
    return None


def _render_hicon_to_pil(hicon, size: int = 256):
    """Render an HICON to a PIL RGBA Image at the given size."""
    import win32gui
    import win32ui
    import win32con
    from PIL import Image

    # Convert ctypes handle to int for win32gui
    if hasattr(hicon, 'value'):
        hicon_int = hicon.value
    else:
        hicon_int = int(hicon)

    hdc_screen = win32gui.GetDC(0)
    hdc = win32gui.CreateCompatibleDC(hdc_screen)
    hbitmap = win32ui.CreateBitmap()
    hbitmap.CreateCompatibleBitmap(win32ui.CreateDCFromHandle(hdc_screen), size, size)
    old_bmp = win32gui.SelectObject(hdc, hbitmap.GetHandle())

    win32gui.DrawIconEx(hdc, 0, 0, hicon_int, size, size, 0, 0, win32con.DI_NORMAL)

    bmpinfo = hbitmap.GetInfo()
    bmpstr = hbitmap.GetBitmapBits(True)
    img = Image.frombuffer(
        "RGBA", (bmpinfo["bmWidth"], bmpinfo["bmHeight"]),
        bmpstr, "raw", "BGRA", 0, 1,
    )

    win32gui.SelectObject(hdc, old_bmp)
    win32gui.DeleteObject(hbitmap.GetHandle())
    win32gui.DeleteDC(hdc)
    win32gui.ReleaseDC(0, hdc_screen)
    return img


def _resolve_lnk_target(lnk_path: str) -> str:
    """Resolve a .lnk shortcut to its target .exe path."""
    try:
        import win32com.client
        shell = win32com.client.Dispatch("WScript.Shell")
        shortcut = shell.CreateShortCut(lnk_path)
        target = shortcut.Targetpath
        args = ""
        try:
            args = shortcut.Arguments or ""
        except Exception:
            args = ""
        if target:
            # If args exist, return full command string so callers can include them
            cmd = target
            if args:
                cmd = f'"{target}" {args}'
            if os.path.exists(target):
                return cmd
    except Exception:
        pass
    return lnk_path


def _get_uwp_icon_png(app_id: str, size: int = 256) -> bytes | None:
    """Extract icon from a UWP/Microsoft Store app by its AppID."""
    import logging as _logging
    _log = _logging.getLogger("wolow-agent")

    try:
        from PIL import Image

        # Extract package name from AppID (before the "!" separator)
        # AppID format: "PackageName_PublisherHash!AppId"
        # Get-AppxPackage -Name wants just the base name (before the last "_")
        family_name = app_id.split("!")[0] if "!" in app_id else app_id
        # Strip publisher hash: "Microsoft.WindowsCalculator_8wekyb3d8bbwe" -> "Microsoft.WindowsCalculator"
        if "_" in family_name:
            base_name = family_name.rsplit("_", 1)[0]
        else:
            base_name = family_name

        # Find the package install location via PowerShell
        # Get-AppxPackage -Name wants the base name without publisher hash, with wildcard
        ps_cmd = (
            'Get-AppxPackage -Name "' + base_name + '*" | '
            "Select-Object -First 1 -ExpandProperty InstallLocation"
        )
        result = subprocess.run(
            ["powershell", "-Command", ps_cmd],
            capture_output=True, text=True, timeout=10,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        install_loc = result.stdout.strip()
        if not install_loc or not os.path.isdir(install_loc):
            _log.info("[UWP] No install location for %s", base_name)
            return None

        # Look for icon PNGs in Assets/ folder
        assets_dir = os.path.join(install_loc, "Assets")
        if not os.path.isdir(assets_dir):
            _log.info("[UWP] No Assets dir in %s", install_loc)
            return None

        # Prefer larger icons: StoreLogo.png, then *150*.png, then any .png
        candidates = []
        for f in os.listdir(assets_dir):
            fl = f.lower()
            if not fl.endswith(".png"):
                continue
            # Score: prefer "storelogo", then files with larger numbers
            score = 0
            if "storelogo" in fl:
                score = 100
            elif "256" in fl:
                score = 90
            elif "150" in fl:
                score = 80
            elif "120" in fl:
                score = 70
            elif "48" in fl:
                score = 30
            elif "44" in fl:
                score = 25
            elif "30" in fl or "24" in fl or "16" in fl:
                score = 10
            else:
                score = 50  # unknown size
            candidates.append((score, os.path.join(assets_dir, f)))

        if not candidates:
            return None

        candidates.sort(key=lambda x: x[0], reverse=True)
        icon_path = candidates[0][1]

        _log.info("[UWP] Using icon: %s", icon_path)
        img = Image.open(icon_path).convert("RGBA")
        img = img.resize((size, size), Image.LANCZOS)

        buf = io.BytesIO()
        img.save(buf, format="PNG", optimize=True)
        return buf.getvalue()

    except Exception as e:
        _log.warning("[UWP] Icon extraction failed for %s: %s", app_id, e)
        return None


def get_app_icon_png(app_path: str, size: int = 256) -> bytes | None:
    """Extract the icon from an app as PNG bytes (256x256). Returns None on failure."""
    if app_path in _icon_cache:
        return _icon_cache[app_path]

    if not is_windows():
        return None

    import logging as _logging
    _log = _logging.getLogger("wolow-agent")

    # Serialize extraction (see _icon_lock). The phone can request every app
    # icon at once; the lock keeps COM/GDI calls one-at-a-time so they can't
    # deadlock the agent. threaded=True in agent.py keeps other endpoints
    # responsive while icons are generated.
    with _icon_lock:
        # Another thread may have populated the cache while we waited
        if app_path in _icon_cache:
            return _icon_cache[app_path]

        try:
            png_bytes = _extract_icon_locked(app_path, size, _log)
        except Exception as e:
            _log.warning("Icon extraction failed for %s: %s", app_path, e)
            png_bytes = None

        # Cache hits AND misses so bad paths aren't retried on every refresh
        _icon_cache[app_path] = png_bytes
        return png_bytes


def _extract_icon_locked(app_path: str, size: int, _log) -> bytes | None:
    """Do the actual icon extraction. Caller must hold _icon_lock."""
    from PIL import Image

    # Handle UWP apps (AppID contains "!")
    if "!" in app_path and not os.path.exists(app_path):
        _log.info("[ICON] UWP app detected: %s", app_path)
        return _get_uwp_icon_png(app_path, size)

    # Resolve .lnk to actual .exe
    exe_path = app_path
    if app_path.lower().endswith(".lnk"):
        _log.info("[ICON] Resolving .lnk: %s", app_path)
        exe_path = _resolve_lnk_target(app_path)
        _log.info("[ICON] Resolved to: %s", exe_path)

    if not os.path.exists(exe_path):
        _log.warning("[ICON] Path does not exist: %s", exe_path)
        if os.path.exists(app_path):
            exe_path = app_path
        else:
            return None

    _log.info("[ICON] Extracting 256px icon from: %s", exe_path)

    # Primary: SHGetImageList for 256px shell icon
    hicon = _get_system_icon_hicon(exe_path, size)
    if hicon:
        img = _render_hicon_to_pil(hicon, size)
        ctypes.windll.user32.DestroyIcon(hicon)
    else:
        # Fallback: ExtractIconEx at system icon size (32x32), then upscale
        _log.info("[ICON] SHGetImageList failed, falling back to ExtractIconEx")
        import win32gui
        import win32ui
        import win32con
        import win32api

        ico_x = win32api.GetSystemMetrics(win32con.SM_CXICON)
        large, small = win32gui.ExtractIconEx(exe_path, 0)
        if not large:
            _log.warning("[ICON] No icon found in %s", exe_path)
            return None

        hicon = large[0]
        img = _render_hicon_to_pil(hicon, ico_x)
        img = img.resize((size, size), Image.LANCZOS)

        for h in large:
            win32gui.DestroyIcon(h)
        for h in small:
            win32gui.DestroyIcon(h)

    # Convert to PNG bytes
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    png_bytes = buf.getvalue()

    _log.info("[ICON] Extracted %dx%d (%d bytes) for %s", size, size, len(png_bytes), app_path)
    return png_bytes
