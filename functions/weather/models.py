from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from zoneinfo import ZoneInfo

# The club's local timezone. Using the IANA zone (not a fixed offset) means Irish
# Summer Time / GMT — daylight-saving — is handled automatically.
CLUB_TZ = ZoneInfo("Europe/Dublin")


@dataclass(frozen=True)
class WeatherPoint:
    """Wind + rain for one forecast slot — an hour (hourly series) or a whole
    day (daily aggregate).

    Only the fields that feed the row/no-row decision are kept; temperature,
    humidity, cloud, pressure etc. are deliberately dropped (YAGNI). The time is
    stored as a UTC instant (unambiguous); local time is derived on demand so
    daylight-saving is always applied correctly.
    """

    time_utc: datetime  # timezone-aware, UTC (for a daily point: the day's ref instant)
    wind_speed_ms: float  # sustained wind, m/s (provider-native SI)
    wind_gust_ms: float | None  # gust, m/s — nullable (not always present)
    rain_mm: float  # precipitation for the period, mm
    pop: (
        float | None
    )  # probability of precipitation, 0..1 — nullable (4.0 daily omits it)
    # Daylight bounds for the day. Present only on daily records — the mirror
    # of gust/pop above, which only hourly records carry. Daylight is a hard
    # override in the row/no-row decision, so these are stored, not dropped.
    sunrise_utc: datetime | None
    sunset_utc: datetime | None

    @property
    def time_local(self) -> datetime:
        """The slot in the club's local time (Europe/Dublin, DST-aware)."""
        return self.time_utc.astimezone(CLUB_TZ)

    def metrics(self) -> dict:
        """Just the decision metrics — used for a day's `daily` aggregate, where
        the document's date key already carries the day."""
        return {
            "wind_speed_ms": round(self.wind_speed_ms, 2),
            "wind_gust_ms": (
                None if self.wind_gust_ms is None else round(self.wind_gust_ms, 2)
            ),
            "rain_mm": round(self.rain_mm, 2),
            "pop": None if self.pop is None else round(self.pop, 2),
        }

    def to_dict(self) -> dict:
        """Metrics plus the timestamp — used for entries in the `hourly` series.
        `time_utc` is left as a datetime, which Firestore stores as a Timestamp.
        """
        return {"time_utc": self.time_utc, **self.metrics()}
