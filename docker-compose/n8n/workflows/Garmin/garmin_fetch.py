#!/usr/bin/env python3
"""
Garmin Connect — Daily fetch script.

Called by n8n's Execute Command node on a schedule. Loads saved OAuth tokens
(from setup_garmin_auth.py), fetches the last 7 days of activities and
detailed sleep epoch data, and appends new records to CSV files.

Deduplication: never writes a record that already exists in the CSV.
Self-healing: always fetches the last 7 days, so missed days catch up on the
next run.

Output files:
    /home/node/garmin/activities.csv
    /home/node/garmin/sleep_epochs.csv
"""

import csv
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path

try:
    from garminconnect import Garmin
except ImportError:
    print(json.dumps({"status": "error", "message": "garminconnect not installed. Rebuild the container."}))
    sys.exit(1)

BASE_DIR = Path("/home/node/garmin")
TOKEN_DIR = BASE_DIR / ".garth"
ACTIVITIES_CSV = BASE_DIR / "activities.csv"
SLEEP_CSV = BASE_DIR / "sleep_epochs.csv"
HRV_CSV = BASE_DIR / "hrv.csv"
RHR_CSV = BASE_DIR / "rhr.csv"

ACTIVITIES_HEADER = [
    "activity_id", "start_time_local", "activity_name", "activity_type",
    "distance_m", "duration_s", "calories", "avg_hr", "max_hr", "avg_speed_ms",
    "elevation_gain_m", "elevation_loss_m", "aerobic_te", "anaerobic_te",
    "vo2max", "fetched_at",
]

SLEEP_HEADER = [
    "date", "sleep_score", "sleep_start_gmt", "sleep_end_gmt",
    "total_sleep_s", "deep_sleep_s", "light_sleep_s", "rem_sleep_s", "awake_s",
    "fetched_at",
]

HRV_HEADER = [
    "date", "last_night_avg", "weekly_avg", "last_night_5min_high",
    "status", "baseline_low", "baseline_high", "fetched_at",
]

RHR_HEADER = ["date", "resting_hr", "fetched_at"]


# ── helpers ──────────────────────────────────────────────────────────────────

def load_seen_ids(csv_path: Path, key_col: int = 0) -> set:
    """Return a set of values from a single column of an existing CSV."""
    seen = set()
    if not csv_path.exists():
        return seen
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader, None)  # skip header
        for row in reader:
            if len(row) > key_col and row[key_col].strip():
                seen.add(row[key_col].strip())
    return seen


def load_seen_composite_keys(csv_path: Path) -> set:
    """Return a set of 'date|start_gmt' composite keys from the sleep CSV."""
    seen = set()
    if not csv_path.exists():
        return seen
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader, None)  # skip header
        for row in reader:
            if len(row) >= 2 and row[0].strip() and row[1].strip():
                seen.add(f"{row[0].strip()}|{row[1].strip()}")
    return seen


def append_rows(csv_path: Path, header: list, rows: list) -> int:
    """Append rows to a CSV, writing header if the file is new."""
    if not rows:
        return 0
    write_header = not csv_path.exists() or csv_path.stat().st_size == 0
    with csv_path.open("a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if write_header:
            writer.writerow(header)
        writer.writerows(rows)
    return len(rows)


def ts_to_iso(ts) -> str:
    """Convert a millisecond timestamp to ISO 8601 string, or return ''."""
    if ts is None:
        return ""
    try:
        return datetime.utcfromtimestamp(int(ts) / 1000).isoformat() + "Z"
    except Exception:
        return str(ts)


def fmt_date(d: datetime) -> str:
    return d.strftime("%Y-%m-%d")


# ── auth ─────────────────────────────────────────────────────────────────────

if not TOKEN_DIR.exists():
    print(json.dumps({
        "status": "error",
        "message": "No saved tokens found. Run setup_garmin_auth.py first: "
                   "docker exec -it n8n python3 /home/node/garmin/setup_garmin_auth.py"
    }))
    sys.exit(1)

try:
    client = Garmin()
    client.login(tokenstore=str(TOKEN_DIR))
except Exception as e:
    print(json.dumps({"status": "error", "message": f"Token load/refresh failed: {e}"}))
    sys.exit(1)

# ── date range: today back 7 days ────────────────────────────────────────────

today = datetime.utcnow().date()
end_date = today
start_date = end_date - timedelta(days=6)
fetched_at = datetime.utcnow().isoformat() + "Z"

stats = {"activities_added": 0, "sleep_days_added": 0, "hrv_days_added": 0, "rhr_days_added": 0, "errors": []}

# ── activities ────────────────────────────────────────────────────────────────

try:
    activities = client.get_activities_by_date(
        startdate=fmt_date(start_date),
        enddate=fmt_date(end_date),
    )
except Exception as e:
    stats["errors"].append(f"Activities fetch failed: {e}")
    activities = []

seen_activity_ids = load_seen_ids(ACTIVITIES_CSV, key_col=0)
new_activity_rows = []

for a in activities:
    aid = str(a.get("activityId", ""))
    if not aid or aid in seen_activity_ids:
        continue
    new_activity_rows.append([
        aid,
        a.get("startTimeLocal", ""),
        a.get("activityName", ""),
        (a.get("activityType") or {}).get("typeKey", ""),
        a.get("distance", ""),
        a.get("duration", ""),
        a.get("calories", ""),
        a.get("averageHR", ""),
        a.get("maxHR", ""),
        a.get("averageSpeed", ""),
        a.get("elevationGain", ""),
        a.get("elevationLoss", ""),
        a.get("aerobicTrainingEffect", ""),
        a.get("anaerobicTrainingEffect", ""),
        a.get("vo2MaxValue", ""),
        fetched_at,
    ])

stats["activities_added"] = append_rows(ACTIVITIES_CSV, ACTIVITIES_HEADER, new_activity_rows)

# ── sleep summary (one row per night) ────────────────────────────────────────

seen_sleep_dates = load_seen_ids(SLEEP_CSV, key_col=0)
new_sleep_rows = []

for i in range(7):
    day = end_date - timedelta(days=i)
    date_str = fmt_date(day)

    if date_str in seen_sleep_dates:
        continue

    try:
        data = client.get_sleep_data(date_str)
    except Exception as e:
        stats["errors"].append(f"Sleep fetch failed for {date_str}: {e}")
        continue

    dto = (data or {}).get("dailySleepDTO") or {}

    if not dto:
        continue

    deep_s  = dto.get("deepSleepSeconds")  or 0
    light_s = dto.get("lightSleepSeconds") or 0
    rem_s   = dto.get("remSleepSeconds")   or 0
    awake_s = dto.get("awakeSleepSeconds") or 0
    total_s = deep_s + light_s + rem_s

    new_sleep_rows.append([
        date_str,
        ((dto.get("sleepScores") or {}).get("overall") or {}).get("value", ""),
        ts_to_iso(dto.get("sleepStartTimestampGMT")),
        ts_to_iso(dto.get("sleepEndTimestampGMT")),
        total_s,
        deep_s,
        light_s,
        rem_s,
        awake_s,
        fetched_at,
    ])

stats["sleep_days_added"] = append_rows(SLEEP_CSV, SLEEP_HEADER, new_sleep_rows)

# ── HRV status (one row per night) ───────────────────────────────────────────

seen_hrv_dates = load_seen_ids(HRV_CSV, key_col=0)
new_hrv_rows = []

for i in range(7):
    day = end_date - timedelta(days=i)
    date_str = fmt_date(day)

    if date_str in seen_hrv_dates:
        continue

    try:
        data = client.get_hrv_data(date_str)
    except Exception as e:
        stats["errors"].append(f"HRV fetch failed for {date_str}: {e}")
        continue

    summary = (data or {}).get("hrvSummary") or {}
    if not summary:
        continue

    baseline = summary.get("baseline") or {}
    new_hrv_rows.append([
        date_str,
        summary.get("lastNightAvg", ""),
        summary.get("weeklyAvg", ""),
        summary.get("lastNight5MinHigh", ""),
        summary.get("status", ""),
        baseline.get("balancedLow", ""),
        baseline.get("balancedUpper", ""),
        fetched_at,
    ])

stats["hrv_days_added"] = append_rows(HRV_CSV, HRV_HEADER, new_hrv_rows)

# ── RHR (resting heart rate, one row per day) ────────────────────────────────

seen_rhr_dates = load_seen_ids(RHR_CSV, key_col=0)
new_rhr_rows = []

for i in range(7):
    day = end_date - timedelta(days=i)
    date_str = fmt_date(day)

    if date_str in seen_rhr_dates:
        continue

    try:
        data = client.get_rhr_day(date_str)
    except Exception as e:
        stats["errors"].append(f"RHR fetch failed for {date_str}: {e}")
        continue

    entries = ((data or {}).get("allMetrics") or {}).get("metricsMap") or {}
    rhr_list = entries.get("WELLNESS_RESTING_HEART_RATE") or []
    rhr_value = rhr_list[0].get("value") if rhr_list else None
    if rhr_value is None:
        continue

    new_rhr_rows.append([date_str, rhr_value, fetched_at])

stats["rhr_days_added"] = append_rows(RHR_CSV, RHR_HEADER, new_rhr_rows)

# ── output ────────────────────────────────────────────────────────────────────

stats["status"] = "error" if stats["errors"] else "ok"
stats["date_range"] = f"{fmt_date(start_date)} to {fmt_date(end_date)}"
print(json.dumps(stats))

if stats["errors"]:
    sys.exit(1)
