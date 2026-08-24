"""One document per local day in `day_ratings`, keyed by the date string so the
app can read a calendar day directly — the same shape as the tide and weather
services. Overwritten on every run: a rating is only ever the current answer.
"""

from __future__ import annotations

from datetime import datetime

from models import DayRating, WindowRating


def _window_entry(window: WindowRating) -> dict:
    start, end = window.window if window.window else (None, None)
    return {
        "high_tide_at": window.high_tide_at,
        "rating": window.rating,
        "window_start": start,
        "window_end": end,
        "reasons": list(window.reasons),
    }


def build_rating_document(
    date_str: str, rating: DayRating, *, computed_at: datetime
) -> dict:
    """`windows` carries one entry per rowable high tide, because a day's two
    tides are separately committable and a single verdict would flatten out the
    one the coach wants. `reasons` at the top level are only the overrides that
    settle every window at once.

    Window bounds are written as null rather than omitted, so a tide the engine
    could not give a stretch for is distinguishable from one it never looked at.
    """
    return {
        "date": date_str,
        "rating": rating.rating,
        "reasons": list(rating.reasons),
        "windows": [_window_entry(window) for window in rating.windows],
        "computed_at": computed_at,
    }
