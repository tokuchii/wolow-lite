"""Test exact reference code approach."""
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

# This is what the reference code does
policy = comtypes.CoCreateInstance(CLSID, IPolicyConfig, CLSCTX_ALL)
print(f'IPolicyConfig: {type(policy)}')
methods = [m for m in dir(policy) if not m.startswith('_')]
print(f'Methods: {methods[:15]}')

# Switch to Headphones
target = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
for role in [0, 1, 2]:
    policy.SetDefaultEndpoint(target, role)
    print(f'  role {role}: OK')

print('SUCCESS!')

from pycaw.pycaw import AudioUtilities
default = AudioUtilities.GetSpeakers()
print(f'Default now: {default.FriendlyName} ({default.id})')

# Switch back to Speakers
target2 = '{0.0.0.00000000}.{f0f63a1c-e07c-4fa6-b503-ba8a9649c8aa}'
for role in [0, 1, 2]:
    policy.SetDefaultEndpoint(target2, role)
print('Switched back to Speakers!')

default2 = AudioUtilities.GetSpeakers()
print(f'Default now: {default2.FriendlyName} ({default2.id})')
