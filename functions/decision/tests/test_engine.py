from datetime import datetime, timedelta, timezone

from engine import longest_calm_interval
from models import WeatherSlot

CALM = 3.0
GUSTY = 12.0


def slots(*wind_speeds_ms, start_hour=6):
    start = datetime(2026, 8, 26, start_hour, tzinfo=timezone.utc)
    return [
        WeatherSlot(
            starts_at=start + timedelta(hours=index),
            wind_speed_ms=speed,
            rain_mm=0.0,
        )
        for index, speed in enumerate(wind_speeds_ms)
    ]


def test_a_flat_calm_run_is_the_whole_interval():
    calm = slots(CALM, CALM, CALM)

    found = longest_calm_interval(calm, max_wind_kmh=30, max_rain_mm=5)

    assert found == (calm[0].starts_at, calm[-1].ends_at)


def test_the_gusty_hours_are_trimmed_off_each_end():
    series = slots(GUSTY, CALM, CALM, GUSTY)

    found = longest_calm_interval(series, max_wind_kmh=30, max_rain_mm=5)

    assert found == (series[1].starts_at, series[2].ends_at)


def test_the_longer_of_two_calm_runs_wins():
    series = slots(CALM, CALM, GUSTY, CALM, CALM, CALM)

    found = longest_calm_interval(series, max_wind_kmh=30, max_rain_mm=5)

    assert found == (series[3].starts_at, series[5].ends_at)


def test_a_run_shorter_than_the_minimum_is_no_window_at_all():
    series = slots(GUSTY, CALM, GUSTY)

    assert longest_calm_interval(series, max_wind_kmh=30, max_rain_mm=5) is None
