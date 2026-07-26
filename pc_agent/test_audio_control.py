"""
Windows audio control layer — reference implementation.
"""

import comtypes
from comtypes import GUID, COMMETHOD, HRESULT
from ctypes import POINTER, c_wchar_p, c_int
from ctypes.wintypes import DWORD

from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
from pycaw.constants import EDataFlow, ERole
from comtypes import CLSCTX_ALL


# ---- IPolicyConfig: undocumented interface for setting default device ----

CLSID_POLICY_CONFIG = GUID("{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}")
IID_POLICY_CONFIG_VISTA = GUID("{568B9108-44BF-40B4-9006-86AFE5B5A620}")


class IPolicyConfig(comtypes.IUnknown):
    _case_insensitive_ = True
    _iid_ = IID_POLICY_CONFIG_VISTA
    _methods_ = [
        COMMETHOD([], HRESULT, "GetMixFormat"),
        COMMETHOD([], HRESULT, "GetDeviceFormat"),
        COMMETHOD([], HRESULT, "ResetDeviceFormat"),
        COMMETHOD([], HRESULT, "SetDeviceFormat"),
        COMMETHOD([], HRESULT, "GetProcessingPeriod"),
        COMMETHOD([], HRESULT, "SetProcessingPeriod"),
        COMMETHOD([], HRESULT, "GetShareMode"),
        COMMETHOD([], HRESULT, "SetShareMode"),
        COMMETHOD([], HRESULT, "GetPropertyValue"),
        COMMETHOD([], HRESULT, "SetPropertyValue"),
        COMMETHOD(
            [],
            HRESULT,
            "SetDefaultEndpoint",
            (["in"], c_wchar_p, "deviceId"),
            (["in"], c_int, "role"),
        ),
        COMMETHOD([], HRESULT, "SetEndpointVisibility"),
    ]


def _policy_config():
    return comtypes.CoCreateInstance(
        CLSID_POLICY_CONFIG, IPolicyConfig, comtypes.CLSCTX_ALL
    )


# ---- Public API ----

def list_devices():
    """Return active playback (render) devices as a list of dicts."""
    devices = AudioUtilities.GetAllDevices()
    default_id = AudioUtilities.GetSpeakers().id

    result = []
    for d in devices:
        if str(d.state) != 'AudioDeviceState.Active':
            continue
        if getattr(d, "id", None) is None:
            continue
        result.append(
            {
                "id": d.id,
                "name": d.FriendlyName,
                "is_active": d.id == default_id,
            }
        )
    return result


def set_default_device(device_id: str):
    """Switch the system default playback device."""
    pc = _policy_config()
    pc.SetDefaultEndpoint(device_id, 0)  # eConsole
    pc.SetDefaultEndpoint(device_id, 1)  # eMultimedia
    pc.SetDefaultEndpoint(device_id, 2)  # eCommunications


def _default_endpoint_volume():
    speaker = AudioUtilities.GetSpeakers()
    return speaker.EndpointVolume


def get_volume() -> int:
    vol = _default_endpoint_volume()
    scalar = vol.GetMasterVolumeLevelScalar()
    return round(scalar * 100)


def set_volume(level: int):
    level = max(0, min(100, level))
    vol = _default_endpoint_volume()
    vol.SetMasterVolumeLevelScalar(level / 100.0, None)


if __name__ == "__main__":
    print("=== List devices ===")
    devs = list_devices()
    for d in devs:
        print(f"  {'*' if d['is_active'] else ' '} {d['name']} ({d['id'][:40]}...)")

    print(f"\n=== Current volume: {get_volume()}% ===")

    # Test switching to first non-active device
    non_active = [d for d in devs if not d['is_active']]
    if non_active:
        target = non_active[0]
        print(f"\n=== Switching to: {target['name']} ===")
        set_default_device(target['id'])
        print("Done!")

        # Verify
        devs2 = list_devices()
        for d in devs2:
            print(f"  {'*' if d['is_active'] else ' '} {d['name']}")

        # Switch back
        active = [d for d in devs2 if d['is_active']]
        if active:
            print(f"\n=== Switching back to: {active[0]['name']} ===")
            set_default_device(active[0]['id'])
            print("Done!")
    else:
        print("\nNo non-active devices to switch to")
