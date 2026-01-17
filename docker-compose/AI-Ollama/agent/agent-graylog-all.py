#!/usr/bin/env python3
"""
AI LOG SENTINEL: Graylog + Ollama Anomaly Detector
==================================================

DESCRIPTION:
    A stateful, private AI agent that monitors Graylog syslogs in real-time
    and uses a local LLM (Ollama) to perform behavioral anomaly detection.

CHANGE LOG:
-----------
2026-01-14 | v1.3.1 | Added Verbose Logging to troubleshoot empty output files.
2026-01-14 | v1.3.0 | Added URL path validation to prevent HTML/404 mismatches.
2026-01-14 | v1.2.9 | Added JSON error trapping to handle empty API responses.
2026-01-14 | v1.2.8 | Added analysis persistence & Quadro P4000 VRAM optimizations.
2026-01-14 | v1.2.7 | Fixed UTC compatibility for Python 3.12 (timezone-aware).

PREREQUISITES:
--------------
1. Hardware: NVIDIA GPU (Quadro P4000) with NVIDIA Container Toolkit.
2. SIEM: Graylog 7.0 instance with a Stream configured for syslogs.
3. AI Engine: Ollama running `llama3.2`.
"""

import os
import time
import requests
import json
import sys
from datetime import datetime, timedelta, timezone

# --- METADATA ---
__version__ = os.getenv('AGENT_VERSION', '1.3.1')

# --- CONFIG VALIDATION & PATH FIXING ---
def validate_url(url):
    """Ensures the Graylog URL is targeting the API endpoint, not the Web UI."""
    if not url:
        return ""
    if not url.endswith('/api'):
        print(f"v{__version__} NOTICE: Appending /api to GRAYLOG_API_URL")
        return f"{url.rstrip('/')}/api"
    return url

# Environment Variables
GRAYLOG_URL = validate_url(os.getenv('GRAYLOG_API_URL'))
GRAYLOG_TOKEN = os.getenv('GRAYLOG_API_TOKEN')
STREAM_ID = os.getenv('GRAYLOG_STREAM_ID')
OLLAMA_URL = os.getenv('OLLAMA_API_URL')
OLLAMA_MODEL = os.getenv('OLLAMA_MODEL', 'llama3.2')
INTERVAL = int(os.getenv('CHECK_INTERVAL_SECONDS', 60))

# Persistent Paths
STATE_FILE = "/app/output/last_timestamp.txt"
OUTPUT_FILE = "/app/output/llm_analysis_output.txt"

def get_last_ts():
    """Reads the high-water mark from the state file."""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            return f.read().strip()
    return (datetime.now(timezone.utc) - timedelta(minutes=10)).isoformat()

def write_to_log(status, analysis):
    """Writes AI reasoning results to the persistent volume."""
    try:
        with open(OUTPUT_FILE, "a") as f:
            f.write(f"\n--- v{__version__} | {datetime.now()} | STATUS: {status} ---\n")
            f.write(f"Model: {OLLAMA_MODEL}\n")
            f.write(f"AI Response: {analysis}\n")
            f.write("-" * 50 + "\n")
    except Exception as e:
        print(f"CRITICAL: Cannot write to {OUTPUT_FILE}: {e}")

def analyze_with_ollama(logs):
    """Sends log batch to local Ollama instance for behavioral analysis."""
    log_summary = "\n".join([f"[{l['message']['timestamp']}] {l['message']['message']}" for l in logs])
    
    prompt = (
        f"You are a security expert. Analyze the following batch of system logs. "
        f"If the logs represent normal system operation, reply ONLY with the word 'NORMAL'. "
        f"If you detect an anomaly, security threat, or hardware failure, provide a concise summary.\n\n"
        f"LOG DATA:\n{log_summary}"
    )
    
    try:
        # 120s timeout allows for Quadro P4000 "Low VRAM" latency
        res = requests.post(
            OLLAMA_URL, 
            json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False}, 
            timeout=120 
        )
        
        if not res.text.strip():
            return "OLLAMA_ERROR: Received empty response body."
            
        try:
            return res.json().get('response', 'NO_RESPONSE_FIELD_IN_JSON')
        except json.JSONDecodeError:
            return f"OLLAMA_ERROR: Non-JSON response received: {res.text[:100]}"
            
    except requests.exceptions.Timeout:
        return "OLLAMA_ERROR: Inference timed out (Check GPU VRAM/Load)."
    except Exception as e:
        return f"OLLAMA_ERROR: Connection failed: {e}"

if __name__ == "__main__":
    print(f"--- Starting Graylog-Ollama-Sentinel v{__version__} ---")
    print(f"Monitoring Stream: {STREAM_ID}")
    
    while True:
        try:
            since = get_last_ts()
            to_time = datetime.now(timezone.utc).isoformat()
            
            # 1. Fetch Logs from Graylog
            params = {
                "query": f"streams:{STREAM_ID}",
                "from": since,
                "to": to_time,
                "fields": "message,timestamp",
                "sort": "timestamp:asc"
            }
            
            headers = {
                "Accept": "application/json",
                "X-Requested-By": "cli-sentinel"
            }
            
            resp = requests.get(
                f"{GRAYLOG_URL}/search/universal/absolute", 
                params=params, 
                auth=(GRAYLOG_TOKEN, 'token'), 
                headers=headers,
                timeout=30
            )
            
            if resp.status_code == 200:
                try:
                    data = resp.json()
                    messages = data.get('messages', [])
                    
                    if messages:
                        print(f"[{datetime.now()}] v{__version__} Sending {len(messages)} logs to AI...")
                        
                        # 2. Analyze with Ollama
                        analysis_result = analyze_with_ollama(messages)
                        
                        # 3. Write to persistent log (v1.3.1 writes ALL for debugging)
                        write_to_log("SUCCESS", analysis_result)
                        
                        # 4. Update State
                        newest_ts = messages[-1]['message']['timestamp']
                        with open(STATE_FILE, "w") as f:
                            f.write(newest_ts)
                    else:
                        print(f"[{datetime.now()}] No new logs found since {since}")
                        
                except json.JSONDecodeError:
                    print(f"ERROR: Graylog API returned non-JSON: {resp.text[:100]}")
            else:
                print(f"Graylog API Error {resp.status_code}: {resp.text}")

        except Exception as e:
            print(f"Runtime Loop Error: {e}")

        time.sleep(INTERVAL)