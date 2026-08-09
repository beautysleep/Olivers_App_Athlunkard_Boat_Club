"""Thin HTTP + PDF-extraction client for ESB's Shannon hydrometric PDFs.

Isolated from parsing so the rest of the service stays testable without the
network (parse.py works on the plain text/row dicts this module produces).
Mirrors the weather service's openweather_client.py: this is the one file that
owns turning the wire format (PDF bytes) into usable Python data.

No API key — ESB publishes these as public PDFs. Plain HTTP only: esbhydro.ie
has no HTTPS listener on port 443 (confirmed by a direct connection test), so
this deliberately does not upgrade to https://.
"""

from __future__ import annotations

import io

import pdfplumber
import requests

BASE_URL = "http://www.esbhydro.ie/Shannon"
FORECAST_URL = f"{BASE_URL}/01-Shannon-Hydro-Forecast.pdf"
ARDNACRUSHA_FLOW_URL = f"{BASE_URL}/07-Total-Ardnacrusha-Flow.pdf"
PARTEEN_WEIR_FLOW_URL = f"{BASE_URL}/08-Total-Parteen-Weir-Flow.pdf"


class EsbHydroError(RuntimeError):
    """Raised when ESB's site returns a non-200 for one of the PDFs."""


def fetch_forecast_text(url: str = FORECAST_URL, *, timeout: int = 20) -> str:
    """Download 01-Shannon-Hydro-Forecast.pdf and return its full extracted
    text (all pages joined), for parse.parse_forecast() to search."""
    return _extract_forecast_text(_download(url, timeout=timeout))


def fetch_flow_table(url: str, *, timeout: int = 20) -> dict:
    """Download a flow PDF (07 or 08 — same two-page layout) and return its
    current reading + 30-day history as plain row dicts, for
    parse.parse_flow_table() to convert."""
    return _extract_flow_table(_download(url, timeout=timeout))


def _download(url: str, *, timeout: int) -> bytes:
    response = requests.get(url, timeout=timeout)
    if response.status_code != 200:
        raise EsbHydroError(f"{url} returned HTTP {response.status_code}")
    return response.content


def _extract_forecast_text(pdf_bytes: bytes) -> str:
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        return "\n".join(page.extract_text() or "" for page in pdf.pages)


def _extract_flow_table(pdf_bytes: bytes) -> dict:
    """Page 0 carries a single-row "current reading" table; page 1 carries the
    30-day history under a merged title row + header row. Both pages also
    contain a spurious all-empty table pdfplumber detects from the chart's
    axis gridlines — filtered out by _has_data (observed on every flow PDF
    fetched so far, not assumed)."""
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        page0_tables = [t for t in pdf.pages[0].extract_tables() if _has_data(t)]
        page1_tables = [t for t in pdf.pages[1].extract_tables() if _has_data(t)]

    current_row = page0_tables[0][0]
    history_rows = page1_tables[0][2:]  # skip the merged title row + header row
    return {
        "current": _row_dict(current_row),
        "readings": [_row_dict(row) for row in history_rows],
    }


def _row_dict(row: list) -> dict:
    return {"timestamp": row[0], "value": row[1], "units": row[2]}


def _has_data(table: list) -> bool:
    return any(any(cell not in (None, "") for cell in row) for row in table)
