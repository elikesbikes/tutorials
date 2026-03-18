#!/usr/bin/env python3
import requests
import json
import time
import signal
import sys
import logging
from logging.handlers import RotatingFileHandler
from collections import deque
import threading
import os

# --- Configuration ---
# Read the hostname from the environment, defaulting to the expected service name.
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "ai-ollama-prod-1")
OLLAMA_URL = f"http://{OLLAMA_HOST}:11434/api/generate"
OLLAMA_MODEL = "llama3"

LOG_FILE_PATH = "/app/logs/input_logs.log"
RESULTS_FILE_PATH = "/app/output/llm_analysis_output.txt"

MAX_CRITICAL_LINES = 50
LOOP_DELAY_SECONDS = 300
OLLAMA_TIMEOUT = 900              # Set to 15 minutes (900s) for streaming safety
OLLAMA_RETRIES = 3
OLLAMA_RETRY_INITIAL_DELAY = 5

# Logging config
LOG_STDOUT_LEVEL = logging.INFO
LOG_FILE = "/app/logs/agent_runtime.log"
LOG_FILE_MAX_BYTES = 5 * 1024 * 1024
LOG_FILE_BACKUP_COUNT = 3

SYSTEM_PROMPT = f"""
You are an expert DevOps engineer specializing in analyzing application logs for stability issues.

Your primary task is to review the provided log data and produce a concise, actionable report.

Your response MUST STRICTLY follow this Markdown format:
## 1. Summary
[A 1-2 sentence summary of the current system status and any potential issues.]

## 2. Critical Events
[List the 3 most critical or recent ERROR/WARN events. For each event, provide the raw log line and a one-sentence technical explanation of its significance.]

## 3. Recommended Action
[Provide one clear, actionable step that should be taken next to investigate or resolve the root cause.]
"""

# --- Setup logging ---
logger = logging.getLogger("ai_log_agent")
logger.setLevel(logging.DEBUG)

# FIX: Clear handlers to prevent duplicate messages
if logger.hasHandlers():
    logger.handlers.clear()

# ⬇️ CONSOLE HANDLER (ch) HAS BEEN REMOVED TO PREVENT MIXING LOGGING WITH LLM OUTPUT ⬇️

try:
    # Rotating File Handler: Writes all agent runtime logs to agent_runtime.log
    fh = RotatingFileHandler(LOG_FILE, maxBytes=LOG_FILE_MAX_BYTES, backupCount=LOG_FILE_BACKUP_COUNT)
    fh.setLevel(logging.DEBUG)
    fh_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    fh.setFormatter(fh_formatter)
    logger.addHandler(fh)
except Exception as e:
    # If file logging fails, fall back to console (which will mix with LLM output, but survive)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(LOG_STDOUT_LEVEL)
    ch_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    ch.setFormatter(ch_formatter)
    logger.addHandler(ch)
    logger.warning("Could not set up file logging (%s). Proceeding with console only.", e)


shutdown_event = threading.Event()

# --- Helper functions ---

def handle_exit(signum, frame):
    """Signal handler to start graceful shutdown."""
    logger.info("Received shutdown signal (%s). Initiating graceful shutdown...", signum)
    shutdown_event.set()

signal.signal(signal.SIGINT, handle_exit)
signal.signal(signal.SIGTERM, handle_exit)

def get_critical_logs(file_path):
    # Includes INFO to ensure analysis runs if only info/warning logs are present
    keywords = ["ERROR", "WARN", "WARNING", "EXCEPTION", "FATAL", "CRITICAL", "FAILURE", "INFO"]
    critical_lines = deque(maxlen=MAX_CRITICAL_LINES)
    try:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                if any(kw in line.upper() for kw in keywords):
                    critical_lines.append(line.rstrip("\n"))
    except FileNotFoundError:
        logger.error("Log file not found at %s. Is the volume mounted correctly?", file_path)
        return []
    except Exception as e:
        logger.exception("Unexpected error while reading logs: %s", e)
        return []
    return list(critical_lines)

def analyze_logs(logs):
    """
    Build the prompt and send logs to Ollama for streaming analysis.
    Prints output to stdout in real-time (captured by Docker redirection)
    and returns the full combined response string.
    """
    if not logs:
        return "No critical logs found to analyze."

    log_data_str = "\n".join(logs)
    prompt_template = f"{SYSTEM_PROMPT}\n\n--- LOG DATA ---\n{log_data_str}"

    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt_template,
        "stream": True,
        "options": {
            "num_ctx": 4096
        }
    }

    logger.info("Submitting request with %d critical lines to Ollama for streaming...", len(logs))

    try:
        # Use requests.post for streaming; use a long timeout.
        response = requests.post(OLLAMA_URL, json=payload, stream=True, timeout=OLLAMA_TIMEOUT)
        response.raise_for_status()

        full_response = ""

        # ⬇️ Stream output to stdout ⬇️
        print("\n--- 🧠 AI Analysis Stream Start ---", file=sys.stdout)

        for line in response.iter_lines():
            if line:
                try:
                    chunk = json.loads(line)
                    if 'response' in chunk:
                        response_token = chunk['response']

                        # Print to stdout (captured by llm_analysis_output.txt)
                        print(response_token, end="", flush=True, file=sys.stdout)

                        full_response += response_token

                    if chunk.get("done"):
                        break

                except json.JSONDecodeError:
                    continue

        print("\n--- 🧠 AI Analysis Stream End ---", file=sys.stdout)
        return full_response

    except requests.exceptions.RequestException as e:
        msg = f"ERROR: Ollama streaming request failed: {e}"
        logger.error(msg)
        return msg

def persist_analysis(result_text):
    # This function is retained but now serves mainly to log the completion status
    pass

# --- Main loop ---
def main_loop():
    logger.info("AI Log Analysis Agent started.")
    logger.info("Targeting model: %s at %s", OLLAMA_MODEL, OLLAMA_HOST)
    logger.info("Scanning log file: %s", LOG_FILE_PATH)

    while not shutdown_event.is_set():
        try:
            critical_logs = get_critical_logs(LOG_FILE_PATH)

            if not critical_logs:
                logger.info("No critical logs found in the last cycle.")
            else:
                analysis_result = analyze_logs(critical_logs)
                logger.info("Analysis run complete. Results captured by Docker redirection.")

        except Exception as e:
            logger.exception("FATAL AGENT ERROR: %s", e)

        logger.debug("Sleeping for %ds (or until shutdown)...", LOOP_DELAY_SECONDS)
        shutdown_event.wait(LOOP_DELAY_SECONDS)

    logger.info("Shutdown event detected. Exiting main loop.")

if __name__ == "__main__":
    try:
        main_loop()
    except KeyboardInterrupt:
        logger.info("KeyboardInterrupt received. Setting shutdown flag.")
        shutdown_event.set()
    finally:
        logger.info("Agent shutdown complete.")
        for h in logger.handlers:
            try:
                h.flush()
            except Exception:
                pass