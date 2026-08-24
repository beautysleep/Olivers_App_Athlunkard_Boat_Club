"""Rate every day the tide and weather services have data for.

Reusable entrypoint (`rate_all_days`) plus a small CLI, so the engine can be
proved against the real collections before it is wired to a schedule.

Run:
    python functions/decision/main.py
"""

from __future__ import annotations

import sys
from datetime import datetime, timezone

from engine import rate_day
from firestore_docs import build_rating_document
from inputs import (
    all_tide_extremes,
    cumulative_rain_before,
    daily_weather_for,
    daylight_for,
    high_tides_on,
    hourly_slots_for,
)
from models import Thresholds

COLLECTION = "day_ratings"


def rate_all_days(
    tide_documents: dict[str, dict],
    weather_documents: dict[str, dict],
    water_release_document: dict | None,
    *,
    computed_at: datetime,
    thresholds: Thresholds = Thresholds(),
) -> dict[str, dict]:
    """Driven by the tide days: without a tide there is no window to rate, and
    the tide service reaches further ahead than the weather one does.

    Days already past are skipped. The store keeps them because the fetchers
    never delete, but a rating for a day nobody can row is only clutter.
    """
    extremes = all_tide_extremes(tide_documents)
    classification = _classification(water_release_document)
    today = computed_at.date().isoformat()

    rated: dict[str, dict] = {}
    for date_str in sorted(tide_documents):
        if date_str < today:
            continue
        rating = rate_day(
            high_tides=high_tides_on(tide_documents, date_str),
            extremes=extremes,
            daylight=daylight_for(weather_documents, date_str),
            slots=hourly_slots_for(weather_documents, date_str),
            daily=daily_weather_for(weather_documents, date_str),
            water_release_classification=classification,
            cumulative_rain_mm=cumulative_rain_before(weather_documents, date_str),
            thresholds=thresholds,
        )
        rated[date_str] = build_rating_document(
            date_str, rating, computed_at=computed_at
        )
    return rated


def _classification(water_release_document: dict | None) -> str:
    forecast = (water_release_document or {}).get("parteen_forecast") or {}
    return forecast.get("discharge_classification") or "unparsed"


def _read_collections():
    from google.cloud import firestore

    client = firestore.Client()
    tide = {d.id: d.to_dict() for d in client.collection("tide_predictions").stream()}
    weather = {
        d.id: d.to_dict() for d in client.collection("weather_forecasts").stream()
    }
    water_release = (
        client.collection("water_release_status").document("current").get().to_dict()
    )
    return tide, weather, water_release


def main(argv: list[str]) -> int:
    tide, weather, water_release = _read_collections()
    rated = rate_all_days(
        tide, weather, water_release, computed_at=datetime.now(timezone.utc)
    )
    today = datetime.now(timezone.utc).date().isoformat()
    for date_str in sorted(rated):
        if date_str < today:
            continue
        document = rated[date_str]
        window = (
            f"{document['window_start']:%H:%M}-{document['window_end']:%H:%M}"
            if document["window_start"]
            else "no window"
        )
        print(f"{date_str}  {str(document['rating']):<6} {window:<13}")
        for reason in document["reasons"]:
            print(f"             • {reason}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
