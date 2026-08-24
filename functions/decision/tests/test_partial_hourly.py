from datetime import datetime, timedelta, timezone

from engine import rate_day
from models import GREEN, RED, DailyWeather, WeatherSlot
from tide_curve import TideExtreme


def utc(hour, minute=0):
    return datetime(2026, 8, 24, hour, minute, tzinfo=timezone.utc)


HIGH = utc(16)
EXTREMES = [
    TideExtreme(at=utc(10), height_metres=1.0),
    TideExtreme(at=HIGH, height_metres=5.0),
    TideExtreme(at=utc(22), height_metres=1.0),
]
DAYLIGHT = (utc(5), utc(20))
CALM_DAY = DailyWeather(wind_speed_ms=3.0, rain_mm=0.0)


def rate(slots, daily=CALM_DAY, now=None):
    return rate_day(
        high_tides=[HIGH],
        extremes=EXTREMES,
        daylight=DAYLIGHT,
        slots=slots,
        daily=daily,
        water_release_classification="no_discharge_expected",
        cumulative_rain_mm={},
        now=now,
    )


def test_hours_the_forecast_no_longer_covers_fall_back_to_the_daily_figure():
    # The fetcher trims past hours, so a window can start before the series
    # does. One surviving hour is not grounds for calling the day unrowable.
    late_arriving = [
        WeatherSlot(starts_at=utc(17), wind_speed_ms=3.0, rain_mm=0.0),
    ]

    verdict = rate(late_arriving)

    assert verdict.rating == GREEN
    assert any("approximated" in r.lower() for r in verdict.windows[0].reasons)


def test_a_fully_covered_window_is_not_called_approximated():
    covered = [
        WeatherSlot(starts_at=utc(hour), wind_speed_ms=3.0, rain_mm=0.0)
        for hour in range(13, 20)
    ]

    verdict = rate(covered)

    assert verdict.rating == GREEN
    assert not any("approximated" in r.lower() for r in verdict.windows[0].reasons)


def test_real_hours_still_beat_the_daily_figure_where_they_exist():
    gusty_real_hours = [
        WeatherSlot(starts_at=utc(hour), wind_speed_ms=25.0, rain_mm=0.0)
        for hour in range(13, 20)
    ]

    assert rate(gusty_real_hours, daily=CALM_DAY).rating == RED


def test_a_window_that_has_already_passed_is_not_offered():
    verdict = rate([], now=utc(19))

    assert verdict.windows[0].window is None
    assert any("passed" in r.lower() for r in verdict.windows[0].reasons)


def test_a_window_underway_is_clipped_to_the_time_that_is_left():
    verdict = rate([], now=utc(15))

    assert verdict.windows[0].window[0] == utc(15)
    assert verdict.windows[0].window[1] > utc(15) + timedelta(hours=1, minutes=30)
