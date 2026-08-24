from __future__ import annotations

import math
from datetime import datetime, timedelta

from models import (
    AMBER,
    DISCHARGE_EXPECTED,
    GREEN,
    MINIMUM_ROWABLE_HEIGHT_METRES,
    RED,
    SLOT_DURATION,
    UNPARSED,
    DailyWeather,
    DayRating,
    Thresholds,
    WeatherSlot,
)
from tide_curve import TideExtreme, rowable_interval

MINIMUM_SESSION_LENGTH = timedelta(hours=1, minutes=30)

APPROXIMATED_FORECAST = (
    "Approximated from the whole-day forecast. This sharpens closer to the "
    "time, once hourly detail reaches this day."
)
UNCONFIRMED_WEIR = (
    "ESB's wording did not match any phrasing on record, so the weir state is "
    "unconfirmed — check the forecast before committing."
)
BIG_BOATS_ONLY = "Above the all-boats limit — bigger boats and experienced crews only."


def longest_calm_interval(
    slots: list[WeatherSlot],
    *,
    max_wind_kmh: float,
    max_rain_mm: float,
    minimum_length: timedelta = MINIMUM_SESSION_LENGTH,
) -> tuple[datetime, datetime] | None:
    """The longest unbroken stretch where every hour stays under both
    thresholds. A crew cannot land mid-session because the wind got up, so a
    stretch counts only if it holds for the whole interval."""

    def is_calm(slot: WeatherSlot) -> bool:
        return slot.wind_speed_kmh <= max_wind_kmh and slot.rain_mm <= max_rain_mm

    longest: tuple[datetime, datetime] | None = None
    run: list[WeatherSlot] = []

    for slot in [*slots, None]:
        if slot is not None and is_calm(slot):
            run.append(slot)
            continue
        if run:
            candidate = (run[0].starts_at, run[-1].ends_at)
            length = candidate[1] - candidate[0]
            if length >= minimum_length and (
                longest is None or length > longest[1] - longest[0]
            ):
                longest = candidate
            run = []

    return longest


def _overlap(
    first: tuple[datetime, datetime], second: tuple[datetime, datetime]
) -> tuple[datetime, datetime] | None:
    start = max(first[0], second[0])
    end = min(first[1], second[1])
    return (start, end) if end > start else None


def _slots_across(
    interval: tuple[datetime, datetime],
    hourly: list[WeatherSlot],
    daily: DailyWeather | None,
) -> tuple[list[WeatherSlot], bool]:
    """Hourly detail where it reaches, otherwise the day's single figure spread
    flat across the interval. Flat is enough to answer whether the day is
    rowable; what it cannot do is tell one hour from another."""
    start, end = interval
    within = [s for s in hourly if s.starts_at >= start and s.ends_at <= end]
    if within:
        return within, False
    if daily is None:
        return [], False
    hours = max(math.floor((end - start) / SLOT_DURATION), 0)
    return (
        [
            WeatherSlot(
                starts_at=start + index * SLOT_DURATION,
                wind_speed_ms=daily.wind_speed_ms,
                rain_mm=daily.rain_mm,
            )
            for index in range(hours)
        ],
        True,
    )


def rowable_windows_in_daylight(
    high_tides: list[datetime],
    extremes: list[TideExtreme],
    daylight: tuple[datetime, datetime] | None,
    *,
    minimum_height_metres: float = MINIMUM_ROWABLE_HEIGHT_METRES,
) -> list[tuple[datetime, datetime]]:
    windows = []
    for high_tide in sorted(high_tides):
        interval = rowable_interval(
            high_tide, extremes, minimum_height_metres=minimum_height_metres
        )
        if interval is None:
            continue
        if daylight is not None:
            interval = _overlap(interval, daylight)
        if interval is not None:
            windows.append(interval)
    return windows


def rate_day(
    *,
    high_tides: list[datetime],
    extremes: list[TideExtreme],
    daylight: tuple[datetime, datetime] | None = None,
    slots: list[WeatherSlot],
    daily: DailyWeather | None = None,
    water_release_classification: str,
    cumulative_rain_mm: dict[int, float],
    thresholds: Thresholds = Thresholds(),
) -> DayRating:
    if water_release_classification == DISCHARGE_EXPECTED:
        return DayRating(
            RED, None, ["ESB expects a discharge at Parteen Weir — no rowing."]
        )

    windows = rowable_windows_in_daylight(high_tides, extremes, daylight)
    if not windows:
        return DayRating(
            RED, None, ["No high tide holds a rowable depth in daylight today."]
        )

    for hours, limit in sorted(thresholds.cumulative_rain_mm.items()):
        fallen = cumulative_rain_mm.get(hours)
        if fallen is not None and fallen > limit:
            return DayRating(
                RED,
                None,
                [
                    f"{fallen:.0f} mm of rain in the last {hours}h, over the "
                    f"{limit:.0f} mm limit."
                ],
            )

    reasons: list[str] = []
    if water_release_classification == UNPARSED:
        reasons.append(UNCONFIRMED_WEIR)

    if daily is None and not slots:
        return DayRating(None, None, [*reasons, "No forecast reaches this day yet."])

    for max_wind, max_rain, big_boats_only in (
        (thresholds.wind_kmh_all_boats, thresholds.rain_mm_all_boats, False),
        (thresholds.wind_kmh_big_boats, thresholds.rain_mm_big_boats, True),
    ):
        for interval in windows:
            across, approximated = _slots_across(interval, slots, daily)
            calm = longest_calm_interval(
                across, max_wind_kmh=max_wind, max_rain_mm=max_rain
            )
            if calm is None:
                continue
            found = [*reasons]
            if approximated:
                found.append(APPROXIMATED_FORECAST)
            if big_boats_only:
                found.append(BIG_BOATS_ONLY)
            rating = AMBER if (big_boats_only or reasons) else GREEN
            return DayRating(rating, calm, found)

    return DayRating(
        RED,
        None,
        [*reasons, "No unbroken 1.5h stretch stays under the wind and rain limits."],
    )
