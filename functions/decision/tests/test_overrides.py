from datetime import datetime, timedelta, timezone

from engine import rate_day
from models import RED, GREEN, WeatherSlot

DISCHARGE_EXPECTED = "discharge_expected"
NO_DISCHARGE_EXPECTED = "no_discharge_expected"
UNPARSED = "unparsed"


def calm_day():
    start = datetime(2026, 8, 26, 6, tzinfo=timezone.utc)
    return [
        WeatherSlot(
            starts_at=start + timedelta(hours=index),
            wind_speed_ms=3.0,
            rain_mm=0.0,
        )
        for index in range(6)
    ]


def rate(classification=NO_DISCHARGE_EXPECTED, high_tides=None, slots=None):
    return rate_day(
        high_tides=(
            [datetime(2026, 8, 26, 8, tzinfo=timezone.utc)]
            if high_tides is None
            else high_tides
        ),
        slots=calm_day() if slots is None else slots,
        water_release_classification=classification,
        cumulative_rain_mm={24: 0.0, 48: 0.0, 72: 0.0},
    )


def test_a_confirmed_discharge_forces_red_through_perfect_weather():
    verdict = rate(classification=DISCHARGE_EXPECTED)

    assert verdict.rating == RED
    assert verdict.window is None
    assert any("discharg" in reason.lower() for reason in verdict.reasons)


def test_wording_esb_has_never_used_is_never_read_as_clear():
    verdict = rate(classification=UNPARSED)

    assert verdict.rating != GREEN
    assert any("esb" in reason.lower() for reason in verdict.reasons)


def test_no_rowable_high_tide_leaves_nothing_to_rate():
    verdict = rate(high_tides=[])

    assert verdict.rating == RED
    assert verdict.window is None


def test_a_clear_forecast_and_calm_weather_is_green():
    verdict = rate()

    assert verdict.rating == GREEN
    assert verdict.window is not None
