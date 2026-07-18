"""Parse OpenWeather One Call 4.0 timeline responses into WeatherPoint objects.

Pure (no HTTP/network): the client hands us an already-decoded payload, so this
is unit-tested against captured real responses without a key.

Handles both timeline shapes returned by `/data/4.0/onecall/timeline/...`:
- hourly (`1h`): records carry `wind_gust` and `pop`; rain, when present, is the
  object `{"1h": mm}`.
- daily (`1day`): records omit `wind_gust` and `pop`; rain, when present, is a
  plain number.

Absent fields are represented honestly — gust/pop → None, rain → 0.0 — rather
than invented, since OpenWeather omits `rain` entirely in dry periods and omits
gust/pop from daily records.
"""

from __future__ import annotations

from datetime import datetime, timezone

from models import WeatherPoint


def parse_points(payload: dict) -> list[WeatherPoint]:
    """Map a 4.0 timeline payload's `data` records to WeatherPoints (UTC)."""
    return [_point(record) for record in payload.get("data", [])]


def _point(record: dict) -> WeatherPoint:
    gust = record.get("wind_gust")
    pop = record.get("pop")
    return WeatherPoint(
        time_utc=datetime.fromtimestamp(record["dt"], tz=timezone.utc),
        wind_speed_ms=float(record["wind_speed"]),
        wind_gust_ms=None if gust is None else float(gust),
        rain_mm=_rain_mm(record),
        pop=None if pop is None else float(pop),
    )


def _rain_mm(record: dict) -> float:
    """Rain for the slot in mm. Absent when dry; `{"1h": mm}` (hourly) or a plain
    number (daily) when present."""
    rain = record.get("rain")
    if rain is None:
        return 0.0
    if isinstance(rain, dict):
        return float(rain.get("1h", 0.0))
    return float(rain)
