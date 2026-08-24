"""One document per LOCAL (Europe/Dublin) day, keyed by the date string, so the
app can read a calendar day directly. `time_utc` stays a datetime, which the
Firestore client stores as a native Timestamp.
"""

from __future__ import annotations

from datetime import datetime

from models import TideExtreme


def group_by_local_day(
    extremes: list[TideExtreme],
) -> dict[str, list[TideExtreme]]:
    """Bucket extremes by their local (Europe/Dublin) date, chronologically.

    Grouping on local date — not UTC — keeps events on the calendar day a coach
    would expect (a 00:30 local high belongs to that local day, not the UTC one).
    """
    groups: dict[str, list[TideExtreme]] = {}
    for extreme in sorted(extremes, key=lambda e: e.time_utc):
        key = extreme.time_local.date().isoformat()
        groups.setdefault(key, []).append(extreme)
    return groups


def build_day_document(
    date_str: str,
    extremes: list[TideExtreme],
    *,
    station: str | None,
    datum: str | None,
    fetched_at: datetime,
    time_offset_minutes: int,
    high_height_offset_m: float,
) -> dict:
    """Build the Firestore document for one day (see the agreed schema)."""
    return {
        "date": date_str,
        "station": station,
        "datum": datum,
        "source": "worldtides",
        "calibration": {
            "time_offset_minutes": time_offset_minutes,
            "high_height_offset_m": high_height_offset_m,
        },
        "fetched_at": fetched_at,
        "extremes": [
            {
                "kind": e.kind,
                "time_utc": e.time_utc,
                "height_m": round(e.height_m, 3),
            }
            for e in extremes
        ],
    }
