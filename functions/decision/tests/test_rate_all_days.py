from datetime import datetime, timedelta, timezone

from main import rate_all_days
from models import GREEN, RED


def utc(day, hour, minute=0):
    return datetime(2026, 8, day, hour, minute, tzinfo=timezone.utc)


def a_day(day, high_metres=5.0, wind_ms=3.0):
    """One day with a rowable high tide at noon between 1.0 m lows."""
    return (
        {
            "extremes": [
                {"kind": "Low", "time_utc": utc(day, 6), "height_m": 1.0},
                {"kind": "High", "time_utc": utc(day, 12), "height_m": high_metres},
                {"kind": "Low", "time_utc": utc(day, 18), "height_m": 1.0},
            ]
        },
        {
            "sunrise": utc(day, 5),
            "sunset": utc(day, 21),
            "daily": {"wind_speed_ms": wind_ms, "rain_mm": 0.0},
            "hourly": [],
        },
    )


def build(days):
    tide, weather = {}, {}
    for day, kwargs in days.items():
        tide[f"2026-08-{day}"], weather[f"2026-08-{day}"] = a_day(int(day), **kwargs)
    return tide, weather


CLEAR = {"parteen_forecast": {"discharge_classification": "no_discharge_expected"}}


def test_every_day_with_a_tide_gets_a_document():
    tide, weather = build({"25": {}, "26": {}, "27": {}})

    rated = rate_all_days(tide, weather, CLEAR, computed_at=utc(25, 6))

    assert sorted(rated) == ["2026-08-25", "2026-08-26", "2026-08-27"]
    assert all(document["rating"] == GREEN for document in rated.values())


def test_a_discharge_turns_every_day_red_at_once():
    tide, weather = build({"25": {}, "26": {}})
    discharging = {
        "parteen_forecast": {"discharge_classification": "discharge_expected"}
    }

    rated = rate_all_days(tide, weather, discharging, computed_at=utc(25, 6))

    assert all(document["rating"] == RED for document in rated.values())


def test_a_day_whose_tide_never_reaches_a_rowable_depth_is_red():
    tide, weather = build({"25": {"high_metres": 3.9}})

    rated = rate_all_days(tide, weather, CLEAR, computed_at=utc(25, 6))

    assert rated["2026-08-25"]["rating"] == RED


def test_the_window_lands_inside_the_day_it_belongs_to():
    tide, weather = build({"26": {}})

    document = rate_all_days(tide, weather, CLEAR, computed_at=utc(26, 6))["2026-08-26"]

    assert (
        utc(26, 5) <= document["window_start"] < document["window_end"] <= utc(26, 21)
    )
    assert document["window_end"] - document["window_start"] >= timedelta(
        hours=1, minutes=30
    )


def test_days_already_past_are_not_rated():
    tide, weather = build({"24": {}, "25": {}, "26": {}})

    rated = rate_all_days(tide, weather, CLEAR, computed_at=utc(25, 6))

    assert sorted(rated) == ["2026-08-25", "2026-08-26"]
