"""Test correct vtable index for SetDefaultEndpoint."""
import comtypes
from comtypes import GUID, CLSCTX_ALL
import ctypes
from ctypes import c_void_p, c_wchar_p, c_int, POINTER, Structure, c_ulong, c_ubyte, c_ushort
import re

CLSID = GUID('{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}')

raw = comtypes.CoCreateInstance(CLSID, None, CLSCTX_ALL)
m = re.search(r'ptr=(0x[0-9a-f]+)', repr(raw))
addr = int(m.group(1), 0)

def vt(obj, idx):
    return c_void_p.from_address(c_void_p.from_address(obj).value + idx * 8).value

# IUnknown: QI(0), AddRef(1), Release(2)
# Then 10 COMMETHODs, then SetDefaultEndpoint
# Reference code methods:
# 0: GetMixFormat
# 1: GetDeviceFormat
# 2: ResetDeviceFormat
# 3: SetDeviceFormat
# 4: GetProcessingPeriod
# 5: SetProcessingPeriod
# 6: GetShareMode
# 7: SetShareMode
# 8: GetPropertyValue
# 9: SetPropertyValue
# 10: SetDefaultEndpoint  <-- this one
# 11: SetEndpointVisibility

# In vtable: IUnknown(0-2) + 10 methods = SetDefaultEndpoint at index 12
SDE = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, c_wchar_p, c_int)

target = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
target_speakers = '{0.0.0.00000000}.{f0f63a1c-e07c-4fa6-b503-ba8a9649c8aa}'

# Try indices 10-14
for idx in range(10, 15):
    try:
        sde = SDE(vt(addr, idx))
        hr = sde(addr, target, 0)
        print(f'Index {idx}: 0x{hr & 0xFFFFFFFF:08X}')
        
        # Check if it worked
        from pycaw.pycaw import AudioUtilities
        default = AudioUtilities.GetSpeakers()
        if 'Headphones' in default.FriendlyName:
            print(f'  -> SWITCHED! Default: {default.FriendlyName}')
            # Switch back
            sde(addr, target_speakers, 0)
            sde(addr, target_speakers, 1)
            sde(addr, target_speakers, 2)
            print('  -> Switched back to Speakers')
            break
        else:
            print(f'  -> Still: {default.FriendlyName}')
    except Exception as e:
        print(f'Index {idx}: ERROR {e}')
