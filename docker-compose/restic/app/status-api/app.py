#!/usr/bin/env python3
"""
HTTP status server for restic backup monitoring (multi-job).

Reads per-job status files from /app/logs/status/<job>.json and returns:
  200  if every job's last_success_time is within that job's max_age_hours
  503  if ANY job is stale/failed-with-no-success/unreadable, or no job
       has ever run

The JSON body always contains a "jobs" map with per-job detail, so a single
Uptime Kuma monitor covers all jobs and the body says which one is unhealthy.

Transitional: if no per-job status files exist yet but the legacy single-job
/app/logs/status.json does, it is reported as job "_legacy" — this keeps the
monitor green between deploying the multi-job code and the first new-style
run. Safe to remove once all hosts have per-job status files.
"""

import glob
import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

STATUS_DIR = "/app/logs/status"
LEGACY_STATUS_FILE = "/app/logs/status.json"
PORT = int(os.environ.get("STATUS_PORT", 8484))
DEFAULT_MAX_AGE_HOURS = 25


def check_job(data):
    """Return (healthy: bool, detail: dict) for one job's status data."""
    detail = dict(data)
    max_age = data.get("max_age_hours", DEFAULT_MAX_AGE_HOURS)

    last_success = data.get("last_success_time")
    if not last_success:
        detail["healthy"] = False
        detail["reason"] = "no successful backup recorded"
        return False, detail

    try:
        ts = datetime.fromisoformat(last_success).replace(tzinfo=timezone.utc)
    except ValueError:
        detail["healthy"] = False
        detail["reason"] = f"could not parse last_success_time: {last_success!r}"
        return False, detail

    age = datetime.now(timezone.utc) - ts
    age_hours = age.total_seconds() / 3600
    detail["age_hours"] = round(age_hours, 1)

    if age_hours > max_age:
        detail["healthy"] = False
        detail["reason"] = (
            f"last success was {int(age_hours)}h ago (threshold: {max_age}h)"
        )
        return False, detail

    detail["healthy"] = True
    return True, detail


def load_status_files():
    """Return {job_name: data_or_error_dict} from per-job status files."""
    jobs = {}
    for path in sorted(glob.glob(os.path.join(STATUS_DIR, "*.json"))):
        name = os.path.splitext(os.path.basename(path))[0]
        try:
            with open(path) as f:
                jobs[name] = json.load(f)
        except Exception as e:
            jobs[name] = {"_parse_error": f"could not parse {path}: {e}"}
    return jobs


def check_health():
    """Return (http_status_code, response_dict)."""
    job_data = load_status_files()

    # Transitional fallback for hosts that haven't run a multi-job backup yet
    if not job_data and os.path.exists(LEGACY_STATUS_FILE):
        try:
            with open(LEGACY_STATUS_FILE) as f:
                job_data["_legacy"] = json.load(f)
        except Exception as e:
            job_data["_legacy"] = {"_parse_error": f"could not parse legacy status.json: {e}"}

    if not job_data:
        return 503, {
            "healthy": False,
            "reason": "no job status files found — no backup has run yet",
            "jobs": {},
        }

    jobs = {}
    all_healthy = True
    for name, data in job_data.items():
        if "_parse_error" in data:
            jobs[name] = {"healthy": False, "reason": data["_parse_error"]}
            all_healthy = False
            continue
        healthy, detail = check_job(data)
        jobs[name] = detail
        all_healthy = all_healthy and healthy

    body = {"healthy": all_healthy, "jobs": jobs}
    if not all_healthy:
        unhealthy = sorted(n for n, j in jobs.items() if not j.get("healthy"))
        body["reason"] = "unhealthy jobs: " + ", ".join(unhealthy)
    return (200 if all_healthy else 503), body


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
