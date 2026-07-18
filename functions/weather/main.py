"""Fetch Limerick / Athlunkard weather from OpenWeather One Call 4.0 and shape it.

Reusable entrypoint (`fetch_club_weather`) plus a small CLI so we can prove the
source before wiring it into Cloud Functions / Firestore.

The CLI prints only our *derived* data (WeatherPoints / documents) — never the
raw API response, which carries the key in its pagination URLs.

Run:
    source ~/.abc_secrets.env      # sets OPENWEATHER_API_KEY — never commit it
    python functions/weather/main.py
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timezone

from firestore_docs import build_documents
from openweather_client import fetch_daily, fetch_hourly
from parse import parse_points

# Athlunkard Boat Club / Limerick Dock (same point used for tides).
CLUB_LAT = 52.6667
CLUB_LON = -8.6333

# Hourly resolution is only meaningful in the near term; past ~48h OpenWeather
# gives daily only, and the far-out planning tier assumes a flat day anyway.
HOURLY_HORIZON_HOURS = 48

_MS_TO_KMH = 3.6


def fetch_club_weather(
    api_key: str | None = None,
    lat: float = CLUB_LAT,
    lon: float = CLUB_LON,
    hours: int = HOURLY_HORIZON_HOURS,
) -> tuple[list, list]:
    """Fetch and parse the daily + hourly forecasts for the club. Returns
    (daily_points, hourly_points)."""
    api_key = api_key or os.environ.get("OPENWEATHER_API_KEY")
    if not api_key:
        raise SystemExit("Set OPENWEATHER_API_KEY (or pass api_key=).")

    daily = parse_points(fetch_daily(lat, lon, api_key))
    hourly = parse_points(fetch_hourly(lat, lon, api_key, hours=hours))
    return daily, hourly


def main(argv: list[str]) -> int:
    daily, hourly = fetch_club_weather()
    docs = build_documents(daily, hourly, fetched_at=datetime.now(timezone.utc))

    print(
        f"Athlunkard weather — {len(daily)} daily day(s), "
        f"{len(hourly)} hourly point(s) over the next {HOURLY_HORIZON_HOURS}h. "
        "Wind shown m/s (km/h):"
    )
    for date_str in sorted(docs):
        d = docs[date_str]["daily"]
        gust = "" if d["wind_gust_ms"] is None else f" gust {d['wind_gust_ms']}"
        kmh = round(d["wind_speed_ms"] * _MS_TO_KMH, 1)
        n_hourly = len(docs[date_str]["hourly"])
        print(
            f"  {date_str}: wind {d['wind_speed_ms']} m/s ({kmh} km/h){gust}, "
            f"rain {d['rain_mm']} mm, {n_hourly} hourly pt(s)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
