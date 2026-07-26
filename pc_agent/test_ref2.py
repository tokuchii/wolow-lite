"""Test: create with None, then cast to IPolicyConfig."""
import comtypes
from comtypes import GUID, CLSCTX_ALL, IUnknown, HRESULT, COMMETHOD
from ctypes import c_wchar_p, c_int

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

# Create with None
raw = comtypes.CoCreateInstance(CLSID, None, CLSCTX_ALL)
print(f'Raw: {type(raw)}')

# Try casting via QueryInterface
try:
    policy = raw.QueryInterface(IPolicyConfig)
    print(f'QI: {type(policy)}')
except Exception as e:
    print(f'QI failed: {e}')
    
    # Try direct method call on raw
    print(f'Raw methods: {[m for m in dir(raw) if not m.startswith("_")]}')
    
    # Try casting the pointer
    import ctypes
    from ctypes import byref, c_void_p, POINTER, Structure, c_ulong, c_ubyte, c_ushort
    
    class GUID_CT(Structure):
        _fields_ = [('Data1', c_ulong), ('Data2', c_ushort), ('Data3', c_ushort), ('Data4', c_ubyte * 8)]
    
    # Get raw address
    import re
    m = re.search(r'ptr=(0x[0-9a-f]+)', repr(raw))
    if m:
        addr = int(m.group(1), 0)
        print(f'Address: {hex(addr)}')
        
        # Try calling SetDefaultEndpoint directly via vtable
        def vt(obj, idx):
            return c_void_p.from_address(c_void_p.from_address(obj).value + idx * 8).value
        
        # IPolicyConfig vtable: IUnknown(0-2) + 9 methods + SetDefaultEndpoint(11)
        # Actually the reference code has 11 methods before SetDefaultEndpoint
        SDE = ctypes.CFUNCTYPE(ctypes.c_long, c_void_p, c_wchar_p, c_int)
        sde = SDE(vt(addr, 11))  # SetDefaultEndpoint is method 11 (after 9 COMMETHODs)
        
        target = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
        for role in [0, 1, 2]:
            hr = sde(addr, target, role)
            print(f'  role {role}: 0x{hr & 0xFFFFFFFF:08X}')
        
        print('SUCCESS via vtable!')
