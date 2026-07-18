"""Shape forecast points into per-day Firestore documents.

Pure (no Firestore/network dependency) so it stays unit-testable; the actual
write lives in function.py.

One document per LOCAL (Europe/Dublin) day, keyed by the date string — so the app
can read a calendar day directly. `daily` is that day's aggregate; `hourly` is
the intraday series for days that fall within the API's hourly horizon (~48h),
and is empty for days beyond it. Mirrors the tide service.
"""

from __future__ import annotations

from datetime import datetime

from models import WeatherPoint


def group_hourly_by_local_day(
    points: list[WeatherPoint],
) -> dict[str, list[WeatherPoint]]:
    """Bucket hourly points by their local (Europe/Dublin) date, chronologically.

    Grouping on local date — not UTC — keeps each hour on the calendar day a
    coach would expect (a 00:30 local reading belongs to that local day).
    """
    groups: dict[str, list[WeatherPoint]] = {}
    for point in sorted(points, key=lambda p: p.time_utc):
        key = point.time_local.date().isoformat()
        groups.setdefault(key, []).append(point)
    return groups


def build_day_document(
    date_str: str,
    daily: WeatherPoint | None,
    hourly: list[WeatherPoint],
    *,
    fetched_at: datetime,
    source: str = "openweather",
) -> dict:
    """Build the Firestore document for one local day."""
    return {
        "date": date_str,
        "source": source,
        "fetched_at": fetched_at,
        "daily": None if daily is None else daily.metrics(),
        "hourly": [point.to_dict() for point in hourly],
    }


def build_documents(
    daily_points: list[WeatherPoint],
    hourly_points: list[WeatherPoint],
    *,
    fetched_at: datetime,
    source: str = "openweather",
) -> dict[str, dict]:
    """Assemble one document per local day from the daily + hourly forecasts.

    Driven by the daily points (the full multi-day horizon); each day gets its
    hourly series attached where available, otherwise an empty list.
    """
    hourly_by_day = group_hourly_by_local_day(hourly_points)
    documents: dict[str, dict] = {}
    for daily in sorted(daily_points, key=lambda p: p.time_utc):
        date_str = daily.time_local.date().isoformat()
        documents[date_str] = build_day_document(
            date_str,
            daily,
            hourly_by_day.get(date_str, []),
            fetched_at=fetched_at,
            source=source,
        )
    return documents
