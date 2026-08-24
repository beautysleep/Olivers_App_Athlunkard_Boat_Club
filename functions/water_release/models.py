from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from zoneinfo import ZoneInfo

# The club's local timezone. The ESB flow-table "09:00:00" reading times are
# assumed to be expressed in this zone — unconfirmed with ESB (see README).
CLUB_TZ = ZoneInfo("Europe/Dublin")

# How the Parteen Weir discharge statement in 01-Shannon-Hydro-Forecast.pdf is
# classified. Every phrasing recognised here was captured from a real ESB
# forecast — see tests/fixtures/README.md for the samples and where they came
# from. Anything that matches none of them is UNPARSED rather than guessed as
# safe or unsafe: a wording ESB has never been observed to use must never be
# read as "clear".
NO_DISCHARGE_EXPECTED = "no_discharge_expected"
DISCHARGE_EXPECTED = "discharge_expected"
UNPARSED = "unparsed"


@dataclass(frozen=True)
class FlowReading:
    """One daily flow reading from an ESB flow PDF's "last 30 readings" table."""

    reading_at: datetime  # timezone-aware, UTC
    value_m3s: float

    def to_dict(self) -> dict:
        return {"reading_at": self.reading_at, "value_m3s": round(self.value_m3s, 1)}


@dataclass(frozen=True)
class FlowSeries:
    """A flow time series as published on one ESB flow PDF (Ardnacrusha total
    or Parteen Weir total): today's headline reading plus the trailing 30-day
    history the PDF carries on its second page."""

    label: str
    current_value_m3s: float
    current_reading_at: datetime  # timezone-aware, UTC
    units: str
    readings: list[FlowReading]
    source_url: str

    def to_dict(self) -> dict:
        return {
            "label": self.label,
            "current_value_m3s": round(self.current_value_m3s, 1),
            "current_reading_at": self.current_reading_at,
            "units": self.units,
            "readings": [r.to_dict() for r in self.readings],
            "source_url": self.source_url,
        }


@dataclass(frozen=True)
class ParteenForecast:
    """The prose ~5-day forecast for discharge at Parteen Weir, from
    01-Shannon-Hydro-Forecast.pdf."""

    discharge_statement_raw: str  # verbatim sentence, always stored
    # NO_DISCHARGE_EXPECTED | DISCHARGE_EXPECTED | UNPARSED
    discharge_classification: str
    date_of_prediction: date | None  # the PDF's own forecast-issue date
    # The discharge range ESB expects, when discharging. Ordered so min is the
    # smaller even where ESB writes the range descending; the direction stays
    # readable in discharge_statement_raw. None unless DISCHARGE_EXPECTED.
    expected_discharge_min_m3s: float | None
    expected_discharge_max_m3s: float | None
    planning_assumption_raw: str | None
    planning_assumption_min_m3s: float | None
    planning_assumption_max_m3s: float | None
    source_url: str

    def to_dict(self) -> dict:
        return {
            "date_of_prediction": (
                None
                if self.date_of_prediction is None
                else self.date_of_prediction.isoformat()
            ),
            "discharge_statement_raw": self.discharge_statement_raw,
            "discharge_classification": self.discharge_classification,
            "expected_discharge_min_m3s": self.expected_discharge_min_m3s,
            "expected_discharge_max_m3s": self.expected_discharge_max_m3s,
            "planning_assumption_raw": self.planning_assumption_raw,
            "planning_assumption_min_m3s": self.planning_assumption_min_m3s,
            "planning_assumption_max_m3s": self.planning_assumption_max_m3s,
            "source_url": self.source_url,
        }
