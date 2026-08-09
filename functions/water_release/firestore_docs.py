"""Shape water-release status into the Firestore document.

Pure (no Firestore/network dependency) so it stays unit-testable; the actual
write lives in function.py. Unlike tide/weather's per-local-day documents,
there's no natural "forecast day" here — PDF 01 is a single blanket ~5-day
judgement, and the flow PDFs already carry their own 30-day trailing window on
every fetch — so this is one evolving document, overwritten on every run
rather than accreted into a growing history.
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
