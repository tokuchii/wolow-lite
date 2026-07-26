"""Helper to switch default audio device via pure ctypes."""
import sys
import json
import ctypes
import pythoncom
pythoncom.CoInitialize()

from ctypes import POINTER, byref, c_void_p, c_wchar_p, Structure, c_ulong, c_ubyte, c_ushort

CLSCTX_ALL = 0x17


class GUID(Structure):
    _fields_ = [
        ('Data1', c_ulong),
        ('Data2', c_ushort),
        ('Data3', c_ushort),
        ('Data4', c_ubyte * 8),
    ]

import ctypes

CLSID_MMDeviceEnumerator = GUID(0xBCDE0395, 0xE52F, 0x467C, (0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E))
IID_IMMDeviceEnumerator = GUID(0xA95664D2, 0x9614, 0x4F35, (0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6))
IID_IPolicyConfig = GUID(0xCA286FC3, 0x91FD, 0x42C3, (0x8E, 0x9B, 0xCA, 0xAF, 0xA6, 0x62, 0x42, 0xE3))


def vt(obj_addr, idx):
    """Get vtable function pointer."""
    vtbl = ctypes.c_void_p.from_address(obj_addr).value
    return ctypes.c_void_p.from_address(vtbl + idx * ctypes.sizeof(ctypes.c_void_p)).value


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"ok": False, "error": "device_id required"}))
        return

    device_id = sys.argv[1]

    # Create MMDeviceEnumerator via pythoncom
    enumerator = c_void_p()
    hr = ctypes.windll.ole32.CoCreateInstance(
        byref(CLSID_MMDeviceEnumerator), None, CLSCTX_ALL,
        byref(IID_IMMDeviceEnumerator), byref(enumerator)
    )
    if hr != 0:
        print(json.dumps({"ok": False, "error": f"CoCreateInstance failed: 0x{hr & 0xFFFFFFFF:08X}"}))
        return

    # EnumAudioEndpoints = vtable[3]
    EnumAF = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, ctypes.c_int, ctypes.c_int, POINTER(c_void_p))
    endpoints = c_void_p()
    hr = EnumAF(vt(enumerator.value, 3))(enumerator.value, 0, 1, byref(endpoints))
    if hr != 0:
        print(json.dumps({"ok": False, "error": f"EnumAudioEndpoints failed: 0x{hr & 0xFFFFFFFF:08X}"}))
        return

    # GetCount = vtable[3] on collection
    GC = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(c_ulong))
    count = c_ulong()
    hr = GC(vt(endpoints.value, 3))(endpoints.value, byref(count))

    # Item = vtable[4]
    IC = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, ctypes.c_ulong, POINTER(c_void_p))
    # GetId = vtable[5] on IMMDevice
    GID = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(c_wchar_p))
    # QueryInterface = vtable[0] on IUnknown
    QI = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(GUID), POINTER(c_void_p))

    for i in range(count.value):
        dev = c_void_p()
        hr = IC(vt(endpoints.value, 4))(endpoints.value, i, byref(dev))
        if hr != 0 or not dev.value:
            continue

        did = c_wchar_p()
        hr = GID(vt(dev.value, 5))(dev.value, byref(did))
        if hr != 0:
            continue

        if did.value == device_id:
            # QI for IPolicyConfig
            out = c_void_p()
            hr = QI(vt(dev.value, 0))(dev.value, byref(IID_IPolicyConfig), byref(out))
            if hr != 0 or not out.value:
                print(json.dumps({"ok": False, "error": f"QI IPolicyConfig failed: 0x{hr & 0xFFFFFFFF:08X}"}))
                return

            # SetDefaultEndpoint = vtable[9]
            SDE = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, c_wchar_p, ctypes.c_int)
            sde = SDE(vt(out.value, 9))

            for role in [0, 1, 2]:
                hr = sde(out.value, device_id, role)
                if hr != 0:
                    print(json.dumps({"ok": False, "error": f"SetDefaultEndpoint role {role} failed: 0x{hr & 0xFFFFFFFF:08X}"}))
                    return

            # Release
            Rel = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p)
            rel = Rel(vt(out.value, 2))
            rel(out.value)

            print(json.dumps({"ok": True, "device_id": device_id}))
            return

    print(json.dumps({"ok": False, "error": "device not found"}))


if __name__ == '__main__':
    main()
