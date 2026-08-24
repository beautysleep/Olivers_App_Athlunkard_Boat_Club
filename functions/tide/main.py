"""Run:
    export WORLDTIDES_API_KEY=...       # never commit this
    python functions/tide/main.py 7     # 7 days of extremes
"""

from __future__ import annotations

import json
import os
import sys

from calibration import apply_limerick_calibration, parse_extremes
from worldtides_client import fetch_extremes

# Athlunkard Boat Club / Limerick Dock, at the tidal limit above Limerick city.
# WorldTides resolves this to the nearest station (~Tarbert); we then calibrate.
CLUB_LAT = 52.6667
CLUB_LON = -8.6333

# Chart datum so heights are tide-table-style positives (matches the coach's
# height reference), and a search radius so WorldTides uses the nearest named
# station (Tarbert) rather than a global model grid point.
DATUM = "CD"
STATION_DISTANCE_KM = 50


def fetch_limerick_tides(
    days: int = 7,
    api_key: str | None = None,
    lat: float = CLUB_LAT,
    lon: float = CLUB_LON,
    datum: str = DATUM,
    station_distance_km: int = STATION_DISTANCE_KM,
) -> dict:
    """Fetch, parse, and calibrate tide extremes for Limerick Dock."""
    api_key = api_key or os.environ.get("WORLDTIDES_API_KEY")
    if not api_key:
        raise SystemExit("Set WORLDTIDES_API_KEY (or pass api_key=).")

    payload = fetch_extremes(
        lat,
        lon,
        days,
        api_key,
        datum=datum,
        station_distance_km=station_distance_km,
    )
    raw = parse_extremes(payload)
    calibrated = apply_limerick_calibration(raw)

    return {
        "requested": {"lat": lat, "lon": lon, "days": days},
        "station": payload.get("station"),
        "response_point": {
            "lat": payload.get("responseLat"),
            "lon": payload.get("responseLon"),
        },
        "datum": payload.get("responseDatum"),
        "tarbert_raw": [e.to_dict() for e in raw],
        "limerick_calibrated": [e.to_dict() for e in calibrated],
    }


def main(argv: list[str]) -> int:
    days = int(argv[1]) if len(argv) > 1 else 7
    result = fetch_limerick_tides(days=days)
    print(json.dumps(result, indent=2))

    # Sanity summary on stderr, in LOCAL (Europe/Dublin) time so it matches
    # real-world tide tables — UTC would read an hour early in summer.
    cal = result["limerick_calibrated"]
    print(
        f"\nResolved station: {result['station']} at {result['response_point']} "
        f"(datum {result['datum']}). {len(cal)} extremes over {days} day(s) "
        f"— Limerick Dock, local time:",
        file=sys.stderr,
    )
    for e in cal:
        # time_local is ISO "…THH:MM…+01:00"; show the day, HH:MM and offset.
        iso = e["time_local"]
        print(
            f"  {e['kind']:<4} {iso[0:10]} {iso[11:16]} {iso[19:]}  "
            f"{e['height_m']:>5.2f} m",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
