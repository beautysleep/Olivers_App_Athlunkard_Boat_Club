from datetime import datetime, timezone

from engine import rate_day
from models import RED, AMBER, GREEN, DailyWeather

HIGH_TIDE = [datetime(2026, 9, 1, 8, tzinfo=timezone.utc)]
NO_RAIN = {24: 0.0, 48: 0.0, 72: 0.0}


def rate(daily):
    return rate_day(
        high_tides=HIGH_TIDE,
        slots=[],
        daily=daily,
        water_release_classification="no_discharge_expected",
        cumulative_rain_mm=NO_RAIN,
    )


def test_a_calm_far_day_is_rated_from_its_daily_figure_not_condemned():
    verdict = rate(DailyWeather(wind_speed_ms=3.0, rain_mm=0.0))

    assert verdict.rating == GREEN


def test_a_far_day_never_claims_a_window_it_cannot_know():
    verdict = rate(DailyWeather(wind_speed_ms=3.0, rain_mm=0.0))

    assert verdict.window is None
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
