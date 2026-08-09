"""Offline tests for parsing ESB hydrometric PDF text/tables.

Runs against CAPTURED REAL extracted content under fixtures/ (generated once
from the real PDFs fetched 2026-08-09 — see esbhydro_client.py for the
extraction step these fixtures stand in for), so the assertions pin the parser
to text ESB actually published, not hand-invented wording. No pdfplumber
dependency here — that lives only in esbhydro_client.py / its own tests.
"""

import json
import os
import sys
import unittest
from datetime import date

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from models import NO_DISCHARGE_EXPECTED, UNPARSED  # noqa: E402
from parse import parse_flow_table, parse_forecast  # noqa: E402

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _load_text(name):
    with open(os.path.join(FIXTURES, name)) as f:
        return f.read()


def _load_json(name):
    with open(os.path.join(FIXTURES, name)) as f:
        return json.load(f)


class ParseForecastTests(unittest.TestCase):
    def setUp(self):
        self.text = _load_text("shannon_hydro_forecast.txt")
        self.forecast = parse_forecast(
            self.text, source_url="http://example/01-Shannon-Hydro-Forecast.pdf"
        )

    def test_classifies_the_observed_no_discharge_phrasing(self):
        self.assertEqual(self.forecast.discharge_classification, NO_DISCHARGE_EXPECTED)

    def test_keeps_the_raw_statement_verbatim(self):
        self.assertIn(
            "no additional discharge will be necessary",
            self.forecast.discharge_statement_raw,
        )
        self.assertIn("Parteen Weir", self.forecast.discharge_statement_raw)

    def test_extracts_date_of_prediction(self):
        self.assertEqual(self.forecast.date_of_prediction, date(2026, 8, 7))

    def test_extracts_planning_assumption_range(self):
        self.assertEqual(self.forecast.planning_assumption_min_m3s, 10.5)
        self.assertEqual(self.forecast.planning_assumption_max_m3s, 30.0)
        self.assertIsNotNone(self.forecast.planning_assumption_raw)

    def test_unrecognised_wording_is_never_guessed(self):
        forecast = parse_forecast(
            "Discharge at Parteen Weir: some future wording ESB has never used "
            "before, forecast",
            source_url="http://example/01-Shannon-Hydro-Forecast.pdf",
        )
        self.assertEqual(forecast.discharge_classification, UNPARSED)

    def test_missing_sections_leave_fields_none_not_guessed(self):
        forecast = parse_forecast(
            "This page has no discharge statement or date of prediction at all.",
            source_url="http://example/01-Shannon-Hydro-Forecast.pdf",
        )
        self.assertEqual(forecast.discharge_classification, UNPARSED)
        self.assertIsNone(forecast.date_of_prediction)
        self.assertIsNone(forecast.planning_assumption_min_m3s)


class ParseFlowTableTests(unittest.TestCase):
    def test_ardnacrusha_current_and_readings(self):
        raw = _load_json("ardnacrusha_flow_extracted.json")
        series = parse_flow_table(
            raw,
            label="Total Average Daily Ardnacrusha Flow",
            source_url="http://example/07-Total-Ardnacrusha-Flow.pdf",
        )
        self.assertEqual(series.current_value_m3s, 36.0)
        self.assertEqual(series.units, "cubic metres per second")
        self.assertEqual(len(series.readings), 30)
        self.assertEqual(series.readings[0].value_m3s, 36.0)

    def test_parteen_weir_current_and_readings(self):
        raw = _load_json("parteen_weir_flow_extracted.json")
        series = parse_flow_table(
            raw,
            label="Total Combined Parteen Weir Flow",
            source_url="http://example/08-Total-Parteen-Weir-Flow.pdf",
        )
        self.assertEqual(series.current_value_m3s, 47.0)
        self.assertEqual(len(series.readings), 30)

    def test_timestamp_is_parsed_as_utc_instant(self):
        raw = _load_json("ardnacrusha_flow_extracted.json")
        series = parse_flow_table(raw, label="x", source_url="http://example")
        # "09-Aug-26 09:00:00" local (IST, +1h in August) -> 08:00 UTC.
        self.assertEqual(series.current_reading_at.hour, 8)
        self.assertEqual(series.current_reading_at.utcoffset().total_seconds(), 0)


if __name__ == "__main__":
    unittest.main()
