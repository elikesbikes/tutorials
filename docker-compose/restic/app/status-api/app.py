#!/usr/bin/env python3
"""
HTTP status server for restic backup monitoring.
Reads /app/logs/status.json and returns:
  200  if last_success_time is within 24 hours
  503  if last_success_time is older than 24 hours, missing, or unreadable
"""

import json
import os
from datetime import datetime, timezone, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer

STATUS_FILE = "/app/logs/status.json"
PORT = int(os.environ.get("STATUS_PORT", 8484))
MAX_AGE_HOURS = 24


def check_health():
    """Return (http_status_code, response_dict)."""
    if not os.path.exists(STATUS_FILE):
        return 503, {
            "healthy": False,
            "reason": "status.json not found — no backup has run yet",
        }

    try:
        with open(STATUS_FILE) as f:
            data = json.load(f)
    except Exception as e:
        return 503, {"healthy": False, "reason": f"could not parse status.json: {e}"}

    last_success = data.get("last_success_time")
    if not last_success:
        return 503, {
            "healthy": False,
            "reason": "no successful backup recorded",
            **data,
        }

    try:
        ts = datetime.fromisoformat(last_success).replace(tzinfo=timezone.utc)
    except ValueError:
        return 503, {
            "healthy": False,
            "reason": f"could not parse last_success_time: {last_success!r}",
            **data,
        }

    age = datetime.now(timezone.utc) - ts
    if age > timedelta(hours=MAX_AGE_HOURS):
        hours_ago = int(age.total_seconds() // 3600)
        return 503, {
            "healthy": False,
            "reason": f"last success was {hours_ago}h ago (threshold: {MAX_AGE_HOURS}h)",
            **data,
        }

    return 200, {"healthy": True, **data}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/health"):
            self.send_response(404)
            self.end_headers()
            return

        code, body = check_health()
        payload = json.dumps(body, indent=2).encode()

        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    # Suppress default request logging to stdout — container logs go to syslog
    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"[status-api] Listening on :{PORT}", flush=True)
    server.serve_forever()
