"""Platform-specific PC actions: reboot, sleep, lock, shutdown, hibernate,
and audio control."""

import ctypes
import platform
import subprocess
import sys
from pathlib import Path


def is_windows() -> bool:
    return platform.system() == "Windows"


def is_linux() -> bool:
    return platform.system() == "Linux"


def is_macos() -> bool:
    return platform.system() == "Darwin"


def reboot() -> dict:
    if is_windows():
        subprocess.run(["shutdown", "/r", "/t", "0"], check=True)
    elif is_linux():
        subprocess.run(["sudo", "shutdown", "-r", "now"], check=True)
    elif is_macos():
        subprocess.run(["sudo", "shutdown", "-r", "now"], check=True)
    return {"ok": True, "action": "reboot"}


def shutdown() -> dict:
    if is_windows():
        subprocess.run(["shutdown", "/s", "/t", "0"], check=True)
    elif is_linux():
        subprocess.run(["sudo", "shutdown", "-h", "now"], check=True)
    elif is_macos():
        subprocess.run(["sudo", "shutdown", "-h", "now"], check=True)
    return {"ok": True, "action": "shutdown"}


def sleep() -> dict:
    if is_windows():
        ctypes.windll.kernel32.SetSystemPowerState(False, False, 0)
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


def get_mac_address() -> str:
    """Get the primary MAC address of this machine."""
    mac = "unknown"
    if is_windows():
        try:
            output = subprocess.check_output(
                ["getmac", "/fo", "csv", "/nh"], text=True, stderr=subprocess.DEVNULL
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
