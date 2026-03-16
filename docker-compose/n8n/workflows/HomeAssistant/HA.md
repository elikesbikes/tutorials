# Home Assistant Workflows

## ZHA Zigbee Error Monitor

**Workflow ID:** `ur3QtEjOnDWORazL`
**Trigger:** Manual (click "Execute workflow" in n8n UI)

Connects to Home Assistant and produces a structured health report for your ZHA (Zigbee Home Automation) network.

### How to Run

1. Open the n8n UI
2. Find **ZHA Zigbee Error Monitor**
3. Click **Execute workflow**
4. Click the **Format ZHA Report** node to see the output

### Output Fields

The output is structured JSON — each section is a separate expandable field in n8n's output panel:

| Field | What it shows |
|-------|---------------|
| `status` | `✅ All good` or `⚠️ Issues detected` |
| `run_time` | Timestamp of when the report ran |
| `summary` | Counts: total / offline / weak signal / healthy |
| `offline_devices` | Devices whose `_lqi` sensor is `unavailable` |
| `weak_signal_devices` | Devices with LQI < 50, sorted weakest first, with signal bar |
| `healthy_devices` | All other online devices, sorted by LQI ascending |
| `log_errors` | ZHA/Zigbee lines from `/api/error_log` (last 20) |

### Workflow Nodes

```
Trigger → Get HA Error Log → Get HA States → Format ZHA Report
```

| Node | Endpoint | Notes |
|------|----------|-------|
| Get HA Error Log | `GET /api/error_log` | Plain text; `continueOnFail: true` — workflow continues even if 404 |
| Get HA States | `GET /api/states` | Returns all 2600+ entities; ZHA ones are filtered in the Code node |
| Format ZHA Report | Code node | Detects ZHA devices, builds structured JSON output |

### ZHA Device Detection

ZHA creates dedicated diagnostic sensor entities named `sensor.DEVICE_NAME_lqi` (and optionally `sensor.DEVICE_NAME_rssi`). The Code node finds all entities matching `sensor.*_lqi` or `sensor.*_lqi_N` — these are the source of truth for which devices are ZHA, their signal quality, and online status.

RSSI sensors (`sensor.*_rssi`) are cross-referenced only for devices already found via LQI, avoiding false positives from WiFi/other RSSI sensors.

### Environment Variables

Set in `/home/ecloaiza/devops/docker/n8n/.env`:

| Variable | Value |
|----------|-------|
| `HA_URL` | `http://192.168.5.18:8123` |
| `HA_TOKEN` | Long-lived access token (HA → Profile → Security) |

> Note: Use the IP address directly. The `has` hostname is not resolvable from the n8n container.

### Tuning

- **Weak signal threshold:** Edit `LQI_THRESHOLD` (default: `50`) in the Format ZHA Report Code node. LQI ranges 0–255.
- **Log error limit:** Change `.slice(-20)` in the error log section to show more/fewer lines.

### Known Limitations

- `/api/error_log` returns 404 on some HA setups (Docker, minimal installs). The workflow handles this gracefully — the `log_errors` field will say `(log endpoint not available)`.
- `/api/logbook` was removed — it causes HA to run a heavy DB query that can crash a busy instance.
