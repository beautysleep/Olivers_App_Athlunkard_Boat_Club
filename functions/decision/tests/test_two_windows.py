from datetime import datetime, timezone

from engine import rate_day
from models import AMBER, GREEN, RED, WeatherSlot
from tide_curve import TideExtreme


def utc(hour, minute=0):
    return datetime(2026, 8, 26, hour, minute, tzinfo=timezone.utc)


MORNING_HIGH = utc(6)
EVENING_HIGH = utc(18)
EXTREMES = [
    TideExtreme(at=utc(0), height_metres=1.0),
    TideExtreme(at=MORNING_HIGH, height_metres=5.0),
    TideExtreme(at=utc(12), height_metres=1.0),
    TideExtreme(at=EVENING_HIGH, height_metres=5.0),
    TideExtreme(at=utc(23, 59), height_metres=1.0),
]
DAYLIGHT = (utc(5), utc(21))


def hours(wind_by_hour):
    return [
        WeatherSlot(starts_at=utc(hour), wind_speed_ms=wind, rain_mm=0.0)
        for hour, wind in wind_by_hour.items()
    ]


def rate(slots):
    return rate_day(
        high_tides=[MORNING_HIGH, EVENING_HIGH],
        extremes=EXTREMES,
        daylight=DAYLIGHT,
        slots=slots,
        water_release_classification="no_discharge_expected",
        cumulative_rain_mm={},
    )


def test_both_rowable_tides_are_reported_separately():
    verdict = rate(hours({hour: 3.0 for hour in range(24)}))

    assert [window.high_tide_at for window in verdict.windows] == [
        MORNING_HIGH,
        EVENING_HIGH,
    ]


def test_a_windy_morning_does_not_condemn_a_calm_evening():
    windy_morning = {hour: 20.0 for hour in range(0, 12)}
    calm_evening = {hour: 3.0 for hour in range(12, 24)}
    verdict = rate(hours({**windy_morning, **calm_evening}))

    morning, evening = verdict.windows
    assert morning.rating == RED
    assert morning.window is None
    assert evening.rating == GREEN
    assert evening.window is not None


def test_the_day_takes_the_best_of_its_tides():
    windy_morning = {hour: 20.0 for hour in range(0, 12)}
    calm_evening = {hour: 3.0 for hour in range(12, 24)}

    assert rate(hours({**windy_morning, **calm_evening})).rating == GREEN


def test_a_day_is_only_red_when_neither_tide_works():
    assert rate(hours({hour: 25.0 for hour in range(24)})).rating == RED


def test_an_unconfirmed_weir_holds_the_day_back_from_green():
    verdict = rate_day(
        high_tides=[MORNING_HIGH, EVENING_HIGH],
        extremes=EXTREMES,
        daylight=DAYLIGHT,
        slots=hours({hour: 3.0 for hour in range(24)}),
        water_release_classification="unparsed",
        cumulative_rain_mm={},
    )

    assert verdict.rating == AMBER
    assert all(window.rating == GREEN for window in verdict.windows)
