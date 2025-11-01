#!/usr/bin/env python3

import requests
import time

OLLAMA_API_URL = "http://localhost:11434/api/generate"
UPTIME_KUMA_API = "http://192.168.5.67:3001/api/v1/metrics"  # Corrected metrics endpoint
UPTIME_KUMA_API_KEY = "uk2_9fmdiV_ddZweFdJ_WroQ-Gp_e-y3qyhbYd2InpH1"  # Replace with your API key
UPTIME_KUMA_USERNAME = "ecloaiza"  # Replace with your Uptime Kuma username

def get_kuma_metrics():
    """ Fetch the system performance metrics from Uptime Kuma API """
    headers = {
        "Authorization": f"Bearer {UPTIME_KUMA_API_KEY}",
        "Username": UPTIME_KUMA_USERNAME  # Add username if necessary
    }
    response = requests.get(UPTIME_KUMA_API, headers=headers)
    response.raise_for_status()  # Will raise an error for bad status codes
    return response.text  # Metrics are usually returned as raw text (Prometheus-style)

def query_ollama(prompt):
    """ Query Ollama for AI analysis based on the provided prompt """
    payload = {"model": "llama3", "prompt": prompt, "stream": False}
    response = requests.post(OLLAMA_API_URL, json=payload)
    return response.json()["response"]

def main():
    """ Main function to pull Uptime Kuma metrics and query Ollama """
    metrics = get_kuma_metrics()  # Get Uptime Kuma metrics
    prompt = (
        f"Here are the current Uptime Kuma system metrics:\n"
        f"{metrics}\n"
        "Can you analyze these metrics and provide insights, especially if any metrics indicate a problem?"
    )
    # Query Ollama with the metrics data for analysis
    analysis = query_ollama(prompt)
    print(f"AI Analysis based on metrics:\n{analysis}\n")

if __name__ == "__main__":
    main()
