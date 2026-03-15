# Home Assistant Workflows

## ZHA Zigbee Error Monitor

**Workflow ID:** `ur3QtEjOnDWORazL`
**Trigger:** Manual (click "Execute workflow" in n8n UI)
**File:** `HA_ZHA_Monitor.json`

Connects to Home Assistant and produces a health report for your ZHA (Zigbee Home Automation) network. Three HA API endpoints are queried in parallel and the results are formatted into four sections.

### Output Sections

| Section | Source | What it shows |
|---------|--------|---------------|
| **1. ZHA Error Log Entries** | `/api/error_log` | Lines from the HA error log matching `zha` or `zigbee` (last 30) |
| **2. Unavailable ZHA Devices** | `/api/states` | Devices with `state = unavailable` that have `lqi`/`rssi` attributes |
| **3. Weak Signal Devices** | `/api/states` | ZHA devices with LQI < 50, sorted weakest first |
| **4. Recent ZHA Logbook Events** | `/api/logbook` | Last 24h of logbook entries mentioning ZHA/Zigbee (up to 20) |

### How to Run

1. Open [n8n UI](http://localhost:5678)
2. Find **ZHA Zigbee Error Monitor**
3. Click **Execute workflow**
4. Click the **ZHA Health Report** node to see the formatted output in the `report` field

### Environment Variables

Set in `/home/ecloaiza/devops/docker/n8n/.env`:

| Variable | Description |
|----------|-------------|
| `HA_URL` | Home Assistant base URL, e.g. `http://has:8123` |
| `HA_TOKEN` | Long-lived access token (HA → Profile → Security) |

### ZHA Entity Detection

Devices are identified as ZHA entities by the presence of `lqi` or `rssi` attributes — Zigbee-specific fields only populated by ZHA. This avoids false positives from non-Zigbee entities.

### Tuning

To adjust the weak signal threshold, edit the `LQI_THRESHOLD` constant (default: `50`) in the **ZHA Health Report** Code node. LQI ranges from 0 (no signal) to 255 (perfect).
