from __future__ import annotations

from datetime import datetime, timedelta

from models import (
    AMBER,
    DISCHARGE_EXPECTED,
    GREEN,
    RED,
    ROWABLE_EITHER_SIDE_OF_HIGH_TIDE,
    UNPARSED,
    DailyWeather,
    DayRating,
    Thresholds,
    WeatherSlot,
)

MINIMUM_SESSION_LENGTH = timedelta(hours=1, minutes=30)


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
            if candidate[1] - candidate[0] >= minimum_length and (
                longest is None or candidate[1] - candidate[0] > longest[1] - longest[0]
            ):
                longest = candidate
            run = []

    return longest


def _rowable_interval(high_tide: datetime) -> tuple[datetime, datetime]:
    return (
        high_tide - ROWABLE_EITHER_SIDE_OF_HIGH_TIDE,
        high_tide + ROWABLE_EITHER_SIDE_OF_HIGH_TIDE,
    )


def _slots_within(
    slots: list[WeatherSlot], interval: tuple[datetime, datetime]
) -> list[WeatherSlot]:
    start, end = interval
    return [s for s in slots if s.starts_at >= start and s.ends_at <= end]


def rate_day(
    *,
    high_tides: list[datetime],
    slots: list[WeatherSlot],
    water_release_classification: str,
    cumulative_rain_mm: dict[int, float],
    daily: DailyWeather | None = None,
    thresholds: Thresholds = Thresholds(),
) -> DayRating:
    reasons: list[str] = []

    if water_release_classification == DISCHARGE_EXPECTED:
        return DayRating(
            RED, None, ["ESB expects a discharge at Parteen Weir — no rowing."]
        )

    if not high_tides:
        return DayRating(
            RED, None, ["No high tide falls in daylight at a rowable height."]
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

    if water_release_classification == UNPARSED:
        reasons.append(
            "ESB's wording did not match any phrasing on record, so the weir "
            "state is unconfirmed — check the forecast before committing."
        )

    if not slots:
        return _rate_from_daily_figure(daily, thresholds, reasons)

    window = None
    for high_tide in sorted(high_tides):
        window = longest_calm_interval(
            _slots_within(slots, _rowable_interval(high_tide)),
            max_wind_kmh=thresholds.wind_kmh_all_boats,
            max_rain_mm=thresholds.rain_mm_all_boats,
        )
        if window is not None:
            break

    if window is not None:
        rating = AMBER if reasons else GREEN
        return DayRating(rating, window, reasons)

    for high_tide in sorted(high_tides):
        window = longest_calm_interval(
            _slots_within(slots, _rowable_interval(high_tide)),
            max_wind_kmh=thresholds.wind_kmh_big_boats,
            max_rain_mm=thresholds.rain_mm_big_boats,
        )
        if window is not None:
            reasons.append(
                "Above the all-boats limit — bigger boats and experienced crews only."
            )
            return DayRating(AMBER, window, reasons)

    reasons.append("No unbroken 1.5h stretch stays under the wind and rain limits.")
    return DayRating(RED, None, reasons)


def _rate_from_daily_figure(
    daily: DailyWeather | None,
    thresholds: Thresholds,
    reasons: list[str],
) -> DayRating:
    """Beyond the hourly horizon a day has one wind and rain figure. That is
    enough to rate it but not to name a session time: a window derived from a
    daily average would read exactly like one derived from real hours."""
    if daily is None:
        return DayRating(None, None, [*reasons, "No forecast reaches this day yet."])

    unconfirmed_weir = list(reasons)
    reasons = [
        *reasons,
        "Hourly forecast does not reach this day, so no session time yet.",
    ]

    if (
        daily.wind_speed_kmh <= thresholds.wind_kmh_all_boats
        and daily.rain_mm <= thresholds.rain_mm_all_boats
    ):
        return DayRating(AMBER if unconfirmed_weir else GREEN, None, reasons)

    if (
        daily.wind_speed_kmh <= thresholds.wind_kmh_big_boats
        and daily.rain_mm <= thresholds.rain_mm_big_boats
    ):
        reasons.append(
            "Above the all-boats limit — bigger boats and experienced crews only."
        )
        return DayRating(AMBER, None, reasons)

    reasons.append("Forecast is over the wind or rain limit all day.")
    return DayRating(RED, None, reasons)
