#!/usr/bin/env python3
"""
Minimal HTTP server that exposes garmin_fetch.py to n8n via HTTP.

Runs inside the container on localhost:8765 (not exposed externally).
n8n's HTTP Request node calls GET http://localhost:8765/fetch to trigger
a sync and receive the JSON result.

Started automatically by entrypoint.sh alongside n8n.
"""

import json
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

FETCH_SCRIPT = Path("/home/node/garmin/garmin_fetch.py")
PORT = 8765


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/fetch":
            self._respond(404, {"status": "error", "message": "Not found"})
            return

        if not FETCH_SCRIPT.exists():
            self._respond(503, {"status": "error", "message": f"{FETCH_SCRIPT} not found"})
            return

        try:
            proc = subprocess.run(
                ["python3", str(FETCH_SCRIPT)],
                capture_output=True,
                text=True,
                timeout=120,
            )
            output = proc.stdout.strip()
            # Filter out Python deprecation warnings (go to stderr)
            try:
                result = json.loads(output)
            except Exception:
                result = {"status": "error", "message": f"Bad output: {output}", "stderr": proc.stderr}

            status = 200 if result.get("status") == "ok" else 500
            self._respond(status, result)

        except subprocess.TimeoutExpired:
            self._respond(504, {"status": "error", "message": "Fetch timed out after 120s"})
        except Exception as e:
            self._respond(500, {"status": "error", "message": str(e)})

    def _respond(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # suppress per-request access logs


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Garmin server listening on :{PORT}", flush=True)
    server.serve_forever()
