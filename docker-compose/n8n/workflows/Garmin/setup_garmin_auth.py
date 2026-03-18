#!/usr/bin/env python3
"""
Garmin Connect — One-time MFA authentication setup.

Run this ONCE inside the n8n container to authenticate with MFA and save
OAuth tokens to disk. After this, garmin_fetch.py runs automatically
every day without any MFA prompts.

Usage (from the host):
    docker exec -it n8n python3 /home/node/garmin/setup_garmin_auth.py

Tokens are saved to:
    /home/node/garmin/.garth/              (inside container)
    ./workflows/Garmin/.garth/             (on host)
"""

import os
import sys
import getpass
from pathlib import Path

try:
    import garth
    from garminconnect import Garmin
except ImportError:
    print("ERROR: garminconnect not installed.")
    print("Rebuild the container: docker compose build && docker compose up -d")
    sys.exit(1)

# Allow host-side runs to override the token path via env var
TOKEN_DIR = Path(os.environ.get("TOKEN_DIR", "/home/node/garmin/.garth"))
TOKEN_DIR.mkdir(parents=True, exist_ok=True)

print("=" * 50)
print("  Garmin Connect — One-time Auth Setup")
print("=" * 50)
print()

email = input("Garmin email: ").strip()
password = getpass.getpass("Garmin password: ")

print()
print("Authenticating... (check your phone/authenticator for the MFA code)")
print()


def prompt_mfa():
    return input("Enter MFA/2FA code: ").strip()


try:
    client = Garmin(email=email, password=password, prompt_mfa=prompt_mfa)
    client.login()
except Exception as e:
    print(f"\nERROR: Authentication failed: {e}")
    sys.exit(1)

# Save tokens — write JSON files directly (garth 0.5.x Client has no .save())
try:
    import json

    oauth1 = client.garth.oauth1_token
    oauth2 = client.garth.oauth2_token

    if not oauth1 or not oauth2:
        raise ValueError("Login succeeded but tokens are empty — please try again.")

    def to_dict(obj):
        if hasattr(obj, "model_dump"):
            return obj.model_dump()
        elif hasattr(obj, "dict"):
            return obj.dict()
        elif hasattr(obj, "__dict__"):
            return {k: v for k, v in obj.__dict__.items() if not k.startswith("_")}
        else:
            import dataclasses
            return dataclasses.asdict(obj)

    from datetime import datetime

    def json_default(obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        raise TypeError(f"Not serializable: {type(obj)}")

    TOKEN_DIR.mkdir(parents=True, exist_ok=True)
    (TOKEN_DIR / "oauth1_token.json").write_text(json.dumps(to_dict(oauth1), default=json_default))
    (TOKEN_DIR / "oauth2_token.json").write_text(json.dumps(to_dict(oauth2), default=json_default))

    print()
    print(f"Tokens saved to {TOKEN_DIR}")
    print()

    display_name = client.get_full_name()
    print(f"Logged in as: {display_name}")
    print()
    print("Setup complete. garmin_fetch.py will now run without MFA prompts.")
    print("Tokens auto-refresh — re-run this script only if you change your password.")
except Exception as e:
    print(f"\nERROR: Failed to save tokens: {e}")
    sys.exit(1)
