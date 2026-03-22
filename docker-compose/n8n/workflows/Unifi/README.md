# UniFi Workflows

This folder contains two n8n workflows for interacting with a UniFi network controller.

---

## 1. UniFi.json

A simple manual workflow for retrieving connected clients from the UniFi network.

**Trigger:** Manual (click "Execute workflow")

**Flow:**
1. **Login to UniFi** — Authenticates against the UniFi controller at `192.168.1.1` using `UNIFI_USER` and `UNIFI_PASS` environment variables. Returns session cookies and CSRF token.
2. **Get Clients** — Queries the `/stat/sta` endpoint using the session credentials to retrieve all currently connected stations.
3. **Format Response** — Normalizes the raw API data into a clean list with fields: `name`, `ip`, `mac`, `network` (SSID or "Wired"), `signal` (dBm), `type` (WiFi/Wired), and `manufacturer`.

**Output:** JSON object with `total` count and a `clients` array.

**Environment variables required:**
- `UNIFI_USER`
- `UNIFI_PASS`

---

## 2. UniFi MCP Server.json

An MCP (Model Context Protocol) server that exposes UniFi network data as tools callable by AI agents. It connects to the UniFi controller at `router.home.elikesbikes.com`.

**Trigger:** MCP Server Trigger (webhook path: `a65e26aa-0f3a-47d2-8cc0-5da81b8e9765`)

**Exposed tools:**

| Tool | Description |
|------|-------------|
| `get_connected_clients` | Returns all devices currently connected to the network with name, IP, MAC, type, SSID, signal strength, and manufacturer. |
| `get_error_logs` | Fetches network alarms and alerts. Returns up to 50 entries with time, type, message, severity (active/resolved), and device name. |
| `get_high_tx_retries` | Identifies access points with TX retry rates above 20% using the same formula as the UniFi UI. Reports AP name, radio, channel, packet counts, and retry percentage. |
| `get_channel_conflicts` | Detects co-channel interference by finding access points sharing the same channel. Includes recommendations for 2.4GHz (channels 1, 6, 11) and 5GHz auto-assignment. |

Each tool authenticates independently against the UniFi API using session cookies and CSRF token extraction.

**Environment variables required:**
- `UNIFI_USER`
- `UNIFI_PASS`
