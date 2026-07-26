"""Test: switch audio device using pythoncom directly."""
import pythoncom
pythoncom.CoInitialize()

from pythoncom import CLSCTX_ALL
import ctypes
from ctypes import POINTER, byref, c_void_p, c_wchar_p, Structure, c_ulong, c_ubyte, c_ushort


class GUID(Structure):
    _fields_ = [
        ('Data1', c_ulong),
        ('Data2', c_ushort),
        ('Data3', c_ushort),
        ('Data4', c_ubyte * 8),
    ]


def vt(obj, idx):
    vtbl = c_void_p.from_address(obj).value
    return c_void_p.from_address(vtbl + idx * 8).value


# Create MMDeviceEnumerator via pythoncom
CLSID_MMDeviceEnumerator = GUID(0xBCDE0395, 0xE52F, 0x467C, (0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E))
IID_IMMDeviceEnumerator = GUID(0xA95664D2, 0x9614, 0x4F35, (0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6))

enumerator = c_void_p()
hr = ctypes.windll.ole32.CoCreateInstance(
    byref(CLSID_MMDeviceEnumerator), None, CLSCTX_ALL,
    byref(IID_IMMDeviceEnumerator), byref(enumerator)
)
print(f"CoCreateInstance: 0x{hr & 0xFFFFFFFF:08X}")

# EnumAudioEndpoints = vtable[3]
endpoints = c_void_p()
EAF = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, ctypes.c_int, ctypes.c_int, POINTER(c_void_p))
hr = EAF(vt(enumerator.value, 3))(enumerator.value, 0, 1, byref(endpoints))
print(f"EnumAudioEndpoints: 0x{hr & 0xFFFFFFFF:08X}")

# GetCount
count = c_ulong()
GC = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(c_ulong))
hr = GC(vt(endpoints.value, 3))(endpoints.value, byref(count))
print(f"Count: {count.value}")

# List all devices
IC = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, ctypes.c_ulong, POINTER(c_void_p))
GID = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(c_wchar_p))

for i in range(count.value):
    dev = c_void_p()
    IC(vt(endpoints.value, 4))(endpoints.value, i, byref(dev))
    did = c_wchar_p()
    GID(vt(dev.value, 5))(dev.value, byref(did))
    print(f"  Device {i}: {did.value}")

# Try QueryInterface for IPolicyConfig on device 0
dev = c_void_p()
IC(vt(endpoints.value, 4))(endpoints.value, 0, byref(dev))
print(f"\nDevice 0 addr: {hex(dev.value)}")

# IPolicyConfig IID
IID_PC = GUID(0xCA286FC3, 0x91FD, 0x42C3, (0x8E, 0x9B, 0xCA, 0xAF, 0xA6, 0x62, 0x42, 0xE3))

# QI = vtable[0]
QI = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(GUID), POINTER(c_void_p))
out = c_void_p()
hr = QI(vt(dev.value, 0))(dev.value, byref(IID_PC), byref(out))
print(f"QI IPolicyConfig: 0x{hr & 0xFFFFFFFF:08X} out={hex(out.value) if out.value else None}")

if hr == 0 and out.value:
    # SetDefaultEndpoint = vtable[9]
    SDE = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, c_wchar_p, ctypes.c_int)
    sde = SDE(vt(out.value, 9))
    target = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
    for role in [0, 1, 2]:
        hr = sde(out.value, target, role)
        print(f"  SetDefaultEndpoint role {role}: 0x{hr & 0xFFFFFFFF:08X}")
    print("SUCCESS!")
else:
    print("IPolicyConfig not available via QI")
    
    # Try Activate instead
    Activate = ctypes.CFUNCTYPE(
        ctypes.c_long, c_void_p, POINTER(GUID),
        ctypes.c_ulong, POINTER(c_ulong), POINTER(c_void_p)
    )
    out2 = c_void_p()
    params = c_ulong(0)
    hr = Activate(vt(dev.value, 3))(dev.value, byref(IID_PC), CLSCTX_ALL, byref(params), byref(out2))
    print(f"Activate IPolicyConfig: 0x{hr & 0xFFFFFFFF:08X} out={hex(out2.value) if out2.value else None}")
