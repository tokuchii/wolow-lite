"""Test pythoncom.CoCreateInstance with IID."""
import pythoncom
pythoncom.CoInitialize()

CLSID = pythoncom.IID('{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}')
IID_PC = pythoncom.IID('{568B9108-44BF-40B4-9006-86AFE5B5A620}')

obj = pythoncom.CoCreateInstance(CLSID, None, pythoncom.CLSCTX_ALL, IID_PC)
print(f'Type: {type(obj)}')
methods = [m for m in dir(obj) if not m.startswith('_')]
print(f'Methods: {methods[:10]}')

target = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
obj.SetDefaultEndpoint(target, 0)
obj.SetDefaultEndpoint(target, 1)
obj.SetDefaultEndpoint(target, 2)
print('Switched!')

from pycaw.pycaw import AudioUtilities
print(f'Default: {AudioUtilities.GetSpeakers().FriendlyName}')
