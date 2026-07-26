"""Test win32com dynamic dispatch for IPolicyConfig."""
import pythoncom
pythoncom.CoInitialize()
import win32com.client

enumerator = pythoncom.CoCreateInstance(
    '{BCDE0395-E52F-467C-8E3D-C4579291692E}',
    None, 0x17, pythoncom.IID_IUnknown
)

dev_enum = win32com.client.dynamic.Dispatch(enumerator)
endpoints = dev_enum.EnumAudioEndpoints(0, 1)
count = endpoints.GetCount()
print(f'Devices: {count}')

for i in range(count):
    dev = endpoints.Item(i)
    print(f'  {i}: {dev.GetId()}')

dev0 = endpoints.Item(0)
print(f'Device 0 type: {type(dev0)}')

try:
    policy = dev0.QueryInterface('{CA286FC3-91FD-42C3-8E9B-CAAFA66242E3}')
    print(f'IPolicyConfig: {type(policy)}')
    methods = [m for m in dir(policy) if not m.startswith('_')]
    print(f'Methods: {methods[:10]}')
    
    target = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
    policy.SetDefaultEndpoint(target, 0)
    print('SetDefaultEndpoint(0) OK!')
    policy.SetDefaultEndpoint(target, 1)
    print('SetDefaultEndpoint(1) OK!')
    policy.SetDefaultEndpoint(target, 2)
    print('SetDefaultEndpoint(2) OK!')
    print('SUCCESS!')
except Exception as e:
    print(f'QI failed: {type(e).__name__}: {e}')
