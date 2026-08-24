from datetime import datetime, timedelta, timezone

from engine import rate_day
from models import AMBER, GREEN, RED, DailyWeather
from tide_curve import TideExtreme

HIGH_TIDE = datetime(2026, 9, 1, 8, tzinfo=timezone.utc)
EXTREMES = [
    TideExtreme(at=HIGH_TIDE - timedelta(hours=6), height_metres=1.0),
    TideExtreme(at=HIGH_TIDE, height_metres=5.0),
    TideExtreme(at=HIGH_TIDE + timedelta(hours=6), height_metres=1.0),
]
DAYLIGHT = (
    datetime(2026, 9, 1, 5, tzinfo=timezone.utc),
    datetime(2026, 9, 1, 20, tzinfo=timezone.utc),
)


def rate(daily):
    return rate_day(
        high_tides=[HIGH_TIDE],
        extremes=EXTREMES,
        daylight=DAYLIGHT,
        slots=[],
        daily=daily,
        water_release_classification="no_discharge_expected",
        cumulative_rain_mm={24: 0.0, 48: 0.0, 72: 0.0},
    )


def test_a_calm_far_day_is_rated_from_its_daily_figure():
    verdict = rate(DailyWeather(wind_speed_ms=3.0, rain_mm=0.0))

    assert verdict.rating == GREEN


def test_a_far_day_still_gets_a_window_and_says_it_is_approximated():
    verdict = rate(DailyWeather(wind_speed_ms=3.0, rain_mm=0.0))

    assert verdict.window is not None
    assert any("approximated" in reason.lower() for reason in verdict.reasons)
    assert any("hourly" in reason.lower() for reason in verdict.reasons)


def test_a_windy_far_day_is_still_red():
    verdict = rate(DailyWeather(wind_speed_ms=15.0, rain_mm=0.0))

    assert verdict.rating == RED


def test_a_far_day_only_big_boats_could_row_is_amber():
    verdict = rate(DailyWeather(wind_speed_ms=7.0, rain_mm=0.0))

    assert verdict.rating == AMBER


def test_no_forecast_at_all_is_not_a_rating():
    verdict = rate(None)

    assert verdict.rating is None
    assert any("no forecast" in reason.lower() for reason in verdict.reasons)


def test_hourly_detail_is_preferred_over_the_daily_figure_where_it_reaches():
    from models import WeatherSlot

    gusty_hours = [
        WeatherSlot(
            starts_at=HIGH_TIDE - timedelta(hours=6) + timedelta(hours=index),
            wind_speed_ms=20.0,
            rain_mm=0.0,
        )
        for index in range(12)
    ]

    verdict = rate_day(
        high_tides=[HIGH_TIDE],
        extremes=EXTREMES,
        daylight=DAYLIGHT,
        slots=gusty_hours,
        daily=DailyWeather(wind_speed_ms=1.0, rain_mm=0.0),
        water_release_classification="no_discharge_expected",
        cumulative_rain_mm={},
    )

    assert verdict.rating == RED
    assert not any("approximated" in reason.lower() for reason in verdict.reasons)
