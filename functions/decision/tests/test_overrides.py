from datetime import datetime, timedelta, timezone

from engine import rate_day
from models import GREEN, RED, WeatherSlot
from tide_curve import TideExtreme

HIGH_TIDE = datetime(2026, 8, 26, 8, tzinfo=timezone.utc)
DISCHARGE_EXPECTED = "discharge_expected"
NO_DISCHARGE_EXPECTED = "no_discharge_expected"
UNPARSED = "unparsed"

# A 5.0 m high tide between 1.0 m lows holds 4.2 m for roughly three and a half
# hours, which is long enough for the 1.5h session rule to have something to
# find.
EXTREMES = [
    TideExtreme(at=HIGH_TIDE - timedelta(hours=6), height_metres=1.0),
    TideExtreme(at=HIGH_TIDE, height_metres=5.0),
    TideExtreme(at=HIGH_TIDE + timedelta(hours=6), height_metres=1.0),
]
DAYLIGHT = (
    datetime(2026, 8, 26, 5, tzinfo=timezone.utc),
    datetime(2026, 8, 26, 20, tzinfo=timezone.utc),
)


def calm_hours():
    start = HIGH_TIDE - timedelta(hours=6)
    return [
        WeatherSlot(
            starts_at=start + timedelta(hours=index),
            wind_speed_ms=3.0,
            rain_mm=0.0,
        )
        for index in range(12)
    ]


def rate(classification=NO_DISCHARGE_EXPECTED, high_tides=None, slots=None):
    return rate_day(
        high_tides=[HIGH_TIDE] if high_tides is None else high_tides,
        extremes=EXTREMES,
        daylight=DAYLIGHT,
        slots=calm_hours() if slots is None else slots,
        water_release_classification=classification,
        cumulative_rain_mm={24: 0.0, 48: 0.0, 72: 0.0},
    )


def test_a_confirmed_discharge_forces_red_through_perfect_weather():
    verdict = rate(classification=DISCHARGE_EXPECTED)

    assert verdict.rating == RED
    assert verdict.windows == []
    assert any("discharg" in reason.lower() for reason in verdict.reasons)


def test_wording_esb_has_never_used_is_never_read_as_clear():
    verdict = rate(classification=UNPARSED)

    assert verdict.rating != GREEN
    assert any("esb" in reason.lower() for reason in verdict.reasons)


def test_no_rowable_high_tide_leaves_nothing_to_rate():
    verdict = rate(high_tides=[])

    assert verdict.rating == RED
    assert verdict.windows == []


def test_a_high_tide_outside_daylight_is_not_offered():
    verdict = rate_day(
        high_tides=[HIGH_TIDE],
        extremes=EXTREMES,
        daylight=(
            datetime(2026, 8, 26, 14, tzinfo=timezone.utc),
            datetime(2026, 8, 26, 20, tzinfo=timezone.utc),
        ),
        slots=calm_hours(),
        water_release_classification=NO_DISCHARGE_EXPECTED,
        cumulative_rain_mm={},
    )

    assert verdict.rating == RED


def test_a_clear_forecast_and_calm_weather_is_green():
    verdict = rate()

    assert verdict.rating == GREEN
    assert verdict.windows[0].window is not None
