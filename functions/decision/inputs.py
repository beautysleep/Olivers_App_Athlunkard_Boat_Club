"""Turn the stored tide and weather documents into one day's decision inputs.

Pure: the caller hands over already-read documents, so every case here — a
window spanning midnight, a gap in the rain history, a day past the forecast —
is exercised without touching Firestore.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta

from models import CUMULATIVE_RAIN_HOURS, DailyWeather, WeatherSlot
from tide_curve import TideExtreme


def all_tide_extremes(tide_documents: dict[str, dict]) -> list[TideExtreme]:
    """Every extreme from every day, pooled and ordered.

    A high tide rises from the low before it, which may sit in the previous
    day's document, so the curve cannot be built from one day alone.
    """
    pooled = [
        TideExtreme(at=extreme["time_utc"], height_metres=extreme["height_m"])
        for document in tide_documents.values()
        for extreme in document.get("extremes", [])
    ]
    return sorted(pooled, key=lambda extreme: extreme.at)


def high_tides_on(tide_documents: dict[str, dict], date_str: str) -> list[datetime]:
    document = tide_documents.get(date_str, {})
    return sorted(
        extreme["time_utc"]
        for extreme in document.get("extremes", [])
        if extreme.get("kind") == "High"
    )


def cumulative_rain_before(
    weather_documents: dict[str, dict], date_str: str
) -> dict[int, float]:
    """Rain over the days leading up to this one, from what was last forecast
    for each. Days we hold nothing for contribute nothing, which understates
    rather than invents.
    """
    day = date.fromisoformat(date_str)
    totals: dict[int, float] = {}
    for hours in CUMULATIVE_RAIN_HOURS:
        totals[hours] = sum(
            _daily_field(
                weather_documents, (day - timedelta(days=back)).isoformat(), "rain_mm"
            )
            or 0.0
            for back in range(1, hours // 24 + 1)
        )
    return totals


def daylight_for(
    weather_documents: dict[str, dict], date_str: str
) -> tuple[datetime, datetime] | None:
    document = weather_documents.get(date_str, {})
    sunrise, sunset = document.get("sunrise"), document.get("sunset")
    if sunrise is None or sunset is None:
        return None
    return (sunrise, sunset)


def daily_weather_for(
    weather_documents: dict[str, dict], date_str: str
) -> DailyWeather | None:
    wind = _daily_field(weather_documents, date_str, "wind_speed_ms")
    if wind is None:
        return None
    return DailyWeather(
        wind_speed_ms=wind,
        rain_mm=_daily_field(weather_documents, date_str, "rain_mm") or 0.0,
    )


def hourly_slots_for(
    weather_documents: dict[str, dict], date_str: str
) -> list[WeatherSlot]:
    document = weather_documents.get(date_str, {})
    return [
        WeatherSlot(
            starts_at=hour["time_utc"],
            wind_speed_ms=hour["wind_speed_ms"],
            rain_mm=hour.get("rain_mm") or 0.0,
        )
        for hour in document.get("hourly", [])
        if hour.get("wind_speed_ms") is not None
    ]


def _daily_field(
    weather_documents: dict[str, dict], date_str: str, field: str
) -> float | None:
    daily = (weather_documents.get(date_str) or {}).get("daily") or {}
    return daily.get(field)
