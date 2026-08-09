"""Offline tests for extracting text/tables from the real ESB PDFs.

Runs pdfplumber against the actual PDF bytes fetched from esbhydro.ie on
2026-08-09 (fixtures/*.pdf) — no network call, no invented content. This is the
one place in the service that exercises pdfplumber directly; parse.py's own
tests run against the extracted output instead, with no pdfplumber dependency.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from esbhydro_client import _extract_flow_table, _extract_forecast_text  # noqa: E402

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _pdf_bytes(name):
    with open(os.path.join(FIXTURES, name), "rb") as f:
        return f.read()


class ExtractForecastTextTests(unittest.TestCase):
    def test_extracts_the_discharge_sentence(self):
        text = _extract_forecast_text(_pdf_bytes("01-Shannon-Hydro-Forecast.pdf"))
        self.assertIn("Discharge at Parteen Weir", text)
        self.assertIn("no additional discharge will be necessary", text)

    def test_extracts_all_five_pages(self):
        text = _extract_forecast_text(_pdf_bytes("01-Shannon-Hydro-Forecast.pdf"))
        # Each of the three lough sections repeats "Date of Prediction".
        self.assertEqual(text.count("Date of Prediction"), 3)


class ExtractFlowTableTests(unittest.TestCase):
    def test_ardnacrusha_current_and_thirty_readings(self):
        raw = _extract_flow_table(_pdf_bytes("07-Total-Ardnacrusha-Flow.pdf"))
        self.assertEqual(raw["current"]["value"], "36")
        self.assertEqual(raw["current"]["units"], "cubic metres per second")
        self.assertEqual(len(raw["readings"]), 30)
        self.assertEqual(raw["readings"][0]["timestamp"], "09-Aug-26 09:00:00")

    def test_parteen_weir_current_and_thirty_readings(self):
        raw = _extract_flow_table(_pdf_bytes("08-Total-Parteen-Weir-Flow.pdf"))
        self.assertEqual(raw["current"]["value"], "47")
        self.assertEqual(len(raw["readings"]), 30)

    def test_no_spurious_empty_rows_from_the_chart_grid(self):
        # pdfplumber detects a bogus all-empty "table" from the chart's axis
        # lines on page 0 of both flow PDFs — must be filtered out, not
        # returned as junk readings.
        raw = _extract_flow_table(_pdf_bytes("07-Total-Ardnacrusha-Flow.pdf"))
        for row in raw["readings"]:
            self.assertTrue(all(row.values()))


if __name__ == "__main__":
    unittest.main()
