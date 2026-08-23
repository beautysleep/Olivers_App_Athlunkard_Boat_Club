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
    DISCHARGE_EXPECTED,
    NO_DISCHARGE_EXPECTED,
    UNPARSED,
    FlowReading,
    FlowSeries,
    ParteenForecast,
)

# ESB has published this in two orderings — "no additional discharge WILL BE
# necessary" (2024 onwards) and "there will be no additional discharge
# necessary" (2017-2023) — which mean the same thing. Matched against
# whitespace-normalized text so line-wrap differences in the PDF layout don't
# break it. See tests/fixtures/README.md for the captured samples.
_NO_DISCHARGE_PATTERN = re.compile(
    r"no additional discharge (?:will be )?necessary", re.IGNORECASE
)

_STATEMENT_PATTERN = re.compile(
    r"Discharge at Parteen Weir:\s*(.+?forecast)", re.IGNORECASE
)

# Classification runs on ESB's forward-looking clause only, not the whole
# section. A real 2017 forecast opens with a *past* fact ("Additional discharge
# of 50m3/s at Parteen Weir ceased as of this morning.") before stating the
# expectation, and only the expectation drives the row/no-row decision.
_EXPECTATION_PATTERN = re.compile(
    r"It is expected that (.+?) based on current weather forecast", re.IGNORECASE
)

# Observed discharging phrasings: "a discharge of between 55m3/s and 95 m3/s",
# "a discharge ranging between 55 and 170m3/s", "a discharge of between 95 and
# 55m3/s". The m3/s unit attaches to either number, both, or neither, and the
# range is sometimes descending (a falling discharge over the period).
_DISCHARGE_RANGE_PATTERN = re.compile(
    r"a discharge (?:of|ranging) between\s*"
    r"([\d.]+)\s*(?:m3/s)?\s*and\s*([\d.]+)\s*(?:m3/s)?",
    re.IGNORECASE,
)

_PLANNING_ASSUMPTION_PATTERN = re.compile(
    r"Total combined Parteen Discharge ranging between "
    r"([\d.]+)\s*m3/s and ([\d.]+)\s*m3/s",
    re.IGNORECASE,
)

# ESB writes this with a leading weekday ("Friday 16 January 2026", 2026
# onwards) or without ("27 October 2020", 2017-2024). The weekday is redundant
# with the date itself, so it is matched and discarded.
_DATE_OF_PREDICTION_PATTERN = re.compile(
    r"Date of Prediction:\s*(?:[A-Za-z]+\s+)?(\d{1,2}\s+[A-Za-z]+\s+\d{4})"
)

_TIMESTAMP_FORMAT = "%d-%b-%y %H:%M:%S"


def parse_forecast(raw_text: str, *, source_url: str) -> ParteenForecast:
    """Parse 01-Shannon-Hydro-Forecast.pdf's extracted text.

    Classification comes from ESB's forward-looking expectation clause, in the
    phrasings captured in tests/fixtures/README.md. Wording matching none of
    them is UNPARSED rather than guessed as safe or unsafe.
    """
    normalized = " ".join(raw_text.split())

    statement_match = _STATEMENT_PATTERN.search(normalized)
    statement_raw = statement_match.group(1).strip() if statement_match else ""
    expectation_match = _EXPECTATION_PATTERN.search(statement_raw)
    expectation = expectation_match.group(1) if expectation_match else ""
    discharge_range = _DISCHARGE_RANGE_PATTERN.search(expectation)
    discharge_min, discharge_max = _range_bounds(discharge_range)

    assumption_match = _PLANNING_ASSUMPTION_PATTERN.search(normalized)
    assumption_raw = assumption_match.group(0) if assumption_match else None
    assumption_min = float(assumption_match.group(1)) if assumption_match else None
    assumption_max = float(assumption_match.group(2)) if assumption_match else None

    date_match = _DATE_OF_PREDICTION_PATTERN.search(normalized)
    date_of_prediction = (
        datetime.strptime(date_match.group(1), "%d %B %Y").date()
        if date_match
        else None
    )

    return ParteenForecast(
        discharge_statement_raw=statement_raw,
        discharge_classification=_classify(expectation, discharge_range),
        date_of_prediction=date_of_prediction,
        expected_discharge_min_m3s=discharge_min,
        expected_discharge_max_m3s=discharge_max,
        planning_assumption_raw=assumption_raw,
        planning_assumption_min_m3s=assumption_min,
        planning_assumption_max_m3s=assumption_max,
        source_url=source_url,
    )


def _classify(expectation: str, discharge_range: re.Match | None) -> str:
    if _NO_DISCHARGE_PATTERN.search(expectation):
        return NO_DISCHARGE_EXPECTED
    if discharge_range is not None:
        return DISCHARGE_EXPECTED
    return UNPARSED


def _range_bounds(match: re.Match | None) -> tuple[float | None, float | None]:
    if match is None:
        return None, None
    first, second = float(match.group(1)), float(match.group(2))
    return min(first, second), max(first, second)


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
