"""Check actual vtable layout of IPolicyConfig."""
import comtypes
from comtypes import GUID, CLSCTX_ALL, IUnknown, HRESULT, COMMETHOD
from ctypes import c_void_p, c_wchar_p, c_int, POINTER, Structure, c_ulong, c_ubyte, c_ushort
import re

CLSID = GUID('{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}')
IID_PC = GUID('{568B9108-44BF-40B4-9006-86AFE5B5A620}')

class IPolicyConfig(IUnknown):
    _case_insensitive_ = True
    _iid_ = IID_PC
    _methods_ = [
        COMMETHOD([], HRESULT, 'GetMixFormat'),
        COMMETHOD([], HRESULT, 'GetDeviceFormat'),
        COMMETHOD([], HRESULT, 'ResetDeviceFormat'),
        COMMETHOD([], HRESULT, 'SetDeviceFormat'),
        COMMETHOD([], HRESULT, 'GetProcessingPeriod'),
        COMMETHOD([], HRESULT, 'SetProcessingPeriod'),
        COMMETHOD([], HRESULT, 'GetShareMode'),
        COMMETHOD([], HRESULT, 'SetShareMode'),
        COMMETHOD([], HRESULT, 'GetPropertyValue'),
        COMMETHOD([], HRESULT, 'SetPropertyValue'),
        COMMETHOD([], HRESULT, 'SetDefaultEndpoint',
                  (['in'], c_wchar_p, 'deviceId'),
                  (['in'], c_int, 'role')),
        COMMETHOD([], HRESULT, 'SetEndpointVisibility'),
    ]

# Check how comtypes builds the vtable
print(f'IPolicyConfig methods count: {len(IPolicyConfig._methods_)}')
print(f'IPolicyConfig._iid_: {IPolicyConfig._iid_}')

# Check the COMMETHOD entries
for i, m in enumerate(IPolicyConfig._methods_):
    print(f'  Method {i}: {m.name} args={len(m.argtypes) if m.argtypes else 0}')

# Create the object
raw = comtypes.CoCreateInstance(CLSID, None, CLSCTX_ALL)
m = re.search(r'ptr=(0x[0-9a-f]+)', repr(raw))
addr = int(m.group(1), 0)

def vt(obj, idx):
    return c_void_p.from_address(c_void_p.from_address(obj).value + idx * 8).value

# Print vtable entries
print(f'\nVTable at {hex(vtable := c_void_p.from_address(addr).value)}:')
for i in range(20):
    func = c_void_p.from_address(vtable + i * 8).value
    print(f'  [{i}]: {hex(func) if func else "NULL"}')

# Try each index with SetDefaultEndpoint
print('\nTesting SetDefaultEndpoint at each index:')
SDE = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, c_wchar_p, c_int)
target = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
for idx in range(3, 20):
    try:
        func = c_void_p.from_address(vtable + idx * 8).value
        if not func:
            continue
        sde = SDE(func)
        hr = sde(addr, target, 0)
        if hr != 0x32:  # Skip the common return
            print(f'  [{idx}]: 0x{hr & 0xFFFFFFFF:08X} ** DIFFERENT **')
        else:
            print(f'  [{idx}]: 0x{hr & 0xFFFFFFFF:08X}')
    except Exception as e:
        print(f'  [{idx}]: ERROR {e}')
        break
