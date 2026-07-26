"""Test switching audio via pythoncom (pywin32)."""
import pythoncom
pythoncom.CoInitialize()

# Create MMDeviceEnumerator via pythoncom
enumerator = pythoncom.CoCreateInstance(
    pythoncom.CLSID_MMDeviceEnumerator,
    None,
    pythoncom.CLSCTX_ALL,
    pythoncom.IID_IUnknown
)
print(f'Enumerator: {type(enumerator)}')

# Get proper interface
from comtypes import GUID
IID_IMMDeviceEnumerator = GUID('{A95664D2-9614-4F35-A746-DE8DB63617E6}')
dev_enum = enumerator.QueryInterface(IID_IMMDeviceEnumerator)
print(f'DeviceEnumerator: {type(dev_enum)}')

endpoints = dev_enum.EnumAudioEndpoints(0, 1)
count = endpoints.GetCount()
print(f'Devices: {count}')

# Find speakers
for i in range(count):
    dev = endpoints.Item(i)
    did = dev.GetId()
    if 'f0f63a1c' in did:
        print(f'Speakers: {did}')
        # QueryInterface for IPolicyConfig
        IID_IPolicyConfig = GUID('{CA286FC3-91FD-42C3-8E9B-CAAFA66242E3}')
        try:
            policy = dev.QueryInterface(IID_IPolicyConfig)
            print(f'IPolicyConfig: {type(policy)}')
            methods = [m for m in dir(policy) if not m.startswith('_')]
            print(f'Methods: {methods}')
            headphones_id = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
            for role in [0, 1, 2]:
                policy.SetDefaultEndpoint(headphones_id, role)
                print(f'Role {role}: OK')
            print('SUCCESS!')
        except Exception as e:
            print(f'QI failed: {type(e).__name__}: {e}')
        break
