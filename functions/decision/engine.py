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
    WindowRating,
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
ALREADY_PASSED = "This tide has already turned; the window has passed."


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
    """Real hours wherever the forecast reaches, the day's single figure for the
    rest. Coverage is partial more often than not: hours drop off the front of
    the series as the fetcher refreshes, and the hourly horizon runs out at the
    far end, so a window sitting across either edge gets some of each.
    """
    start, end = interval
    by_hour = {slot.starts_at: slot for slot in hourly}
    hours = max(math.floor((end - start) / SLOT_DURATION), 0)

    across: list[WeatherSlot] = []
    approximated = False
    for index in range(hours):
        at = start + index * SLOT_DURATION
        real = by_hour.get(at.replace(minute=0, second=0, microsecond=0))
        if real is not None:
            across.append(WeatherSlot(at, real.wind_speed_ms, real.rain_mm))
            continue
        if daily is None:
            continue
        approximated = True
        across.append(WeatherSlot(at, daily.wind_speed_ms, daily.rain_mm))

    return across, approximated


def rowable_windows_in_daylight(
    high_tides: list[datetime],
    extremes: list[TideExtreme],
    daylight: tuple[datetime, datetime] | None,
    *,
    minimum_height_metres: float = MINIMUM_ROWABLE_HEIGHT_METRES,
) -> list[tuple[datetime, tuple[datetime, datetime]]]:
    """Each rowable high tide paired with the stretch it holds a rowable depth
    for, clipped to daylight."""
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
            windows.append((high_tide, interval))
    return windows


def _rate_one_window(
    high_tide: datetime,
    interval: tuple[datetime, datetime],
    slots: list[WeatherSlot],
    daily: DailyWeather | None,
    thresholds: Thresholds,
    now: datetime | None = None,
) -> WindowRating:
    if now is not None:
        remaining = _overlap(interval, (now, interval[1]))
        if remaining is None:
            return WindowRating(high_tide, RED, None, [ALREADY_PASSED])
        interval = remaining

    across, approximated = _slots_across(interval, slots, daily)
    reasons = [APPROXIMATED_FORECAST] if approximated else []

    for max_wind, max_rain, big_boats_only in (
        (thresholds.wind_kmh_all_boats, thresholds.rain_mm_all_boats, False),
        (thresholds.wind_kmh_big_boats, thresholds.rain_mm_big_boats, True),
    ):
        calm = longest_calm_interval(
            across, max_wind_kmh=max_wind, max_rain_mm=max_rain
        )
        if calm is None:
            continue
        return WindowRating(
            high_tide_at=high_tide,
            rating=AMBER if big_boats_only else GREEN,
            window=calm,
            reasons=[*reasons, BIG_BOATS_ONLY] if big_boats_only else reasons,
        )

    return WindowRating(
        high_tide_at=high_tide,
        rating=RED,
        window=None,
        reasons=[*reasons, "No unbroken 1.5h stretch stays under the limits."],
    )


def _best(ratings: list[str]) -> str:
    for rating in (GREEN, AMBER, RED):
        if rating in ratings:
            return rating
    return RED


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
    now: datetime | None = None,
) -> DayRating:
    if water_release_classification == DISCHARGE_EXPECTED:
        return DayRating(RED, ["ESB expects a discharge at Parteen Weir — no rowing."])

    windows = rowable_windows_in_daylight(high_tides, extremes, daylight)
    if not windows:
        return DayRating(RED, ["No high tide holds a rowable depth in daylight today."])

    for hours, limit in sorted(thresholds.cumulative_rain_mm.items()):
        fallen = cumulative_rain_mm.get(hours)
        if fallen is not None and fallen > limit:
            return DayRating(
                RED,
                [
                    f"{fallen:.0f} mm of rain in the last {hours}h, over the "
                    f"{limit:.0f} mm limit."
                ],
            )

    day_reasons: list[str] = []
    if water_release_classification == UNPARSED:
        day_reasons.append(UNCONFIRMED_WEIR)

    if daily is None and not slots:
        return DayRating(None, [*day_reasons, "No forecast reaches this day yet."])

    rated = [
        _rate_one_window(high_tide, interval, slots, daily, thresholds, now)
        for high_tide, interval in windows
    ]
    day_rating = _best([window.rating for window in rated])
    if day_rating == GREEN and day_reasons:
        day_rating = AMBER
    return DayRating(day_rating, day_reasons, rated)
