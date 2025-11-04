import os
import requests
import re
from datetime import datetime

# --- Configuration (Pulled from Environment Variables) ---
HA_URL = os.environ.get("HOME_ASSISTANT_URL")
HA_TOKEN = os.environ.get("HA_ACCESS_TOKEN")
OLLAMA_API_URL = os.environ.get("OLLAMA_API_URL")

# --- Log Analysis Parameters ---
LOG_ENDPOINT = "/api/error_log"
HEADERS = {
    "Authorization": f"Bearer {HA_TOKEN}",
    "Content-Type": "application/json"
}
CRITICAL_KEYWORDS = ["ERROR", "CRITICAL", "Timeout", "Failed to connect", "Exception", "Traceback"]
OLLAMA_MODEL = "llama3" # Default model for analysis

def fetch_ha_logs():
    """Fetches the raw error log from Home Assistant."""
    if not HA_URL or not HA_TOKEN:
        print("🚨 ERROR: Home Assistant URL or Access Token is missing from environment variables.")
        return None

    full_url = f"{HA_URL}{LOG_ENDPOINT}"
    print(f"🔗 Attempting to connect to Home Assistant at: {full_url}")

    try:
        response = requests.get(full_url, headers=HEADERS, timeout=10)
        response.raise_for_status() # Raises an exception for 4XX or 5XX status codes

        # The /api/error_log endpoint returns the log content as plain text
        print("✅ Successfully fetched Home Assistant error log.")
        return response.text

    except requests.exceptions.HTTPError as e:
        print(f"❌ HTTP Error fetching logs: {e.response.status_code} - Check URL and Token permissions.")
    except requests.exceptions.ConnectionError:
        print("❌ Connection Error: Could not reach Home Assistant. Is the IP/Port correct?")
    except requests.exceptions.Timeout:
        print("❌ Timeout Error: Request took too long.")
    except Exception as e:
        print(f"❌ An unexpected error occurred: {e}")

    return None

def analyze_logs_for_critical_events(log_content):
    """Parses the log content to find critical lines."""
    critical_events = []

    # Split the log into lines and iterate
    for line in log_content.splitlines():
        # Simple check for critical keywords
        if any(keyword in line for keyword in CRITICAL_KEYWORDS):
            critical_events.append(line.strip())

    print(f"\n🔬 Found {len(critical_events)} critical log entries.")
    return critical_events

def send_to_ollama_for_analysis(critical_events):
    """Sends critical log entries to Ollama for an advanced summary."""
    if not OLLAMA_API_URL:
        print("\n🟡 Skipping Ollama analysis: OLLAMA_API_URL is not set.")
        return

    print(f"\n🤖 Sending critical entries to Ollama for summary using model: {OLLAMA_MODEL}...")

    # Join the critical events into a single block of text for the prompt
    log_block = "\n".join(critical_events)

    prompt = (
        "Analyze the following Home Assistant log entries. Identify the root cause "
        "of the issue (e.g., failed integration, network problem, entity error). "
        "Provide a concise summary and suggest a specific action the user should take.\n\n"
        f"--- LOG ENTRIES ---\n{log_block}"
    )

    ollama_data = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False # Set to False for a single response
    }

    try:
        # Increased timeout to 180 seconds (3 minutes) to allow time for processing 6000+ log lines
        OLLAMA_TIMEOUT_SECONDS = 180 
        ollama_response = requests.post(OLLAMA_API_URL, json=ollama_data, timeout=OLLAMA_TIMEOUT_SECONDS)
        #ollama_response = requests.post(OLLAMA_API_URL, json=ollama_data, timeout=60)
        ollama_response.raise_for_status()

        # Ollama API returns a JSON object with the response text
        summary = ollama_response.json().get("response", "No response text received from Ollama.")

        print("\n--- 🧠 AI Analysis Summary ---")
        print(summary)
        print("------------------------------")

    except requests.exceptions.HTTPError as e:
        print(f"❌ Ollama HTTP Error: {e.response.status_code}. Ensure Ollama is running and the model is loaded.")
    except requests.exceptions.ConnectionError:
        print("❌ Ollama Connection Error: Cannot connect to Ollama service.")
    except requests.exceptions.Timeout:
        print("❌ Ollama Timeout Error: Model took too long to generate a response.")
    except Exception as e:
        print(f"❌ An unexpected error occurred during Ollama analysis: {e}")

def main():
    log_content = fetch_ha_logs()

    if log_content:
        critical_events = analyze_logs_for_critical_events(log_content)

        if critical_events:
            send_to_ollama_for_analysis(critical_events)
        else:
            print("🎉 Log check complete: No critical errors found for AI analysis.")

if __name__ == "__main__":
    main()
