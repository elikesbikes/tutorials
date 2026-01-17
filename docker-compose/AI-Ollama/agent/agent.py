#!/usr/bin/env python3
"""
AI LOG SENTINEL v2.7.3 - Strict Log Separation
==============================================

CHANGE LOG:
-----------
2026-01-17 | v2.7.3 | UPGRADE: Split Zigbee audits into dedicated zigbee_mesh.log.
2026-01-17 | v2.7.2 | IMPROVED: Added console summary for Zigbee entity count.
2026-01-17 | v2.7.1 | UPGRADE: Unified logging for Zigbee & Wi-Fi in ha_alerts.log.
2026-01-17 | v2.6.5 | UPDATE: Preserved full cumulative change log history.
"""

import os
import time
import requests
import json
from collections import Counter
from datetime import datetime, timedelta, timezone

# --- CONFIG ---
GRAYLOG_URL = os.getenv('GRAYLOG_API_URL', '').rstrip('/')
GRAYLOG_TOKEN = os.getenv('GRAYLOG_API_TOKEN')
STREAM_ID = os.getenv('GRAYLOG_STREAM_ID')
OLLAMA_URL = os.getenv('OLLAMA_API_URL')
OLLAMA_MODEL = os.getenv('OLLAMA_MODEL', 'llama3.2')
OLLAMA_NUM_CTX = int(os.getenv('OLLAMA_NUM_CTX', 16384))
INTERVAL = int(os.getenv('CHECK_INTERVAL_SECONDS', 60))

# HA Config
HA_URL = os.getenv('HOME_ASSISTANT_URL')
HA_TOKEN = os.getenv('HA_ACCESS_TOKEN')

# --- LOG PATHS (Strictly Separated) ---
STATE_FILE = "/app/output/last_timestamp.txt"
WIFI_LOG = "/app/output/wifi_interference.log"  # Strictly Graylog Wi-Fi
ZIGBEE_LOG = "/app/output/zigbee_mesh.log"      # Strictly HA Zigbee
HA_LOG = "/app/output/ha_alerts.log"            # UI Push History

class StrictSeparatorSentinel:
    def __init__(self):
        self.version = "2.7.3"
        self.last_heartbeat = datetime.now()
        print(f"--- Sentinel v{self.version} Initiated ---")
        print(f"Logs: {WIFI_LOG} (Wi-Fi) | {ZIGBEE_LOG} (Zigbee)")

    def push_to_ha(self, title, message, tag):
        """The bridge to HA Sidebar. Records which type of alert was sent."""
        if not HA_URL or not HA_TOKEN: return 
        url = f"{HA_URL}/api/services/persistent_notification/create"
        headers = {"Authorization": f"Bearer {HA_TOKEN}", "Content-Type": "application/json"}
        payload = {"title": title, "message": message, "notification_id": f"sentinel_{tag}_alert"}
        
        try:
            resp = requests.post(url, headers=headers, json=payload, timeout=10)
            with open(HA_LOG, "a") as f:
                f.write(f"[{datetime.now()}] [HA_PUSH] [{tag.upper()}] {title} | Status: {resp.status_code}\n")
        except Exception as e:
            print(f"HA Push Error: {e}")

    def get_zigbee_states(self):
        url = f"{HA_URL}/api/states"
        headers = {"Authorization": f"Bearer {HA_TOKEN}", "Content-Type": "application/json"}
        try:
            resp = requests.get(url, headers=headers, timeout=15)
            # Filter logic: IDs with 'zigbee' or 'linkquality'
            return [s for s in resp.json() if 'linkquality' in s['entity_id'] or 'zigbee' in s['entity_id'].lower()]
        except Exception as e:
            print(f"Zigbee Pull Failed: {e}")
            return []

    def analyze_stability(self, data, mesh_mode=False):
        if mesh_mode:
            system_role = "You are a Zigbee Mesh Expert. Analyze these states for 'unavailable' nodes. Format: SCORE: [1-10], STATUS: [ZIGBEE_ISSUES/OK], SUMMARY: [Text]"
            prompt = "\n".join([f"{i['entity_id']}: {i['state']}" for i in data])
        else:
            system_role = "You are an RF Engineer. Analyze logs for Wi-Fi flapping. Format: SCORE: [1-10], STATUS: [RF_INTERFERENCE/OK], SUMMARY: [Text]"
            prompt = "\n".join([f"[{l['message']['timestamp']}] {l['message']['message']}" for l in data])

        payload = {
            "model": OLLAMA_MODEL, "system": system_role, "prompt": prompt,
            "stream": False, "options": {"num_ctx": OLLAMA_NUM_CTX}
        }
        
        try:
            res = requests.post(OLLAMA_URL, json=payload, timeout=180)
            return res.json().get('response', 'Inference Failure')
        except Exception as e:
            return f"SCORE: 0\nSTATUS: ERROR\nSUMMARY: Ollama Error: {e}"

    def run(self):
        while True:
            try:
                # 1. Zigbee Mesh Audit (To zigbee_mesh.log)
                z_data = self.get_zigbee_states()
                if z_data:
                    z_analysis = self.analyze_stability(z_data, mesh_mode=True)
                    with open(ZIGBEE_LOG, "a") as f:
                        f.write(f"\n[{datetime.now()}] [ZIGBEE_AUDIT]\n{z_analysis}\n---\n")
                    if "ZIGBEE_ISSUES" in z_analysis:
                        self.push_to_ha("🚨 Zigbee Mesh Alert", z_analysis, "zigbee")

                # 2. Wi-Fi Graylog Audit (To wifi_interference.log)
                since = self.get_last_ts()
                params = {"query": f"streams:{STREAM_ID}", "from": since, "to": datetime.now(timezone.utc).isoformat(), "fields": "message,timestamp", "sort": "timestamp:asc"}
                resp = requests.get(f"{GRAYLOG_URL}/search/universal/absolute", params=params, auth=(GRAYLOG_TOKEN, 'token'), timeout=30)
                
                if resp.status_code == 200:
                    msgs = resp.json().get('messages', [])
                    if msgs:
                        w_analysis = self.analyze_stability(msgs, mesh_mode=False)
                        with open(WIFI_LOG, "a") as f:
                            f.write(f"\n[{datetime.now()}] [WIFI_AUDIT]\n{w_analysis}\n---\n")
                        if "RF_INTERFERENCE" in w_analysis:
                            self.push_to_ha("🚨 Wi-Fi Stability Alert", w_analysis, "wifi")
                        with open(STATE_FILE, "w") as f: f.write(msgs[-1]['message']['timestamp'])
                    else:
                        self.handle_heartbeat()
                
            except Exception as e:
                print(f"Loop Error: {e}")
            
            time.sleep(INTERVAL)

    def handle_heartbeat(self):
        if datetime.now() - self.last_heartbeat > timedelta(hours=4):
            self.push_to_ha("Sentinel Pulse", "System running. Monitoring Wi-Fi & Zigbee separately.", "pulse")
            self.last_heartbeat = datetime.now()

    def get_last_ts(self):
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE, "r") as f: return f.read().strip()
        return (datetime.now(timezone.utc) - timedelta(minutes=10)).isoformat()

if __name__ == "__main__":
    StrictSeparatorSentinel().run()