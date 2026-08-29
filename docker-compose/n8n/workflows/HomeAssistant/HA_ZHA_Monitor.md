# HA_ZHA_Monitor — ZHA Zigbee Diagnostic & Alerting

**Workflow file:** `HA_ZHA_Monitor.json`
**Workflow ID:** `ur3QtEjOnDWORazL`

---

## Two Workflows, One ID

The workflow ID `ur3QtEjOnDWORazL` covers two distinct versions of ZHA monitoring. The JSON file is the **diagnostic tool**. A separate **alerting workflow** (multi-node, scheduled, with push notifications) also exists under the same name. They are different in structure and purpose.

| Feature | `HA_ZHA_Monitor.json` (Diagnostic) | Alerting Workflow |
|---------|------------------------------------|--------------------|
| Trigger | Manual only | Manual + Daily 4PM schedule |
| Output | Markdown report string | ntfy + Signal push notifications |
| Nodes | 2 (trigger + code) | 6+ (HTTP nodes, IF, alert nodes) |
| ZHA detection | `attributes.lqi/rssi` on states | `sensor.*_lqi` entity IDs |
| Logbook | Fetched — risky, see warnings | Removed (caused HA DB load) |
| Alert on | Nothing — read only | `offline > 0` OR `low_battery > 0` |
| `active` | `false` — manual trigger only | Must be toggled on for schedule |

---

## HA_ZHA_Monitor.json — On-Demand Diagnostic Report

A single Code node that hits three HA API endpoints in parallel and returns a formatted markdown health report. Run it any time you want a snapshot of your Zigbee network.

### Use Cases

| Situation | Why use this |
|-----------|-------------|
| Devices going offline unexpectedly | Section 2 shows all unavailable ZHA devices with last-changed timestamp |
| Zigbee mesh signal issues | Section 3 lists all devices below LQI 50, sorted weakest-first |
| Debugging an integration error | Section 1 filters the HA error log for ZHA/Zigbee lines |
| Post-maintenance check | Run after adding/moving devices to confirm mesh health |
| Routine network snapshot | Full picture in one click, no scheduled noise |

### Workflow Structure

```
Manual Trigger ──► ZHA Health Report (Code node) ──► { report: "# ZHA Health Report..." }
```

Only 2 nodes. All logic lives in the Code node JS.

### Report Sections

| Section | API Source | What it shows |
|---------|-----------|---------------|
| 1 — ZHA Error Log | `/api/error_log` | Last 30 lines matching `zha` or `zigbee` (case-insensitive) |
| 2 — Unavailable Devices | `/api/states` | ZHA entities whose state is `unavailable`, with last-changed timestamp |
| 3 — Weak Signal | `/api/states` | Entities with `attributes.lqi < 50`, sorted weakest-first (LQI, RSSI, last seen) |
| 4 — Logbook Events | `/api/logbook` | Up to 20 recent events matching `zha`/`zigbee` — **see warning below** |

**Output format:** a single `report` field containing a full markdown string:

```
# ZHA Health Report
Run time: 3/20/2026, 2:15:00 PM
Summary: 2 error log entries | 1 unavailable devices | 3 weak signal devices | 5 logbook events
---

## Section 1: ZHA Error Log Entries
...

## Section 2: Unavailable ZHA Devices
| Entity ID | Friendly Name | Last Changed |
...
```

### How to Run

1. Open the n8n UI
2. Find **ZHA Zigbee Error Monitor**
3. Click **Execute workflow**
4. Click the **ZHA Health Report** node to see the output

### ZHA Device Detection Method

Detects ZHA devices by checking entity attributes from `/api/states` — any entity exposing `lqi` or `rssi` is treated as ZHA, regardless of entity ID naming:

```js
const isZHAEntity = (e) => {
  const attrs = e.attributes || {};
  return attrs.lqi !== undefined || attrs.rssi !== undefined;
};
```

This is different from the alerting workflow, which uses `sensor.*_lqi` entity ID patterns.

### Environment Variables

Set in `/home/ecloaiza/devops/docker/n8n/.env`:

| Variable | Value |
|----------|-------|
| `HA_URL` | `http://192.168.5.18:8123` |
| `HA_TOKEN` | Long-lived access token (HA → Profile → Security) |

Referenced in the Code node as `$env.HA_URL` and `$env.HA_TOKEN`.

### Tuning

| Parameter | Location | Default |
|-----------|----------|---------|
| Weak signal threshold | `LQI_THRESHOLD` at top of Code node | `50` |
| Error log lines shown | `MAX_LOG_LINES` at top of Code node | `30` |
| Logbook events shown | `.slice(0, 20)` in Section 4 | `20` |

### Known Issues & Warnings

| Issue | Detail |
|-------|--------|
| `/api/logbook` is dangerous | Triggers a heavy HA DB query — can cause slowness or crashes on a busy instance. Consider removing Section 4 entirely or adding a request timeout. |
| `/api/error_log` may 404 | Returns 404 on some HA setups (Docker, minimal installs). The Code node does NOT handle this gracefully — add `try/catch` or `continueOnFail` if needed. |
| No alerts | Diagnostic only — no ntfy or Signal notifications fire. Use the alerting workflow for proactive monitoring. |
| `active: false` | Inactive by default — schedule trigger (if added) won't fire until toggled on in n8n UI. |

---

## Alerting Workflow (Multi-Node)

A separate, more complete monitoring workflow that sends push notifications when issues are detected. Distinct from the diagnostic JSON above.

### Triggers

| Trigger | When |
|---------|------|
| Manual | Click "Execute workflow" in the n8n UI |
| Schedule | Daily at 4:00 PM ET — alerts only if issues detected |

> Must be **activated** (toggle in top-right of n8n UI) for the schedule to fire.

### Node Structure

```
Manual Trigger ──┐
                 ├──► Get HA Error Log → Get HA States → Format ZHA Report → Any issues? ──► Send ntfy Alert
Daily 4PM ───────┘                                                              (IF true)  └► Send Signal Alert
```

| Node | Type | Notes |
|------|------|-------|
| Get HA Error Log | HTTP Request | `GET /api/error_log` — plain text, `continueOnFail: true` |
| Get HA States | HTTP Request | `GET /api/states` — all 2600+ entities, ZHA filtered in code |
| Format ZHA Report | Code | Structured JSON output with alert fields |
| Any issues? | IF | Fires if `summary.offline > 0` OR `summary.low_battery > 0` |
| Send ntfy Alert | HTTP Request | `POST https://ntfy.home.elikesbikes.com/ha_alerts` |
| Send Signal Alert | HTTP Request | `GET https://signal.callmebot.com/signal/send.php` |

### Structured Output Fields

| Field | What it shows |
|-------|---------------|
| `status` | `All good` or `Issues detected` |
| `run_time` | Timestamp of report |
| `alert_title` | Pre-built title for ntfy/Signal |
| `alert_body` | Pre-built body for ntfy/Signal |
| `summary` | Counts: total / offline / weak signal / low battery / healthy |
| `offline_devices` | Devices whose `_lqi` sensor is `unavailable` |
| `weak_signal_devices` | LQI < 50, sorted weakest first |
| `low_battery_devices` | Battery < 10%, sorted lowest first |
| `healthy_devices` | All other online devices, sorted by LQI |

### Notification Channels

**ntfy**
- URL: `https://ntfy.home.elikesbikes.com/ha_alerts`
- Priority: `high` — Tags: `warning, rotating_light`
- HTTP headers must be ASCII-only — no emoji in the `Title` header

**Signal (via CallMeBot)**
- URL: `https://signal.callmebot.com/signal/send.php`
- Phone ID: `a060b503-a21e-43f4-834a-ac4519a830f2`
- API key stored directly in the node

**Example alert:**
```
Title: 2 offline, 1 low battery - ZHA Alert

OFFLINE:
- ThirdReality-Office-motion
- Aeotec-office-button

LOW BATTERY:
- ThirdReality-Garage-sensor (4%)
```

### ZHA Device Detection Method

Uses `sensor.*_lqi` entity ID patterns (not attribute inspection):
- Finds all entities matching `sensor.*_lqi` or `sensor.*_lqi_N`
- Cross-references RSSI sensors only for devices already found via LQI
- Battery: `device_class: battery` OR `unit_of_measurement: %` + `battery` in entity ID

### Tuning

- **Weak signal threshold:** `LQI_THRESHOLD` (default: `50`) in Format ZHA Report node. LQI ranges 0–255.
- **Low battery threshold:** `BATT_THRESHOLD` (default: `10`) in Format ZHA Report node.
- **Log lines:** `.slice(-20)` in the error log section.

### Known Limitations

- `/api/error_log` returns 404 on some setups — handled gracefully via `continueOnFail: true`.
- `/api/logbook` was removed — caused HA to run a heavy DB query that crashed a busy instance.
