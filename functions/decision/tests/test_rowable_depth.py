"""The rule the club actually rows by: the water must stand at 3.7 m or more for
at least 1h of daylight. A high-tide height on its own says nothing — 4.2 m
was only ever a stand-in for "high enough to hold 3.7 m long enough".

Heights are illustrative (0.5 m lows, 6h12m between each low and high), not
captured from tide_predictions.
"""

from datetime import datetime, timedelta, timezone

import pytest

from engine import rate_day, rowable_windows_in_daylight
from models import RED, WeatherSlot
from tide_curve import TideExtreme

LOW = datetime(2026, 10, 1, 3, 48, tzinfo=timezone.utc)
HIGH = datetime(2026, 10, 1, 10, 0, tzinfo=timezone.utc)
NEXT_LOW = datetime(2026, 10, 1, 16, 12, tzinfo=timezone.utc)
ALL_DAY = (
    datetime(2026, 10, 1, 0, tzinfo=timezone.utc),
    datetime(2026, 10, 1, 23, 59, tzinfo=timezone.utc),
)


def tide(high_metres):
    return [
        TideExtreme(at=LOW, height_metres=0.5),
        TideExtreme(at=HIGH, height_metres=high_metres),
        TideExtreme(at=NEXT_LOW, height_metres=0.5),
    ]


def windows(high_metres, daylight=ALL_DAY):
    return rowable_windows_in_daylight([HIGH], tide(high_metres), daylight)


def test_a_big_tide_is_rowable_from_when_it_passes_3_7m_until_it_drops_back():
    [(_, (start, end))] = windows(5.7)

    # 0.5 m -> 5.7 m over 6h12m crosses 3.7 m at acos(1 - 2*3.2/5.2)/pi of the
    # run: 12814.5s after the low. So roughly 07:21 until 12:38 — a 10:00 high
    # of 5.7 m gives about "7 till 1", not a fixed span either side.
    assert (start - LOW).total_seconds() == pytest.approx(12814.5, abs=0.1)
    assert (NEXT_LOW - end).total_seconds() == pytest.approx(12814.5, abs=0.1)


def test_a_4m_high_tide_is_offered_because_it_holds_3_7m_for_over_two_hours():
    # Rejected outright under the old 4.2 m high-tide target; it actually gives
    # about 2h20m of water above 3.7 m.
    [(_, (start, end))] = windows(4.0)

    assert end - start == pytest.approx(timedelta(seconds=2 * 4221.9), abs=timedelta(seconds=1))


def test_a_3_75m_high_tide_passes_3_7m_too_briefly_to_be_offered():
    # Above 3.7 m for only about 59 minutes — under the 1h a session needs. A
    # 3.8 m peak holds it for about 1h23m, which the 1h rule now accepts; the
    # gate is time at depth, not peak height.
    assert windows(3.75) == []


def test_a_high_tide_before_sunrise_is_offered_when_enough_rowable_water_is_left_in_daylight():
    sunrise = HIGH + timedelta(hours=1)

    [(high_tide, (start, end))] = windows(
        5.7, daylight=(sunrise, sunrise + timedelta(hours=10))
    )

    assert high_tide == HIGH
    assert start == sunrise
    assert end - start >= timedelta(hours=1)


def test_a_high_tide_whose_daylight_share_is_under_1h_is_not_offered():
    # Water above 3.7 m until about 12:38; light only from 11:45, leaving ~53
    # minutes — under the 1h a session needs.
    sunrise = datetime(2026, 10, 1, 11, 45, tzinfo=timezone.utc)

    assert windows(5.7, daylight=(sunrise, sunrise + timedelta(hours=10))) == []


def test_a_day_whose_only_tide_is_too_brief_is_red_and_says_why():
    verdict = rate_day(
        high_tides=[HIGH],
        extremes=tide(3.75),
        daylight=ALL_DAY,
        slots=[
            WeatherSlot(starts_at=LOW + timedelta(hours=h), wind_speed_ms=3.0, rain_mm=0.0)
            for h in range(13)
        ],
        water_release_classification="no_discharge_expected",
        cumulative_rain_mm={},
    )

    assert verdict.rating == RED
    assert verdict.reasons == ["No tide holds 3.7m for 1h in daylight today."]
