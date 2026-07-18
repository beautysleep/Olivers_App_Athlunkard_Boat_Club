"""Thin HTTP client for the OpenWeather One Call 4.0 timeline endpoints.

Isolated from parsing so the rest of the service stays testable without the
network or a key.

Key-safety (One Call 4.0 embeds `appid` in the `prev`/`next` URLs it returns):
- `prev`/`next` are dropped from every payload the moment it arrives, so they can
  never be logged, stored, or paginated through.
- Pagination is done by rebuilding the request from our own params (`start`), not
  by following the returned URLs.
- Errors reference the bare endpoint path only — never the query string that
  carries the key.
"""

from __future__ import annotations

import requests

BASE_URL = "https://api.openweathermap.org/data/4.0/onecall"

# One page of the hourly timeline is ~20 records; step forward by the hour.
_HOUR = 3600


class OpenWeatherError(RuntimeError):
    """Raised when OpenWeather returns a non-200 or an unusable payload."""


def fetch_daily(lat: float, lon: float, api_key: str, *, timeout: int = 20) -> dict:
    """One daily-timeline page (~10 days) — covers our multi-day horizon in a
    single call. Returns the payload with `data` records."""
    return _get(f"{BASE_URL}/timeline/1day", {"lat": lat, "lon": lon}, api_key, timeout)


def fetch_hourly(
    lat: float,
    lon: float,
    api_key: str,
    *,
    hours: int = 48,
    timeout: int = 20,
    max_pages: int = 5,
) -> dict:
    """Hourly timeline paginated forward to cover `hours` ahead.

    Each page returns ~20 records, so ~3 pages reach 48h. Returns a single merged
    payload shaped like one timeline response (`{..., "data": [...]}`), trimmed to
    the horizon and de-duplicated by timestamp.
    """
    meta: dict = {}
    records: list[dict] = []
    horizon_end: int | None = None
    start: int | None = None

    for _ in range(max_pages):
        params = {"lat": lat, "lon": lon}
        if start is not None:
            params["start"] = start
        page = _get(f"{BASE_URL}/timeline/1h", params, api_key, timeout)
        page_records = page.get("data", [])
        if not page_records:
            break
        if not meta:
            meta = {
                k: page[k]
                for k in ("lat", "lon", "timezone", "timezone_offset")
                if k in page
            }
            horizon_end = page_records[0]["dt"] + hours * _HOUR
        records.extend(page_records)
        if page_records[-1]["dt"] >= horizon_end:
            break
        start = page_records[-1]["dt"] + _HOUR

    # De-dup by timestamp (guard against overlapping pages) and trim to horizon.
    seen: set[int] = set()
    trimmed: list[dict] = []
    for record in records:
        dt = record["dt"]
        if dt in seen or (horizon_end is not None and dt >= horizon_end):
            continue
        seen.add(dt)
        trimmed.append(record)
    return {**meta, "data": trimmed}


def _get(url: str, params: dict, api_key: str, timeout: int) -> dict:
    response = requests.get(url, params={**params, "appid": api_key}, timeout=timeout)
    if response.status_code != 200:
        # Never echo the query string — it carries the key.
        raise OpenWeatherError(
            f"{url} returned HTTP {response.status_code}: {_safe_message(response)}"
        )
    payload = response.json()
    # These URLs contain the API key — drop them before they can be used or logged.
    payload.pop("prev", None)
    payload.pop("next", None)
    return payload


def _safe_message(response: requests.Response) -> str:
    """OpenWeather's error body carries a `message` (and no key)."""
    try:
        return response.json().get("message", "")
    except ValueError:
        return ""
