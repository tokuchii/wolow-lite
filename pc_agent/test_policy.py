"""Test IPolicyConfig activation from IMMDevice."""
import pythoncom
pythoncom.CoInitialize()

from pycaw.pycaw import AudioUtilities
from comtypes import GUID, CLSCTX_ALL, IUnknown

speakers = AudioUtilities.GetSpeakers()
dev_ptr = speakers._dev

# Try different IPolicyConfig versions
versions = [
    ('V1', '{CA286FC3-91FD-42C3-8E9B-CAAFA66242E3}'),
    ('V2', '{568B9108-44BF-40B4-9006-86AFE5B5A620}'),
    ('V3', '{68108638-490C-4F5C-B292-3B8AD6A8F553}'),
    ('V4', '{3B6F38B8-3F22-46FC-A839-2457BEBB2290}'),
    ('V5', '{05C4063A-CA5E-48B8-BA5F-B0C0E59F7F0C}'),
    ('V6', '{17580E9E-6F93-4E38-9F5D-24791FCAB42C}'),
    ('V7', '{1A002F58-8E76-4E4C-9A23-0258EEC3ACCF}'),
]

for name, guid_str in versions:
    try:
        iid = GUID(guid_str)
        iface = dev_ptr.Activate(iid, CLSCTX_ALL, None)
        methods = [m for m in dir(iface) if not m.startswith('_')]
        print(f'{name}: WORKS! Methods: {methods[:10]}')

        # Try calling SetDefaultEndpoint
        headphones_id = '{0.0.0.00000000}.{0a8b19c1-8253-4190-8645-fc8ab21e0926}'
        for role in [0, 1, 2]:
            try:
                iface.SetDefaultEndpoint(headphones_id, role)
                print(f'  SetDefaultEndpoint role {role}: OK')
            except Exception as e:
                print(f'  SetDefaultEndpoint role {role}: {e}')
        break
    except Exception as e:
        print(f'{name}: {e}')
