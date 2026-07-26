"""Working audio_control module using comtypes CoCreateInstance + vtable."""
import comtypes
from comtypes import GUID, CLSCTX_ALL
from ctypes import c_void_p, c_wchar_p, c_int, POINTER, Structure, c_ulong, c_ubyte, c_ushort
import re

import pythoncom
pythoncom.CoInitialize()

from pycaw.pycaw import AudioUtilities

CLSID_POLICY_CONFIG = GUID('{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}')


class GUID_CT(Structure):
    _fields_ = [('Data1', c_ulong), ('Data2', c_ushort), ('Data3', c_ushort), ('Data4', c_ubyte * 8)]


def _get_policy_config():
    """Create IPolicyConfig COM object and return raw address."""
    raw = comtypes.CoCreateInstance(CLSID_POLICY_CONFIG, None, CLSCTX_ALL)
    m = re.search(r'ptr=(0x[0-9a-f]+)', repr(raw))
    if not m:
        raise RuntimeError("Cannot get COM address")
    return int(m.group(1), 0)


def _vt(obj_addr, idx):
    """Get vtable function pointer."""
    return c_void_p.from_address(c_void_p.from_address(obj_addr).value + idx * 8).value


def list_devices():
    """Return active playback devices."""
    devices = AudioUtilities.GetAllDevices()
    default_id = AudioUtilities.GetSpeakers().id

    result = []
    for d in devices:
        if str(d.state) != 'AudioDeviceState.Active':
            continue
        if not hasattr(d, 'id') or d.id is None:
            continue
        # Only render devices (output)
        if not d.id.startswith('{0.0.0'):
            continue
        result.append({
            'id': d.id,
            'name': d.FriendlyName,
            'is_active': d.id == default_id,
        })
    return result


def set_default_device(device_id):
    """Switch the system default playback device."""
    addr = _get_policy_config()

    # IPolicyConfig vtable layout (from reference code COMMETHODs):
    # IUnknown: QI(0), AddRef(1), Release(2)
    # 0: GetMixFormat(3), 1: GetDeviceFormat(4), 2: ResetDeviceFormat(5),
    # 3: SetDeviceFormat(6), 4: GetProcessingPeriod(7), 5: SetProcessingPeriod(8),
    # 6: GetShareMode(9), 7: SetShareMode(10), 8: GetPropertyValue(11),
    # 9: SetPropertyValue(12), 10: SetDefaultEndpoint(13), 11: SetEndpointVisibility(14)
    SDE = c_void_p  # We'll call it raw

    # SetDefaultEndpoint is at vtable index 13
    # Signature: HRESULT SetDefaultEndpoint(wchar_t* deviceId, int role)
    SetDefaultEndpoint = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, c_wchar_p, c_int)
    sde = SetDefaultEndpoint(_vt(addr, 13))

    for role in [0, 1, 2]:  # eConsole, eMultimedia, eCommunications
        hr = sde(addr, device_id, role)
        if hr != 0:
            raise RuntimeError(f"SetDefaultEndpoint failed: 0x{hr & 0xFFFFFFFF:08X}")


def get_volume():
    """Get current master volume (0-100)."""
    speaker = AudioUtilities.GetSpeakers()
    vol = speaker.EndpointVolume
    return round(vol.GetMasterVolumeLevelScalar() * 100)


def set_volume(level):
    """Set master volume (0-100)."""
    level = max(0, min(100, level))
    speaker = AudioUtilities.GetSpeakers()
    vol = speaker.EndpointVolume
    vol.SetMasterVolumeLevelScalar(level / 100.0, None)


if __name__ == '__main__':
    import ctypes
    print('=== Devices ===')
    for d in list_devices():
        print(f"  {'*' if d['is_active'] else ' '} {d['name']}")

    print(f'\nVolume: {get_volume()}%')

    # Switch to first non-active
    non_active = [d for d in list_devices() if not d['is_active']]
    if non_active:
        target = non_active[0]
        print(f'\nSwitching to: {target["name"]}')
        set_default_device(target['id'])
        print(f'Default now: {AudioUtilities.GetSpeakers().FriendlyName}')

        # Switch back
        active = [d for d in list_devices() if d['is_active']]
        if active:
            print(f'Switching back to: {active[0]["name"]}')
            set_default_device(active[0]['id'])
            print(f'Default now: {AudioUtilities.GetSpeakers().FriendlyName}')
