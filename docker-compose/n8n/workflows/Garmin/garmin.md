# Garmin CSV Export Workflow

Fetches the last 7 days of Garmin Connect data daily and appends new records to three persistent CSV files. Deduplication prevents duplicate rows on re-runs.

---

## What It Does

- **Runs:** Daily at 06:00 America/New_York via cron (`0 6 * * *`)
- **Fetches:** Workout activities + nightly sleep summary + nightly HRV status
- **Saves to:** Three append-only CSV files in the mounted volume
- **Self-healing:** Always fetches the last 7 days, so missed days auto-catch-up on the next run
- **0 added = normal** when re-running the same day — dedup skips already-saved records

---

## Output Files

| File | Container Path | Host Path |
|------|---------------|-----------|
| Activities | `/home/node/garmin/activities.csv` | `./workflows/Garmin/activities.csv` |
| Sleep summary | `/home/node/garmin/sleep_epochs.csv` | `./workflows/Garmin/sleep_epochs.csv` |
| HRV status | `/home/node/garmin/hrv.csv` | `./workflows/Garmin/hrv.csv` |

### activities.csv columns

```
activity_id, start_time_local, activity_name, activity_type,
distance_m, duration_s, calories, avg_hr, max_hr, avg_speed_ms,
elevation_gain_m, elevation_loss_m, aerobic_te, anaerobic_te,
vo2max, fetched_at
```

Dedup key: `activity_id`

### sleep_epochs.csv columns

One row per night.

```
date, sleep_score, sleep_start_gmt, sleep_end_gmt,
total_sleep_s, deep_sleep_s, light_sleep_s, rem_sleep_s, awake_s, fetched_at
```

Dedup key: `date`

All duration values are in seconds. `total_sleep_s` = deep + light + rem (excludes awake time).

### hrv.csv columns

One row per night.

```
date, last_night_avg, weekly_avg, last_night_5min_high,
status, baseline_low, baseline_high, fetched_at
```

Dedup key: `date`

- All HRV values are in milliseconds (ms)
- `status`: BALANCED / LOW / UNBALANCED / POOR
- `baseline_low` / `baseline_high`: Garmin's personal HRV baseline range
- Missing nights (watch not worn) are skipped — no empty rows

---

## Architecture

The n8n container is a custom image (`node:20-alpine`) with n8n + Python 3 + `garth` + `garminconnect` installed. At startup, `entrypoint.sh` launches two processes:

1. `garmin_server.py` — a lightweight Python HTTP server on `127.0.0.1:8765` (internal only)
2. `n8n` — the automation platform

The n8n workflow is a 3-node pipeline:

```
Schedule Trigger ──┐
                   ├──► HTTP Request (127.0.0.1:8765/fetch) ──► [result JSON]
Manual Trigger  ───┘
```

The HTTP Request node calls `garmin_server.py`, which runs `garmin_fetch.py` as a subprocess and returns its JSON output. This sidecar pattern is necessary because n8n's Code node sandbox blocks `child_process` and `executeCommand` was removed in n8n 2.8.

**Important:** The URL must be `http://127.0.0.1:8765/fetch` — not `localhost`, which resolves to IPv6 (`::1`) on modern systems and will get `ECONNREFUSED`.

---

## Scripts

| File | Purpose |
|------|---------|
| `setup_garmin_auth.py` | One-time interactive MFA auth — saves OAuth tokens |
| `garmin_fetch.py` | Daily fetch script — runs inside container via garmin_server.py |
| `garmin_server.py` | HTTP sidecar server — bridges n8n to garmin_fetch.py |

All scripts live in `./workflows/Garmin/` (host) = `/home/node/garmin/` (container).

---

## Setup

### 1. Set credentials in `.env`

```
GARMIN_EMAIL=your-email@example.com
GARMIN_PASSWORD=your-password
```

### 2. Build and start the container

```bash
cd /home/ecloaiza/devops/docker/n8n
docker compose build
docker compose up -d
```

### 3. Run the one-time MFA auth setup

This is the only time you'll need MFA. Run it interactively from the host:

```bash
docker exec -it n8n python3 /home/node/garmin/setup_garmin_auth.py
```

You'll be prompted for your email, password, and the MFA code from your authenticator app. OAuth tokens are saved to `./workflows/Garmin/.garth/` and auto-refresh on every subsequent run — **you will never need to enter MFA again** unless you change your Garmin password.

### 4. The workflow is already live in n8n

The workflow (ID: `MWP4OQ8hBMYKj7Xr`) is already imported and active. To test manually: open n8n → **Garmin CSV Export** → click **Test workflow**.

To re-import from scratch: **Workflows → Import from file** → select `garmin_csv_export.json`.

### 5. Verify the output

```bash
head -3 workflows/Garmin/activities.csv
cat workflows/Garmin/sleep_epochs.csv
cat workflows/Garmin/hrv.csv
# Confirm dedup: run again and line counts must not change
docker exec n8n python3 /home/node/garmin/garmin_fetch.py
wc -l workflows/Garmin/*.csv
```

---

## Authentication

Uses `garth` + `garminconnect` Python libraries. The setup script authenticates once with your MFA code and saves long-lived OAuth tokens. `garminconnect` auto-refreshes them on every run via `client.login(tokenstore=...)` — no re-authentication needed.

Token storage: `./workflows/Garmin/.garth/`

**Re-run setup** only if you change your Garmin password or the tokens expire (rare).

---

## Garmin API Endpoints Used (by garminconnect)

| Data | Method |
|------|--------|
| Activities | `client.get_activities_by_date(startdate, enddate)` |
| Sleep | `client.get_sleep_data(date)` — called once per day for 7 days |
| HRV | `client.get_hrv_data(date)` — called once per day for 7 days |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `activities_added: 0, sleep_days_added: 0, hrv_days_added: 0` | Data already fetched today | Normal — dedup skips existing records; new rows appear tomorrow |
| `No saved tokens found` | Setup script not run yet | `docker exec -it n8n python3 /home/node/garmin/setup_garmin_auth.py` |
| `Token load/refresh failed` | Tokens expired or password changed | Re-run setup script |
| `ECONNREFUSED ::1:8765` | URL uses `localhost` (resolves to IPv6) | Change URL to `http://127.0.0.1:8765/fetch` |
| `garminconnect not installed` | Container built without Dockerfile | `docker compose build && docker compose up -d` |
| Garmin server not running | Container restarted, entrypoint failed | Check `docker logs n8n` for "Garmin server started" |
| Activities array is empty | No workouts in the last 7 days | Normal — 0 rows written |
| Sleep CSV not growing | No sleep recorded for those dates | Normal — check the Garmin Connect app to confirm sleep was tracked |
| HRV CSV not growing | Watch not worn or HRV not tracked | Normal — nights without HRV data are skipped |
| `GARMIN_EMAIL` not in container | Env var not forwarded | Confirm `docker-compose.yml` has both vars and container was restarted |