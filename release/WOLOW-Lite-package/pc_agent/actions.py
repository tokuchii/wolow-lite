"""Platform-specific PC actions: reboot, sleep, lock, shutdown, hibernate."""

import ctypes
import platform
import subprocess


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
