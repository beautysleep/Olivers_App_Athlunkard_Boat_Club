"""Parse ESB hydrometric PDF text/tables into water-release domain types.

Pure (no HTTP/PDF-library dependency): esbhydro_client.py hands us the
already-extracted plain text (from the prose forecast PDF) or row dicts (from
the flow-table PDFs), so this is unit-tested against captured real extracted
content without a network call or pdfplumber. Mirrors the weather service's
parse.py.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

from models import (
    CLUB_TZ,
    NO_DISCHARGE_EXPECTED,
    UNPARSED,
    FlowReading,
    FlowSeries,
    ParteenForecast,
)

# The only Parteen Weir discharge-statement phrasing ever observed (see
# models.py). Matched against whitespace-normalized text so line-wrap
# differences in the PDF layout don't break it.
_NO_DISCHARGE_PATTERN = re.compile(
    r"no additional discharge will be necessary at Parteen Weir", re.IGNORECASE
)

_STATEMENT_PATTERN = re.compile(
    r"Discharge at Parteen Weir:\s*(.+?forecast)", re.IGNORECASE
)

_PLANNING_ASSUMPTION_PATTERN = re.compile(
    r"Total combined Parteen Discharge ranging between "
    r"([\d.]+)\s*m3/s and ([\d.]+)\s*m3/s",
    re.IGNORECASE,
)

_DATE_OF_PREDICTION_PATTERN = re.compile(
    r"Date of Prediction:\s*([A-Za-z]+ \d{1,2} [A-Za-z]+ \d{4})"
)

_TIMESTAMP_FORMAT = "%d-%b-%y %H:%M:%S"


def parse_forecast(raw_text: str, *, source_url: str) -> ParteenForecast:
    """Parse 01-Shannon-Hydro-Forecast.pdf's extracted text.

    Only the one discharge-statement phrasing ESB has ever been observed to
    publish is classified as NO_DISCHARGE_EXPECTED; anything else — including a
    real "discharging" statement, which has never been captured — is UNPARSED
    rather than guessed.
    """
    normalized = " ".join(raw_text.split())

    statement_match = _STATEMENT_PATTERN.search(normalized)
    statement_raw = statement_match.group(1).strip() if statement_match else ""
    classification = (
        NO_DISCHARGE_EXPECTED
        if statement_raw and _NO_DISCHARGE_PATTERN.search(statement_raw)
        else UNPARSED
    )

    assumption_match = _PLANNING_ASSUMPTION_PATTERN.search(normalized)
    assumption_raw = assumption_match.group(0) if assumption_match else None
    assumption_min = float(assumption_match.group(1)) if assumption_match else None
    assumption_max = float(assumption_match.group(2)) if assumption_match else None

    date_match = _DATE_OF_PREDICTION_PATTERN.search(normalized)
    date_of_prediction = (
        datetime.strptime(date_match.group(1), "%A %d %B %Y").date()
        if date_match
        else None
    )

    return ParteenForecast(
        discharge_statement_raw=statement_raw,
        discharge_classification=classification,
        date_of_prediction=date_of_prediction,
        planning_assumption_raw=assumption_raw,
        planning_assumption_min_m3s=assumption_min,
        planning_assumption_max_m3s=assumption_max,
        source_url=source_url,
    )


def parse_flow_table(raw: dict, *, label: str, source_url: str) -> FlowSeries:
    """Parse the {"current": {...}, "readings": [...]} dict esbhydro_client
    extracts from a flow-table PDF (07 or 08) into a FlowSeries."""
    current = raw["current"]
    return FlowSeries(
        label=label,
        current_value_m3s=float(current["value"]),
        current_reading_at=_parse_timestamp(current["timestamp"]),
        units=current["units"],
        readings=[_reading(row) for row in raw["readings"]],
        source_url=source_url,
    )


def _reading(row: dict) -> FlowReading:
    return FlowReading(
        reading_at=_parse_timestamp(row["timestamp"]),
        value_m3s=float(row["value"]),
    )


def _parse_timestamp(text: str) -> datetime:
    """ESB flow-table timestamps are "DD-Mon-YY HH:MM:SS", assumed Europe/Dublin
    local (unconfirmed with ESB) — converted to a UTC instant."""
    local = datetime.strptime(text, _TIMESTAMP_FORMAT).replace(tzinfo=CLUB_TZ)
    return local.astimezone(timezone.utc)
