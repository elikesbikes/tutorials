# Home Assistant Workflows

## ZHA Zigbee Error Monitor

**Workflow ID:** `ur3QtEjOnDWORazL`

Connects to Home Assistant and produces a structured health report for your ZHA (Zigbee Home Automation) network.

### Triggers

| Trigger | When |
|---------|------|
| **Manual** | Click "Execute workflow" in the n8n UI anytime |
| **Schedule** | Daily at 4:00 PM ET — sends alerts if any issues are detected |

> The workflow must be **activated** (toggle in top-right of n8n UI) for the schedule to fire.

### How to Run Manually

1. Open the n8n UI
2. Find **ZHA Zigbee Error Monitor**
3. Click **Execute workflow**
4. Click the **Format ZHA Report** node to see the output

### Output Fields

The output is structured JSON — each section is a separate expandable field in n8n's output panel:

| Field | What it shows |
|-------|---------------|
| `status` | `All good` or `Issues detected` |
| `run_time` | Timestamp of when the report ran |
| `alert_title` | Pre-built notification title used by ntfy and Signal |
| `alert_body` | Pre-built notification body used by ntfy and Signal |
| `summary` | Counts: total / offline / weak signal / low battery / healthy |
| `offline_devices` | Devices whose `_lqi` sensor is `unavailable` |
| `weak_signal_devices` | Devices with LQI < 50, sorted weakest first, with signal bar |
| `low_battery_devices` | Devices with battery < 10%, sorted lowest first |
| `healthy_devices` | All other online devices, sorted by LQI ascending |
| `log_errors` | ZHA/Zigbee lines from `/api/error_log` (last 20) |

### Workflow Nodes

```
Manual Trigger ──┐
                 ├──► Get HA Error Log → Get HA States → Format ZHA Report → Any issues? ──► Send ntfy Alert
Daily 4PM ───────┘                                                              (IF true)  └► Send Signal Alert
```

| Node | Type | Notes |
|------|------|-------|
| Get HA Error Log | HTTP Request | `GET /api/error_log` — plain text, `continueOnFail: true` |
| Get HA States | HTTP Request | `GET /api/states` — all 2600+ entities, ZHA filtered in code |
| Format ZHA Report | Code | Detects ZHA devices, battery sensors, builds structured JSON |
| Any issues? | IF | Fires if `summary.offline > 0` OR `summary.low_battery > 0` |
| Send ntfy Alert | HTTP Request | `POST https://ntfy.home.elikesbikes.com/ha_alerts` |
| Send Signal Alert | HTTP Request | `GET https://signal.callmebot.com/signal/send.php` |

### Notifications

Both ntfy and Signal fire in parallel when issues are detected. They use the same `alert_title` and `alert_body` fields.

**Example message:**
```
Title : 2 offline, 1 low battery - ZHA Alert

OFFLINE:
- ThirdReality-Office-motion
- Aeotec-office-button

LOW BATTERY:
- ThirdReality-Garage-sensor (4%)
```

#### ntfy
- URL: `https://ntfy.home.elikesbikes.com/ha_alerts`
- Priority: `high` — Tags: `warning, rotating_light`
- Note: HTTP headers must be ASCII-only — no emoji in the `Title` header

#### Signal (via CallMeBot)
- URL: `https://signal.callmebot.com/signal/send.php`
- Phone ID: `a060b503-a21e-43f4-834a-ac4519a830f2`
- API key stored directly in the node

### ZHA Device Detection

ZHA creates dedicated diagnostic sensor entities named `sensor.DEVICE_NAME_lqi` (and optionally `sensor.DEVICE_NAME_rssi`). The Code node finds all entities matching `sensor.*_lqi` or `sensor.*_lqi_N` — these are the source of truth for which devices are ZHA, their signal quality, and online status.

RSSI sensors (`sensor.*_rssi`) are cross-referenced only for devices already found via LQI, avoiding false positives from WiFi/other RSSI sensors.

Battery sensors are detected via `device_class: battery` or `unit_of_measurement: %` + `battery` in the entity ID.

### Environment Variables

Set in `/home/ecloaiza/devops/docker/n8n/.env`:

| Variable | Value |
|----------|-------|
| `HA_URL` | `http://192.168.5.18:8123` |
| `HA_TOKEN` | Long-lived access token (HA → Profile → Security) |

> Note: Use the IP address directly. The `has` hostname is not resolvable from the n8n container.

### Tuning

- **Weak signal threshold:** Edit `LQI_THRESHOLD` (default: `50`) in the Format ZHA Report Code node. LQI ranges 0–255.
- **Low battery threshold:** Edit `BATT_THRESHOLD` (default: `10`) in the Format ZHA Report Code node.
- **Log error limit:** Change `.slice(-20)` in the error log section to show more/fewer lines.

### Known Limitations

- `/api/error_log` returns 404 on some HA setups (Docker, minimal installs). The workflow handles this gracefully — the `log_errors` field will say `(log endpoint not available)`.
- `/api/logbook` was removed — it causes HA to run a heavy DB query that can crash a busy instance.
