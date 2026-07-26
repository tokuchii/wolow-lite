"""Test switching audio via pythoncom (pywin32)."""
import pythoncom
pythoncom.CoInitialize()
from pythoncom import CLSCTX_ALL, IIDFromString, CoCreateInstance
from pycaw.pycaw import AudioUtilities

# Create MMDeviceEnumerator via pythoncom
CLSID_MMDeviceEnumerator = IIDFromString('{BCDE0395-E52F-467C-8E3D-C4579291692E}')
IID_IMMDeviceEnumerator = IIDFromString('{A95664D2-9614-4F35-A746-DE8DB63617E6}')

enumerator = CoCreateInstance(CLSID_MMDeviceEnumerator, None, CLSCTX_ALL, IID_IMMDeviceEnumerator)
print(f'Enumerator: {type(enumerator)}')

# Enumerate endpoints
endpoints = enumerator.EnumAudioEndpoints(0, 1)
count = endpoints.GetCount()
print(f'Devices: {count}')

# Find speakers device
for i in range(count):
    dev = endpoints.Item(i)
    dev_id = dev.GetId()
    if 'f0f63a1c' in dev_id:
        print(f'Speakers found: {dev_id}')
        
        # Try QueryInterface for IPolicyConfig
        IID_IPolicyConfig = IIDFromString('{CA286FC3-91FD-42C3-8E9B-CAAFA66242E3}')
        try:
            policy = dev.QueryInterface(IID_IPolicyConfig)
            print(f'IPolicyConfig: {type(policy)}')
            
            headphones_id = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
            for role in [0, 1, 2]:
                policy.SetDefaultEndpoint(headphones_id, role)
                print(f'SetDefaultEndpoint role {role}: OK')
            print('SUCCESS!')
        except Exception as e:
            print(f'QI failed: {e}')
        break
