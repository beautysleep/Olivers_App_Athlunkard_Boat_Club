"""Triggered daily over HTTP by Cloud Scheduler. The WorldTides key arrives in
an environment variable injected from Secret Manager.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone

from google.cloud import firestore

from calibration import (
    DEFAULT_HIGH_HEIGHT_OFFSET_M,
    DEFAULT_TIME_OFFSET,
    apply_limerick_calibration,
    parse_extremes,
)
from firestore_docs import build_day_document, group_by_local_day
from main import CLUB_LAT, CLUB_LON, DATUM, STATION_DISTANCE_KM
from worldtides_client import fetch_extremes

COLLECTION = "tide_predictions"


def store_predictions(days: int, client: firestore.Client) -> int:
    """Fetch `days` of tides, calibrate, and upsert one doc per local day.

    Returns the number of day-documents written.
    """
    api_key = os.environ["WORLDTIDES_API_KEY"]
    payload = fetch_extremes(
        CLUB_LAT, CLUB_LON, days, api_key,
        datum=DATUM, station_distance_km=STATION_DISTANCE_KM,
    )
    calibrated = apply_limerick_calibration(parse_extremes(payload))
    groups = group_by_local_day(calibrated)

    fetched_at = datetime.now(timezone.utc)
    offset_minutes = int(DEFAULT_TIME_OFFSET.total_seconds() // 60)

    batch = client.batch()
    for date_str, extremes in groups.items():
        doc = build_day_document(
            date_str,
            extremes,
            station=payload.get("station"),
            datum=payload.get("responseDatum") or DATUM,
            fetched_at=fetched_at,
            time_offset_minutes=offset_minutes,
            high_height_offset_m=DEFAULT_HIGH_HEIGHT_OFFSET_M,
        )
        batch.set(client.collection(COLLECTION).document(date_str), doc)
    batch.commit()
    return len(groups)


def fetch_tides(request):
    """HTTP entry point (Cloud Functions gen2 / functions-framework)."""
    days = int(os.environ.get("TIDE_DAYS", "14"))
    written = store_predictions(days, firestore.Client())
    return (f"Stored {written} day(s) of tide predictions.\n", 200)
