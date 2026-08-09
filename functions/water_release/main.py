"""Fetch Athlunkard water-release status from ESB's Shannon hydrometric PDFs.

Reusable entrypoint (`fetch_water_release_status`) plus a small CLI so we can
prove the source before wiring it into Cloud Functions / Firestore.

No API key needed — ESB publishes these as public PDFs over plain HTTP (no
HTTPS listener on esbhydro.ie, confirmed).

Run:
    python functions/water_release/main.py
"""

from __future__ import annotations

import sys

from esbhydro_client import (
    ARDNACRUSHA_FLOW_URL,
    FORECAST_URL,
    PARTEEN_WEIR_FLOW_URL,
    fetch_flow_table,
    fetch_forecast_text,
)
from models import FlowSeries, ParteenForecast
from parse import parse_flow_table, parse_forecast


def fetch_water_release_status() -> tuple[ParteenForecast, FlowSeries, FlowSeries]:
    """Fetch and parse all three ESB sources. Returns
    (parteen_forecast, ardnacrusha_flow, parteen_weir_flow)."""
    forecast = parse_forecast(
        fetch_forecast_text(FORECAST_URL), source_url=FORECAST_URL
    )
    ardnacrusha = parse_flow_table(
        fetch_flow_table(ARDNACRUSHA_FLOW_URL),
        label="Total Average Daily Ardnacrusha Flow",
        source_url=ARDNACRUSHA_FLOW_URL,
    )
    parteen_weir = parse_flow_table(
        fetch_flow_table(PARTEEN_WEIR_FLOW_URL),
        label="Total Combined Parteen Weir Flow",
        source_url=PARTEEN_WEIR_FLOW_URL,
    )
    return forecast, ardnacrusha, parteen_weir


def main(argv: list[str]) -> int:
    forecast, ardnacrusha, parteen_weir = fetch_water_release_status()

    print(f"Parteen Weir discharge forecast: {forecast.discharge_classification}")
    print(f'  "{forecast.discharge_statement_raw}"')
    if forecast.date_of_prediction:
        print(f"  (date of prediction: {forecast.date_of_prediction.isoformat()})")
    if forecast.planning_assumption_raw:
        print(
            f"  planning assumption: {forecast.planning_assumption_min_m3s}"
            f"-{forecast.planning_assumption_max_m3s} m3/s"
        )
    print(
        f"Ardnacrusha flow: {ardnacrusha.current_value_m3s} m3/s "
        f"at {ardnacrusha.current_reading_at.isoformat()}"
    )
    print(
        f"Parteen Weir flow: {parteen_weir.current_value_m3s} m3/s "
        f"at {parteen_weir.current_reading_at.isoformat()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
