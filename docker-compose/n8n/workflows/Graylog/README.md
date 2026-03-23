# Graylog WiFi MCP Server

**Author:** Emmanuel Loaiza (Tars)

An n8n workflow that exposes a **Model Context Protocol (MCP) server** giving AI assistants (like Claude) direct, real-time access to WiFi logs stored in Graylog. It bridges your AI tooling with Graylog's log management platform — enabling natural language queries over your network's WiFi event history.

---

## Features

- Query WiFi error logs by severity level and time range
- Search WiFi logs using custom Graylog query strings (e.g., `deauth`, `auth fail`, `beacon loss`)
- Returns up to 50 log entries, sorted newest-first
- Connects to any MCP-compatible AI client (Claude, etc.)

---

## Workflow Architecture

```
[MCP Server Trigger]
        |
        ├──ai_tool──> [get_wifi_errors]
        └──ai_tool──> [search_wifi_logs]
```

| Node | Type | Purpose |
|------|------|---------|
| `MCP Server Trigger` | `@n8n/n8n-nodes-langchain.mcpTrigger` | Receives MCP tool calls and routes them |
| `get_wifi_errors` | `@n8n/n8n-nodes-langchain.toolCode` | Fetches logs filtered by severity level |
| `search_wifi_logs` | `@n8n/n8n-nodes-langchain.toolCode` | Searches logs with a custom Graylog query |

---

## Tools

### `get_wifi_errors`

Fetches WiFi-related error logs from Graylog filtered by severity and time range.

**Parameters:**

| Parameter   | Type    | Default | Description |
|-------------|---------|---------|-------------|
| `minutes`   | integer | `60`    | How far back (in minutes) to search |
| `min_level` | integer | `3`     | Max syslog severity to include (lower = more severe) |

**Syslog severity levels:**

| Level | Name      |
|-------|-----------|
| 0     | EMERGENCY |
| 1     | ALERT     |
| 2     | CRITICAL  |
| 3     | ERROR     |
| 4     | WARNING   |
| 5     | NOTICE    |
| 6     | INFO      |
| 7     | DEBUG     |

> **Example:** `min_level=4` returns WARNING, ERROR, CRITICAL, ALERT, and EMERGENCY messages.

**Output:**

```
Found 2 WiFi log entries:

[2026-03-11T14:22:01.000Z] ERROR | ap-office-01 | Association failed for client 00:11:22:33:44:55
[2026-03-11T14:20:15.000Z] WARNING | ap-lobby-02 | High retry rate detected on channel 6
```

---

### `search_wifi_logs`

Searches WiFi logs using a custom Graylog query string. Use this for targeted searches like specific events (`deauth`, `auth fail`, `disassoc`, `beacon loss`).

**Parameters:**

| Parameter | Type    | Default                    | Description |
|-----------|---------|----------------------------|-------------|
| `query`   | string  | `wifi OR wlan OR wireless` | Graylog search terms |
| `minutes` | integer | `60`                       | Time range in minutes |
| `limit`   | integer | `50`                       | Max number of results |

**Output:**

```
Found 3 log entries for query "deauth":

[2026-03-11T14:25:00.000Z] WARNING | ap-office-01 | Deauth received from client 00:11:22:33:44:55
...
```

If no logs are found:
```
No logs found for query "deauth" in the last 60 minutes.
```

---

## Prerequisites

- A running [n8n](https://n8n.io) instance
- A running [Graylog](https://www.graylog.org) instance with a configured stream containing WiFi logs
- An MCP-compatible AI client (e.g., Claude with MCP support)

---

## Setup

### 1. Import the Workflow

In n8n, go to **Workflows > Import from File** and select `Graylog WiFi MCP Server.json`.

### 2. Configure Environment Variables

Go to **Settings > Environment Variables** in n8n and add:

| Variable            | Description |
|---------------------|-------------|
| `GRAYLOG_API_TOKEN` | Your Graylog API token (used as `token:token` in Basic Auth) |
| `GRAYLOG_STREAM_ID` | The Graylog stream ID to search within |

> **Note:** The Graylog host is hardcoded to `http://192.168.5.20:9000`. Update the URL in both tool nodes' JS code if your Graylog is hosted elsewhere.

### 3. Activate the Workflow

Toggle the workflow to **Active** in n8n.

---

## MCP Client Integration

Register the MCP server endpoint in your AI client using the webhook URL from the MCP Server Trigger node.

**Example Claude MCP config** (`.claude/mcp_servers.json`):

```json
{
  "graylog-wifi": {
    "url": "http://<your-n8n-host>:<port>/mcp/graylog-wifi-mcp"
  }
}
```

Once connected, you can query your WiFi logs naturally:

- *"Check for WiFi errors in the last 30 minutes with severity ERROR or worse."*
- *"Search for any deauth events in the past hour."*
- *"Find beacon loss events from the last 15 minutes."*

---

## Graylog API

Both tools query the Graylog **Universal Relative Search** endpoint:

```
GET /api/search/universal/relative
```

Fields returned: `timestamp`, `source`, `message`, `level`, `facility`

---

## File Structure

```
workflows/
├── Graylog WiFi MCP Server.json   ← Workflow definition
└── Graylog/
    └── README.md                   ← This file
```
