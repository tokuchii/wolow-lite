"""Generate a config.yaml with a random token for the WOLOW agent."""

import secrets
import os
from pathlib import Path

import yaml

CONFIG_PATH = Path(__file__).parent / "config.yaml"

token = secrets.token_urlsafe(32)

config = {
    "server": {
        "host": "0.0.0.0",
        "port": 8220,
        "token": token,
    },
    "logging": {"level": "INFO"},
}

with open(CONFIG_PATH, "w") as f:
    yaml.dump(config, f, default_flow_style=False)

print(f"  Config saved to: {CONFIG_PATH}")
print()
print(f"  ============================================")
print(f"   YOUR AGENT TOKEN (copy this into the app):")
print(f"  ============================================")
print()
print(f"   {token}")
print()
print(f"  ============================================")
