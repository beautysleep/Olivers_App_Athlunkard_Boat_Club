from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta

SLOT_DURATION = timedelta(hours=1)

# Mirrors the values water_release/models.py writes; this service reads them
# back off the stored document, so it is the wire format that is shared, not
# code — the two functions deploy separately.
DISCHARGE_EXPECTED = "discharge_expected"
UNPARSED = "unparsed"

GREEN = "green"
AMBER = "amber"
RED = "red"

# The depth the club needs under them. How long a tide holds it is not a fixed
# span: it falls out of the curve between the neighbouring lows, so a bigger
# tide stays rowable for longer. Provisional, and the coaches' number.
MINIMUM_ROWABLE_HEIGHT_METRES = 4.2


@dataclass(frozen=True)
class Thresholds:
    """Provisional, from Data_needed_for_rowing_safety_decision.md. Big boats
    tolerate more than the all-boats figure, which is the stricter gate: meeting
    only the big-boat figure is what amber means."""

    wind_kmh_all_boats: float = 20.0
    wind_kmh_big_boats: float = 30.0
    rain_mm_all_boats: float = 5.0
    rain_mm_big_boats: float = 15.0
    cumulative_rain_mm: dict[int, float] = field(
        default_factory=lambda: {24: 100.0, 48: 150.0, 72: 150.0}
    )


@dataclass(frozen=True)
class DailyWeather:
    """A whole day as one figure, which is all OpenWeather offers beyond its
    ~48h hourly horizon."""

    wind_speed_ms: float
    rain_mm: float

    @property
    def wind_speed_kmh(self) -> float:
        return self.wind_speed_ms * 3.6


@dataclass(frozen=True)
class DayRating:
    rating: str | None
    window: tuple[datetime, datetime] | None
    reasons: list[str]


@dataclass(frozen=True)
class WeatherSlot:
    """One hour of forecast. Wind is m/s as stored; the thresholds are km/h, so
    the conversion happens at the comparison rather than in the store."""

    starts_at: datetime
    wind_speed_ms: float
    rain_mm: float

    @property
    def ends_at(self) -> datetime:
        return self.starts_at + SLOT_DURATION

    @property
    def wind_speed_kmh(self) -> float:
        return self.wind_speed_ms * 3.6
