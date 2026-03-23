# Garmin CSV Export Workflow

Fetches the last 7 days of Garmin Connect data daily and appends new records to four persistent CSV files. Deduplication prevents duplicate rows on re-runs.

---

## Quick Start

```bash
# 1. Set credentials
echo "GARMIN_EMAIL=you@example.com\nGARMIN_PASSWORD=yourpassword" >> docker/n8n/.env

# 2. Build and start
cd /home/ecloaiza/devops/docker/n8n
docker compose build && docker compose up -d

# 3. One-time MFA auth
docker exec -it n8n python3 /home/node/garmin/setup_garmin_auth.py

# 4. Verify
docker exec n8n python3 /home/node/garmin/garmin_fetch.py
```

The workflow runs automatically at 06:00 America/New_York every day. No further setup needed.

---

## Prerequisites

- Docker + Docker Compose
- A Garmin Connect account with MFA enabled
- The parent `docker/n8n/docker-compose.yml` and `entrypoint.sh` (lives in the `n8n/` directory, not here)

---

## Directory Structure

```
docker/n8n/
├── docker-compose.yml          # Custom build, mounts Garmin volume
├── entrypoint.sh               # Starts garmin_server.py + n8n at boot
├── .env                        # GARMIN_EMAIL / GARMIN_PASSWORD (chmod 600)
├── n8n_data/                   # n8n database, logs, config (persisted volume)
├── shared/                     # General-purpose shared volume
└── workflows/
    └── Garmin/                 # All Garmin files live here
        ├── README.md               # This file
        ├── Dockerfile              # Custom image: node:20-alpine + Python + n8n
        ├── setup_garmin_auth.py    # One-time MFA auth setup
        ├── garmin_server.py        # HTTP sidecar server (port 8765)
        ├── garmin_fetch.py         # Daily fetch + CSV append logic
        ├── garmin_backfill.py      # One-off historical backfill script
        ├── garmin_csv_export.json  # n8n workflow backup (import if needed)
        ├── activities.csv          # Output: workout activities
        ├── sleep_epochs.csv        # Output: nightly sleep summary
        ├── hrv.csv                 # Output: nightly HRV status
        └── rhr.csv                 # Output: daily resting heart rate
```

> Note: `.garth/` (OAuth token store) is inside `Garmin/` but git-ignored — it holds sensitive auth tokens.

---

## What It Does

- **Runs:** Daily at 06:00 America/New_York via cron (`0 6 * * *`)
- **Fetches:** Workout activities + nightly sleep summary + nightly HRV status + resting heart rate
- **Saves to:** Four append-only CSV files in the mounted volume
- **Self-healing:** Always fetches today + 6 prior days, so missed days auto-catch-up on the next run
- **Today included:** `end_date = today` so last night's sleep/HRV (keyed to wake-up date) is always captured
- **0 added = normal** when re-running the same day — dedup skips already-saved records

---

## Output Files

| File | Container Path | Host Path |
|------|---------------|-----------|
| Activities | `/home/node/garmin/activities.csv` | `./workflows/Garmin/activities.csv` |
| Sleep summary | `/home/node/garmin/sleep_epochs.csv` | `./workflows/Garmin/sleep_epochs.csv` |
| HRV status | `/home/node/garmin/hrv.csv` | `./workflows/Garmin/hrv.csv` |
| Resting HR | `/home/node/garmin/rhr.csv` | `./workflows/Garmin/rhr.csv` |

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

### rhr.csv columns

One row per day.

```
date, resting_hr, fetched_at
```

Dedup key: `date`

- `resting_hr`: resting heart rate in bpm (int)
- Days with no data (e.g. watch not worn) are skipped — no empty rows

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
| `garmin_backfill.py` | One-off historical backfill — fetches a configurable date range in 7-day chunks |

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

## Backfill

Use `garmin_backfill.py` to load historical data that predates the daily workflow. It fetches from a configured start date to today in 7-day chunks, merging into the same CSV files with the same dedup logic.

### Configure the date range

Edit `garmin_backfill.py` and set `START_DATE`:

```python
START_DATE = date(2026, 1, 1)   # change to your desired start date
```

### Run the backfill

```bash
docker exec -it n8n python3 /home/node/garmin/garmin_backfill.py
```

Progress is printed per chunk. The script sleeps 2 seconds between chunks to avoid Garmin API rate limits. Re-running is safe — dedup skips rows already in the CSVs.

> Note: `garmin_backfill.py` does not fetch RHR. Add that manually if needed.

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
| RHR | `client.get_rhr_day(date)` — called once per day for 7 days |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `activities_added: 0, sleep_days_added: 0, hrv_days_added: 0` | Data already fetched today | Normal — dedup skips existing records |
| Sleep/HRV missing for today | Garmin keys nightly data to wake-up date | Run after you've woken up; script includes today in range |
| `No saved tokens found` | Setup script not run yet | `docker exec -it n8n python3 /home/node/garmin/setup_garmin_auth.py` |
| `Token load/refresh failed` | Tokens expired or password changed | Re-run setup script |
| `ECONNREFUSED ::1:8765` | URL uses `localhost` (resolves to IPv6) | Change URL to `http://127.0.0.1:8765/fetch` |
| `garminconnect not installed` | Container built without Dockerfile | `docker compose build && docker compose up -d` |
| Garmin server not running | Container restarted, entrypoint failed | Check `docker logs n8n` for "Garmin server started" |
| Activities array is empty | No workouts in the last 7 days | Normal — 0 rows written |
| Sleep CSV not growing | No sleep recorded for those dates | Normal — check the Garmin Connect app to confirm sleep was tracked |
| HRV CSV not growing | Watch not worn or HRV not tracked | Normal — nights without HRV data are skipped |
| RHR CSV not growing | Watch not worn or RHR not tracked | Normal — days without RHR data are skipped |
| `GARMIN_EMAIL` not in container | Env var not forwarded | Confirm `docker-compose.yml` has both vars and container was restarted |
