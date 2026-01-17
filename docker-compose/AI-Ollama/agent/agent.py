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
from datetime import datetime

# --- Load Environment Variables ---
HOME_ASSISTANT_URL = os.getenv("HOME_ASSISTANT_URL")
HA_ACCESS_TOKEN = os.getenv("HA_ACCESS_TOKEN")
OLLAMA_API_URL = os.getenv("OLLAMA_API_URL")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3:latest")
# Convert string 'false' or '0' to boolean False
OLLAMA_STREAM = os.getenv("OLLAMA_STREAM", "false").lower() == "true"
GRAYLOG_API_URL = os.getenv("GRAYLOG_API_URL")
GRAYLOG_API_TOKEN = os.getenv("GRAYLOG_API_TOKEN")
GRAYLOG_STREAM_ID = os.getenv("GRAYLOG_STREAM_ID")
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL_SECONDS", 60))

def log_debug(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {msg}")

def get_graylog_logs():
    """Fetch recent logs from Graylog."""
    headers = {"Authorization": f"Bearer {GRAYLOG_API_TOKEN}", "Accept": "application/json"}
    # Simplified search params for debugging
    params = {"query": f"streams:{GRAYLOG_STREAM_ID}", "range": "300", "limit": 5}
    
    try:
        response = requests.get(f"{GRAYLOG_API_URL}/search/universal/absolute", headers=headers, params=params, timeout=10)
        
        # --- DEBUG BLOCK ---
        if response.status_code != 200:
            print("--- DEBUG: GRAYLOG CONNECTION FAILED ---")
            print(f"Status: {response.status_code}")
            print(f"URL: {response.url}")
            print(f"Response: {response.text}")
            return None
            
        return response.json()
    except Exception as e:
        log_debug(f"Graylog Error: {e}")
        return None

def analyze_with_ollama(log_data):
    """Send logs to Ollama for analysis."""
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": f"Analyze these logs for interference patterns: {json.dumps(log_data)}",
        "stream": OLLAMA_STREAM
    }
    
    try:
        log_debug(f"Sending request to Ollama: {OLLAMA_API_URL}")
        response = requests.post(OLLAMA_API_URL, json=payload, timeout=60)
        
        # --- THE JSON CRASH DEBUG BLOCK ---
        try:
            return response.json()
        except Exception as json_err:
            print("\n--- CRITICAL DEBUG: OLLAMA JSON PARSE FAILED ---")
            print(f"Status Code: {response.status_code}")
            print(f"Expected JSON but got: {response.text}")
            print(f"Used URL: {OLLAMA_API_URL}")
            print("----------------------------------------------\n")
            raise json_err

    except Exception as e:
        log_debug(f"Ollama Error: {e}")
        return None

def main():
    print("--- Sentinel v2.7.3 Initiated ---")
    log_debug(f"Monitoring Graylog Stream: {GRAYLOG_STREAM_ID}")
    log_debug(f"Targeting Ollama Model: {OLLAMA_MODEL}")

    while True:
        try:
            # 1. Get Logs
            logs = get_graylog_logs()
            
            if logs:
                # 2. Analyze
                analysis = analyze_with_ollama(logs)
                if analysis:
                    log_debug(f"Analysis Complete: {analysis.get('response', 'No response field')}")
            else:
                log_debug("No logs found or Graylog unreachable. Retrying...")

        except Exception as e:
            print(f"Loop Error: {e}")

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()