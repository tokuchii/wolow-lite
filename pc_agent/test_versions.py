"""Test all IPolicyConfig versions."""
import pythoncom
pythoncom.CoInitialize()
import ctypes
from ctypes import POINTER, byref, c_void_p, Structure, c_ulong, c_ubyte, c_ushort, c_wchar_p

class GUID(Structure):
    _fields_ = [('Data1', c_ulong), ('Data2', c_ushort), ('Data3', c_ushort), ('Data4', c_ubyte * 8)]

def vt(obj, idx):
    return c_void_p.from_address(c_void_p.from_address(obj).value + idx * 8).value

# Create enumerator
CLSID = GUID(0xBCDE0395, 0xE52F, 0x467C, (0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E))
IID_ENUM = GUID(0xA95664D2, 0x9614, 0x4F35, (0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6))
enumerator = c_void_p()
ctypes.windll.ole32.CoCreateInstance(byref(CLSID), None, 0x17, byref(IID_ENUM), byref(enumerator))

# Get endpoints
endpoints = c_void_p()
ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, ctypes.c_int, ctypes.c_int, POINTER(c_void_p))(vt(enumerator.value, 3))(enumerator.value, 0, 1, byref(endpoints))
count = c_ulong()
ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(c_ulong))(vt(endpoints.value, 3))(endpoints.value, byref(count))

# Get device 2 (Speakers)
dev = c_void_p()
ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, ctypes.c_ulong, POINTER(c_void_p))(vt(endpoints.value, 4))(endpoints.value, 2, byref(dev))
did = c_wchar_p()
ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(c_wchar_p))(vt(dev.value, 5))(dev.value, byref(did))
print(f'Target device: {did.value}')

# Try all IPolicyConfig versions via QI
versions = [
    ('V1', 0xCA286FC3, 0x91FD, 0x42C3, (0x8E, 0x9B, 0xCA, 0xAF, 0xA6, 0x62, 0x42, 0xE3)),
    ('V2', 0x568B9108, 0x44BF, 0x40B4, (0x90, 0x06, 0x86, 0xAF, 0xE5, 0xB5, 0xA6, 0x20)),
    ('V3', 0x68108638, 0x490C, 0x4F5C, (0xB2, 0x92, 0x3B, 0x8A, 0xD6, 0xA8, 0xF5, 0x53)),
    ('V4', 0x3B6F38B8, 0x3F22, 0x46FC, (0xA8, 0x39, 0x24, 0x57, 0xBE, 0xBB, 0x22, 0x90)),
    ('V5', 0x05C4063A, 0xCA5E, 0x48B8, (0xBA, 0x5F, 0xB0, 0xC0, 0xE5, 0x9F, 0x7F, 0x0C)),
    ('V6', 0x17580E9E, 0x6F93, 0x4E38, (0x9F, 0x5D, 0x24, 0x79, 0x1F, 0xCA, 0xB4, 0x2C)),
    ('V7', 0x1A002F58, 0x8E76, 0x4E4C, (0x9A, 0x23, 0x02, 0x58, 0xEE, 0xC3, 0xAC, 0xCF)),
]

QI = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(GUID), POINTER(c_void_p))

for name, d1, d2, d3, d4 in versions:
    iid = GUID(d1, d2, d3, d4)
    out = c_void_p()
    hr = QI(vt(dev.value, 0))(dev.value, byref(iid), byref(out))
    status = 'OK' if hr == 0 else f'0x{hr & 0xFFFFFFFF:08X}'
    print(f'  {name}: {status}')
    if hr == 0:
        # Try SetDefaultEndpoint
        SDE = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, c_wchar_p, ctypes.c_int)
        sde = SDE(vt(out.value, 9))
        target = '{0.0.0.00000000}.{f0f63a1c-e07c-4fa6-b503-ba8a9649c8aa}'
        for role in [0, 1, 2]:
            hr2 = sde(out.value, target, role)
            print(f'    SetDefaultEndpoint role {role}: 0x{hr2 & 0xFFFFFFFF:08X}')
        # Release
        ctypes.CFUNCTYPE(ctypes.c_long, c_void_p)(vt(out.value, 2))(out.value)
        print(f'  {name} SUCCESS!')
        break
