#!/usr/bin/env python3
"""
One-off backfill script: fetches all Garmin data from START_DATE to today
and merges it into the existing CSV files (dedup prevents duplicates).

Usage (inside container):
    python3 /home/node/garmin/garmin_backfill.py

Iterates in 7-day chunks to avoid Garmin API rate limits.
Shares the same CSV files and dedup logic as garmin_fetch.py.
"""

import csv
import json
import sys
import time
from datetime import date, datetime, timedelta
from pathlib import Path

try:
    from garminconnect import Garmin
except ImportError:
    print("ERROR: garminconnect not installed. Rebuild the container.")
    sys.exit(1)

# ── config ────────────────────────────────────────────────────────────────────

START_DATE = date(2026, 1, 1)
END_DATE   = date.today()
CHUNK_DAYS = 7          # days per activities API call
SLEEP_BETWEEN_CHUNKS = 2  # seconds between chunks (rate-limit courtesy)

BASE_DIR      = Path("/home/node/garmin")
TOKEN_DIR     = BASE_DIR / ".garth"
ACTIVITIES_CSV = BASE_DIR / "activities.csv"
SLEEP_CSV      = BASE_DIR / "sleep_epochs.csv"
HRV_CSV        = BASE_DIR / "hrv.csv"

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


# ── helpers ───────────────────────────────────────────────────────────────────

def load_seen_ids(csv_path: Path, key_col: int = 0) -> set:
    seen = set()
    if not csv_path.exists():
        return seen
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if len(row) > key_col and row[key_col].strip():
                seen.add(row[key_col].strip())
    return seen


def append_rows(csv_path: Path, header: list, rows: list) -> int:
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
    if ts is None:
        return ""
    try:
        return datetime.utcfromtimestamp(int(ts) / 1000).isoformat() + "Z"
    except Exception:
        return str(ts)


def fmt(d: date) -> str:
    return d.strftime("%Y-%m-%d")


# ── auth ──────────────────────────────────────────────────────────────────────

if not TOKEN_DIR.exists():
    print(f"ERROR: No saved tokens at {TOKEN_DIR}. Run setup_garmin_auth.py first.")
    sys.exit(1)

try:
    client = Garmin()
    client.login(tokenstore=str(TOKEN_DIR))
    print("Authenticated with Garmin Connect.")
except Exception as e:
    print(f"ERROR: Token load/refresh failed: {e}")
    sys.exit(1)

# ── backfill loop ─────────────────────────────────────────────────────────────

fetched_at = datetime.utcnow().isoformat() + "Z"
total = {"activities": 0, "sleep": 0, "hrv": 0, "errors": []}

# Pre-load all seen keys once (updated in memory as we go)
seen_activity_ids = load_seen_ids(ACTIVITIES_CSV, key_col=0)
seen_sleep_dates  = load_seen_ids(SLEEP_CSV, key_col=0)
seen_hrv_dates    = load_seen_ids(HRV_CSV, key_col=0)

chunk_start = START_DATE
chunk_num   = 0

while chunk_start <= END_DATE:
    chunk_end = min(chunk_start + timedelta(days=CHUNK_DAYS - 1), END_DATE)
    chunk_num += 1
    print(f"\n[Chunk {chunk_num}] {fmt(chunk_start)} → {fmt(chunk_end)}", flush=True)

    # ── activities ────────────────────────────────────────────────────────────
    try:
        activities = client.get_activities_by_date(
            startdate=fmt(chunk_start),
            enddate=fmt(chunk_end),
        )
    except Exception as e:
        msg = f"Activities fetch failed {fmt(chunk_start)}-{fmt(chunk_end)}: {e}"
        total["errors"].append(msg)
        print(f"  WARN: {msg}")
        activities = []

    new_activity_rows = []
    for a in activities:
        aid = str(a.get("activityId", ""))
        if not aid or aid in seen_activity_ids:
            continue
        seen_activity_ids.add(aid)
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
    added = append_rows(ACTIVITIES_CSV, ACTIVITIES_HEADER, new_activity_rows)
    total["activities"] += added
    print(f"  Activities: +{added}", flush=True)

    # ── sleep + HRV (day by day within the chunk) ─────────────────────────────
    sleep_added = 0
    hrv_added   = 0

    current_day = chunk_start
    while current_day <= chunk_end:
        date_str = fmt(current_day)

        # sleep
        if date_str not in seen_sleep_dates:
            try:
                data = client.get_sleep_data(date_str)
                dto = (data or {}).get("dailySleepDTO") or {}
                if dto:
                    deep_s  = dto.get("deepSleepSeconds")  or 0
                    light_s = dto.get("lightSleepSeconds") or 0
                    rem_s   = dto.get("remSleepSeconds")   or 0
                    awake_s = dto.get("awakeSleepSeconds") or 0
                    total_s = deep_s + light_s + rem_s
                    row = [
                        date_str,
                        ((dto.get("sleepScores") or {}).get("overall") or {}).get("value", ""),
                        ts_to_iso(dto.get("sleepStartTimestampGMT")),
                        ts_to_iso(dto.get("sleepEndTimestampGMT")),
                        total_s, deep_s, light_s, rem_s, awake_s,
                        fetched_at,
                    ]
                    append_rows(SLEEP_CSV, SLEEP_HEADER, [row])
                    seen_sleep_dates.add(date_str)
                    sleep_added += 1
            except Exception as e:
                msg = f"Sleep fetch failed {date_str}: {e}"
                total["errors"].append(msg)
                print(f"  WARN: {msg}")

        # HRV
        if date_str not in seen_hrv_dates:
            try:
                data = client.get_hrv_data(date_str)
                summary = (data or {}).get("hrvSummary") or {}
                if summary:
                    baseline = summary.get("baseline") or {}
                    row = [
                        date_str,
                        summary.get("lastNightAvg", ""),
                        summary.get("weeklyAvg", ""),
                        summary.get("lastNight5MinHigh", ""),
                        summary.get("status", ""),
                        baseline.get("balancedLow", ""),
                        baseline.get("balancedUpper", ""),
                        fetched_at,
                    ]
                    append_rows(HRV_CSV, HRV_HEADER, [row])
                    seen_hrv_dates.add(date_str)
                    hrv_added += 1
            except Exception as e:
                msg = f"HRV fetch failed {date_str}: {e}"
                total["errors"].append(msg)
                print(f"  WARN: {msg}")

        current_day += timedelta(days=1)

    total["sleep"] += sleep_added
    total["hrv"]   += hrv_added
    print(f"  Sleep: +{sleep_added}  HRV: +{hrv_added}", flush=True)

    chunk_start = chunk_end + timedelta(days=1)
    if chunk_start <= END_DATE:
        time.sleep(SLEEP_BETWEEN_CHUNKS)

# ── summary ───────────────────────────────────────────────────────────────────

print(f"\n{'='*50}")
print(f"Backfill complete: {fmt(START_DATE)} → {fmt(END_DATE)}")
print(f"  Activities added : {total['activities']}")
print(f"  Sleep days added : {total['sleep']}")
print(f"  HRV days added   : {total['hrv']}")
if total["errors"]:
    print(f"  Errors ({len(total['errors'])}):")
    for e in total["errors"]:
        print(f"    - {e}")
else:
    print("  Errors           : none")
print(f"{'='*50}")
sys.exit(1 if total["errors"] else 0)
