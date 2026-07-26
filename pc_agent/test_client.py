"""Test comtypes.client.CreateObject."""
import comtypes.client
import comtypes

CLSID = '{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}'
try:
    obj = comtypes.client.CreateObject(CLSID)
    print(f'Type: {type(obj)}')
    methods = [m for m in dir(obj) if not m.startswith('_')]
    print(f'Methods: {methods[:15]}')

    target = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
    obj.SetDefaultEndpoint(target, 0)
    print('SetDefaultEndpoint(0): OK')
    obj.SetDefaultEndpoint(target, 1)
    print('SetDefaultEndpoint(1): OK')
    obj.SetDefaultEndpoint(target, 2)
    print('SetDefaultEndpoint(2): OK')
    print('SUCCESS!')

    from pycaw.pycaw import AudioUtilities
    default = AudioUtilities.GetSpeakers()
    print(f'Default: {default.FriendlyName}')
except Exception as e:
    print(f'Error: {type(e).__name__}: {e}')
