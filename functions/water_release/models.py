"""Domain types for the water-release (Parteen Weir / Ardnacrusha) service.

Kept free of any HTTP/PDF-parsing dependency so document-building is
unit-tested without a network call. Mirrors the weather service's models.py.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from zoneinfo import ZoneInfo

# The club's local timezone. The ESB flow-table "09:00:00" reading times are
# assumed to be expressed in this zone — unconfirmed with ESB (see README).
CLUB_TZ = ZoneInfo("Europe/Dublin")

# The only Parteen Weir discharge-statement phrasing ever observed in a real
# ESB forecast (fetched 2026-08-09): "no additional discharge will be
# necessary". There is no captured example of the "IS discharging" wording, so
# no state is invented for it — anything that doesn't match the observed
# pattern is classified UNPARSED rather than guessed as safe or unsafe.
NO_DISCHARGE_EXPECTED = "no_discharge_expected"
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
    discharge_classification: str  # NO_DISCHARGE_EXPECTED | UNPARSED
    date_of_prediction: date | None  # the PDF's own forecast-issue date
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
            "planning_assumption_raw": self.planning_assumption_raw,
            "planning_assumption_min_m3s": self.planning_assumption_min_m3s,
            "planning_assumption_max_m3s": self.planning_assumption_max_m3s,
            "source_url": self.source_url,
        }
