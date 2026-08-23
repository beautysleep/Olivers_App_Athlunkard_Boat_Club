"""Offline tests for water-release domain types. No network, no key."""

import os
import sys
import unittest
from datetime import date, datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from models import (  # noqa: E402
    NO_DISCHARGE_EXPECTED,
    UNPARSED,
    FlowReading,
    FlowSeries,
    ParteenForecast,
)


class FlowReadingTests(unittest.TestCase):
    def test_to_dict_rounds_value(self):
        r = FlowReading(
            reading_at=datetime(2026, 8, 9, 9, 0, tzinfo=timezone.utc),
            value_m3s=36.049,
        )
        d = r.to_dict()
        self.assertEqual(d["reading_at"], r.reading_at)
        self.assertEqual(d["value_m3s"], 36.0)


class FlowSeriesTests(unittest.TestCase):
    def test_to_dict_carries_current_and_readings(self):
        readings = [
            FlowReading(datetime(2026, 8, 9, 9, 0, tzinfo=timezone.utc), 36.0),
            FlowReading(datetime(2026, 8, 8, 9, 0, tzinfo=timezone.utc), 37.0),
        ]
        series = FlowSeries(
            label="Total Average Daily Ardnacrusha Flow",
            current_value_m3s=36.0,
            current_reading_at=datetime(2026, 8, 9, 9, 0, tzinfo=timezone.utc),
            units="cubic metres per second",
            readings=readings,
            source_url="http://www.esbhydro.ie/Shannon/07-Total-Ardnacrusha-Flow.pdf",
        )
        d = series.to_dict()
        self.assertEqual(d["label"], "Total Average Daily Ardnacrusha Flow")
        self.assertEqual(d["current_value_m3s"], 36.0)
        self.assertEqual(d["units"], "cubic metres per second")
        self.assertEqual(len(d["readings"]), 2)
        self.assertEqual(d["readings"][0]["value_m3s"], 36.0)


class ParteenForecastTests(unittest.TestCase):
    def test_to_dict_serialises_date_of_prediction_as_iso_string(self):
        f = ParteenForecast(
            discharge_statement_raw="It is expected that no additional discharge "
            "will be necessary at Parteen Weir over the next 5 days based on "
            "current weather forecast",
            discharge_classification=NO_DISCHARGE_EXPECTED,
            date_of_prediction=date(2026, 8, 7),
            expected_discharge_min_m3s=None,
            expected_discharge_max_m3s=None,
            planning_assumption_raw="Total combined Parteen Discharge ranging "
            "between 10.5 m3/s and 30 m3/s throughout forecast period.",
            planning_assumption_min_m3s=10.5,
            planning_assumption_max_m3s=30.0,
            source_url="http://www.esbhydro.ie/Shannon/01-Shannon-Hydro-Forecast.pdf",
        )
        d = f.to_dict()
        self.assertEqual(d["date_of_prediction"], "2026-08-07")
        self.assertEqual(d["discharge_classification"], NO_DISCHARGE_EXPECTED)
        self.assertEqual(d["planning_assumption_min_m3s"], 10.5)
        self.assertEqual(d["planning_assumption_max_m3s"], 30.0)

    def test_to_dict_handles_missing_date_and_assumption(self):
        f = ParteenForecast(
            discharge_statement_raw="some unrecognised wording",
            discharge_classification=UNPARSED,
            date_of_prediction=None,
            expected_discharge_min_m3s=None,
            expected_discharge_max_m3s=None,
            planning_assumption_raw=None,
            planning_assumption_min_m3s=None,
            planning_assumption_max_m3s=None,
            source_url="http://www.esbhydro.ie/Shannon/01-Shannon-Hydro-Forecast.pdf",
        )
        d = f.to_dict()
        self.assertIsNone(d["date_of_prediction"])
        self.assertEqual(d["discharge_classification"], UNPARSED)
        self.assertIsNone(d["planning_assumption_raw"])


if __name__ == "__main__":
    unittest.main()
