"""One evolving document, overwritten on every run rather than accreted into a
history. Unlike tide and weather there is no natural "forecast day": PDF 01 is a
single blanket ~5-day judgement, and the flow PDFs carry their own 30-day
trailing window on every fetch.
"""

from __future__ import annotations

from datetime import datetime

from models import FlowSeries, ParteenForecast


def build_document(
    forecast: ParteenForecast,
    ardnacrusha_flow: FlowSeries,
    parteen_weir_flow: FlowSeries,
    *,
    fetched_at: datetime,
    source: str = "esbhydro",
) -> dict:
    """Build the single water_release_status/current Firestore document."""
    return {
        "source": source,
        "fetched_at": fetched_at,
        "parteen_forecast": forecast.to_dict(),
        "ardnacrusha_flow": ardnacrusha_flow.to_dict(),
        "parteen_weir_flow": parteen_weir_flow.to_dict(),
    }
