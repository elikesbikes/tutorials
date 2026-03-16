# Garmin CSV Export Workflow

Fetches the last 7 days of Garmin Connect data daily and appends new records to persistent CSV files. Deduplication prevents duplicate rows on re-runs.

---

## What It Does

- **Runs:** Daily at 06:00 America/New_York via cron (`0 6 * * *`)
- **Fetches:** Workout activities + nightly sleep summary (score, duration, stage totals)
- **Saves to:** Two append-only CSV files in the shared volume
- **Self-healing:** Always fetches the last 7 days, so missed days auto-catch-up on the next run

---

## Output Files

| File | Container Path | Host Path |
|------|---------------|-----------|
| Activities | `/home/node/garmin/activities.csv` | `./workflows/Garmin/activities.csv` |
| Sleep summary | `/home/node/garmin/sleep_epochs.csv` | `./workflows/Garmin/sleep_epochs.csv` |

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

---

## Architecture

The n8n container is built from a custom `Dockerfile` (based on `node:20-alpine`) that installs n8n + Python 3 + `garth` + `garminconnect`. The n8n workflow is a simple 3-node pipeline:

```
Schedule Trigger → Run Garmin Fetch (Execute Command) → Parse Result (Code)
```

All the real work happens in `garmin_fetch.py`, which is called by the Execute Command node.

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

### 4. Import and activate the workflow

In n8n (http://localhost:5678): **Workflows → Import from file** → select `garmin_csv_export.json`

Test it first with a Manual Trigger, then activate the Schedule Trigger.

### 5. Verify the output

```bash
head -3 workflows/Garmin/activities.csv
cat workflows/Garmin/sleep_epochs.csv
# Run the fetch again to confirm dedup (line counts must not change)
docker exec n8n python3 /home/node/garmin/garmin_fetch.py
```

---

## Scripts

| File | Purpose |
|------|---------|
| `setup_garmin_auth.py` | One-time interactive MFA auth — saves OAuth tokens |
| `garmin_fetch.py` | Daily fetch script — called by n8n on schedule |

Both scripts live in `./workflows/Garmin/` (host) = `/home/node/garmin/` (container).

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

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `No saved tokens found` | setup script not run yet | Run `docker exec -it n8n python3 /home/node/garmin/setup_garmin_auth.py` |
| `Token load/refresh failed` | Tokens expired or password changed | Re-run setup script |
| `garminconnect not installed` | Container built without Dockerfile | Run `docker compose build && docker compose up -d` |
| Activities array is empty | No workouts in the last 7 days | Normal — 0 rows written |
| Sleep CSV not growing | No sleep recorded for those dates | Normal — check the Garmin Connect app to confirm sleep was tracked |
| `GARMIN_EMAIL` not in container | Env var not forwarded | Confirm `docker-compose.yml` has both vars and container was restarted |
