from datetime import datetime, timezone

from inputs import (
    all_tide_extremes,
    cumulative_rain_before,
    daily_weather_for,
    daylight_for,
    high_tides_on,
    hourly_slots_for,
)


def utc(day, hour, minute=0):
    return datetime(2026, 8, day, hour, minute, tzinfo=timezone.utc)


TIDE_DOCUMENTS = {
    "2026-08-25": {
        "extremes": [
            {"kind": "High", "time_utc": utc(25, 5), "height_m": 4.81},
            {"kind": "Low", "time_utc": utc(25, 11), "height_m": 1.50},
            {"kind": "High", "time_utc": utc(25, 17), "height_m": 5.09},
        ]
    },
    "2026-08-26": {
        "extremes": [
            {"kind": "Low", "time_utc": utc(25, 23), "height_m": 1.13},
            {"kind": "High", "time_utc": utc(26, 5), "height_m": 5.09},
        ]
    },
}


def test_extremes_are_pooled_across_days_so_a_window_can_span_midnight():
    pooled = all_tide_extremes(TIDE_DOCUMENTS)

    assert [extreme.at for extreme in pooled] == sorted(e.at for e in pooled)
    # The 23:00 low is filed under the 26th but falls on the 25th; the pool has
    # to carry it either way, because it is the low the 26th's 05:00 high rises
    # from.
    assert utc(25, 23) in [extreme.at for extreme in pooled]


def test_only_the_days_own_high_waters_are_offered_for_it():
    assert high_tides_on(TIDE_DOCUMENTS, "2026-08-26") == [utc(26, 5)]


def test_cumulative_rain_reaches_back_over_the_preceding_days():
    weather = {
        "2026-08-23": {"daily": {"rain_mm": 8.0}},
        "2026-08-24": {"daily": {"rain_mm": 4.0}},
        "2026-08-25": {"daily": {"rain_mm": 2.0}},
        "2026-08-26": {"daily": {"rain_mm": 99.0}},
    }

    fallen = cumulative_rain_before(weather, "2026-08-26")

    assert fallen[24] == 2.0
    assert fallen[48] == 6.0
    assert fallen[72] == 14.0


def test_a_missing_past_day_contributes_nothing_rather_than_breaking():
    weather = {"2026-08-25": {"daily": {"rain_mm": 2.0}}}

    assert cumulative_rain_before(weather, "2026-08-26")[72] == 2.0


def test_daylight_and_weather_are_read_off_the_day_document():
    weather = {
        "2026-08-26": {
            "sunrise": utc(26, 5, 34),
            "sunset": utc(26, 20, 38),
            "daily": {"wind_speed_ms": 6.07, "rain_mm": 0.5},
            "hourly": [{"time_utc": utc(26, 6), "wind_speed_ms": 3.76, "rain_mm": 0.0}],
        }
    }

    assert daylight_for(weather, "2026-08-26") == (utc(26, 5, 34), utc(26, 20, 38))
    assert daily_weather_for(weather, "2026-08-26").wind_speed_ms == 6.07
    assert hourly_slots_for(weather, "2026-08-26")[0].starts_at == utc(26, 6)


def test_a_day_beyond_the_forecast_has_no_daylight_and_no_daily_figure():
    assert daylight_for({}, "2026-09-30") is None
    assert daily_weather_for({}, "2026-09-30") is None
    assert hourly_slots_for({}, "2026-09-30") == []
