"""Configuration loader for WOLOW Lite PC Agent."""

import os
import secrets
from pathlib import Path

import yaml

CONFIG_PATH = Path(__file__).parent / "config.yaml"
DEFAULTS = {
    "server": {"host": "0.0.0.0", "port": 8220, "token": ""},
    "logging": {"level": "INFO"},
}


def load_config() -> dict:
    cfg = _deep_copy(DEFAULTS)

    if CONFIG_PATH.exists():
        with open(CONFIG_PATH, "r") as f:
            user_cfg = yaml.safe_load(f) or {}
        _deep_merge(cfg, user_cfg)

    if token := os.environ.get("WOLOW_TOKEN"):
        cfg["server"]["token"] = token
    if port := os.environ.get("WOLOW_PORT"):
        cfg["server"]["port"] = int(port)

    if not cfg["server"]["token"]:
        cfg["server"]["token"] = secrets.token_urlsafe(32)
        print(f"[WOLOW] No token configured. Generated: {cfg['server']['token']}")

    return cfg


def _deep_copy(d: dict) -> dict:
    return {k: (v.copy() if isinstance(v, dict) else v) for k, v in d.items()}


def _deep_merge(base: dict, override: dict):
    for k, v in override.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            _deep_merge(base[k], v)
        else:
            base[k] = v
