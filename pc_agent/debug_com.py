"""Debug: compare pycaw's COM pointer with our vtable approach."""
import pythoncom
pythoncom.CoInitialize()
import ctypes
import re
from ctypes import POINTER, byref, c_void_p, Structure, c_ulong, c_ubyte, c_ushort

class GUID(Structure):
    _fields_ = [('Data1', c_ulong), ('Data2', c_ushort), ('Data3', c_ushort), ('Data4', c_ubyte * 8)]

def vt(obj, idx):
    return c_void_p.from_address(c_void_p.from_address(obj).value + idx * 8).value

from pycaw.pycaw import AudioUtilities

speakers = AudioUtilities.GetSpeakers()
dev = speakers._dev

# Get address from repr
m = re.search(r'ptr=(0x[0-9a-f]+)', repr(dev))
addr = int(m.group(1), 0)
print(f'COM addr: {hex(addr)}')

# Get vtable
vtable = c_void_p.from_address(addr).value
print(f'VTable: {hex(vtable)}')

# Check vtable entries
for i in range(7):
    func = c_void_p.from_address(vtable + i * 8).value
    print(f'  vtable[{i}]: {hex(func) if func else None}')

# IAudioEndpointVolume IID
IID_IAEV = GUID(0x26B7CB44, 0x6AB2, 0x49D6, (0xB4, 0xD6, 0x4C, 0xC0, 0xD5, 0xE0, 0xE4, 0x1E))

# QI
QI = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, POINTER(GUID), POINTER(c_void_p))
out = c_void_p()
hr = QI(vt(addr, 0))(addr, byref(IID_IAEV), byref(out))
print(f'\nQI IAudioEndpointVolume: 0x{hr & 0xFFFFFFFF:08X} out={hex(out.value) if out.value else None}')

# Now try the SAME thing via pycaw's EndpointVolume property
print(f'\npycaw EndpointVolume: {speakers.EndpointVolume}')

# The difference must be in how pycaw calls Activate
# Let me check pycaw's Activate call
import inspect
src = inspect.getsource(type(speakers._dev).Activate)
print(f'\nIMMDevice.Activate source:\n{src}')
