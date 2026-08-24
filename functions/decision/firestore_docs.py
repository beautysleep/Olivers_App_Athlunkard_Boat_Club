"""One document per local day in `day_ratings`, keyed by the date string so the
app can read a calendar day directly — the same shape as the tide and weather
services. Overwritten on every run: a rating is only ever the current answer,
and yesterday's is of no use to anyone.
"""

from __future__ import annotations

from datetime import datetime

from models import DayRating


def build_rating_document(
    date_str: str, rating: DayRating, *, computed_at: datetime
) -> dict:
    """`window_start`/`window_end` are written as null rather than omitted, so a
    day the engine could not give a window for is distinguishable from a day it
    has not looked at."""
    start, end = rating.window if rating.window else (None, None)
    return {
        "date": date_str,
        "rating": rating.rating,
        "window_start": start,
        "window_end": end,
        "reasons": list(rating.reasons),
        "computed_at": computed_at,
    }
