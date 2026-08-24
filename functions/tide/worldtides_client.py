from __future__ import annotations

import requests

BASE_URL = "https://www.worldtides.info/api/v3"


class WorldTidesError(RuntimeError):
    """Raised when WorldTides returns an error or an unexpected payload."""


def fetch_extremes(
    lat: float,
    lon: float,
    days: int,
    api_key: str,
    *,
    datum: str | None = None,
    station_distance_km: int | None = None,
    timeout: int = 20,
) -> dict:
    """Fetch high/low tide extremes for `days` days from `lat`/`lon`.

    `datum` picks the vertical reference (e.g. "CD" for chart datum, so heights
    are tide-table-style positives; default MSL gives values around zero).
    `station_distance_km` sets the search radius for a named tide station — set
    it so WorldTides snaps to Tarbert rather than a global model grid point.

    Returns the raw decoded JSON payload (includes `extremes`, `station`,
    `responseLat`/`responseLon`, `responseDatum`). Credits: 1 per 7 days.
    """
    params = {
        "extremes": "",  # flag parameter — value ignored
        "lat": lat,
        "lon": lon,
        "days": days,
        "key": api_key,
    }
    if datum is not None:
        params["datum"] = datum
    if station_distance_km is not None:
        params["stationDistance"] = station_distance_km
    return _get(params)


def find_stations(
    lat: float,
    lon: float,
    api_key: str,
    *,
    station_distance_km: int = 100,
    timeout: int = 20,
) -> list[dict]:
    """List named tide stations near `lat`/`lon` (id, name, lat, lon, timezone)."""
    payload = _get(
        {
            "stations": "",
            "lat": lat,
            "lon": lon,
            "stationDistance": station_distance_km,
            "key": api_key,
        },
        timeout=timeout,
    )
    return payload.get("stations", [])


def _get(params: dict, *, timeout: int = 20) -> dict:
    response = requests.get(BASE_URL, params=params, timeout=timeout)
    response.raise_for_status()
    payload = response.json()
    # WorldTides echoes an HTTP-style status in the body and an `error` string
    # on failure (e.g. bad key, no station in range).
    if payload.get("status") != 200:
        raise WorldTidesError(
            payload.get("error", f"WorldTides returned status {payload.get('status')}")
        )
    return payload
