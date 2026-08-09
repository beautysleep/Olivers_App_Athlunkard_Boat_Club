"""Offline tests for building the water_release_status/current Firestore
document. No network, no Firestore, no key."""

import os
import sys
import unittest
from datetime import date, datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from firestore_docs import build_document  # noqa: E402
from models import (  # noqa: E402
    NO_DISCHARGE_EXPECTED,
    UNPARSED,
    FlowReading,
    FlowSeries,
    ParteenForecast,
)


def _forecast(
    classification=NO_DISCHARGE_EXPECTED, date_of_prediction=date(2026, 8, 7)
):
    return ParteenForecast(
        discharge_statement_raw="It is expected that no additional discharge "
        "will be necessary at Parteen Weir over the next 5 days based on "
        "current weather forecast",
        discharge_classification=classification,
        date_of_prediction=date_of_prediction,
        planning_assumption_raw="Total combined Parteen Discharge ranging "
        "between 10.5 m3/s and 30 m3/s throughout forecast period.",
        planning_assumption_min_m3s=10.5,
        planning_assumption_max_m3s=30.0,
        source_url="http://www.esbhydro.ie/Shannon/01-Shannon-Hydro-Forecast.pdf",
    )


def _flow_series(label, current):
    return FlowSeries(
        label=label,
        current_value_m3s=current,
        current_reading_at=datetime(2026, 8, 9, 8, 0, tzinfo=timezone.utc),
        units="cubic metres per second",
        readings=[
            FlowReading(datetime(2026, 8, 9, 8, 0, tzinfo=timezone.utc), current)
        ],
        source_url="http://www.esbhydro.ie/Shannon/x.pdf",
    )


class BuildDocumentTests(unittest.TestCase):
    def test_assembles_the_three_sections_with_envelope_fields(self):
        fetched = datetime(2026, 8, 9, 10, 0, tzinfo=timezone.utc)
        doc = build_document(
            _forecast(),
            _flow_series("Total Average Daily Ardnacrusha Flow", 36.0),
            _flow_series("Total Combined Parteen Weir Flow", 47.0),
            fetched_at=fetched,
        )

        self.assertEqual(doc["source"], "esbhydro")
        self.assertEqual(doc["fetched_at"], fetched)

        self.assertEqual(
            doc["parteen_forecast"]["discharge_classification"], NO_DISCHARGE_EXPECTED
        )
        self.assertEqual(doc["parteen_forecast"]["date_of_prediction"], "2026-08-07")

        self.assertEqual(doc["ardnacrusha_flow"]["current_value_m3s"], 36.0)
        self.assertEqual(doc["parteen_weir_flow"]["current_value_m3s"], 47.0)
        self.assertEqual(
            doc["ardnacrusha_flow"]["label"], "Total Average Daily Ardnacrusha Flow"
        )

    def test_unparsed_classification_and_missing_assumption_pass_through_as_null(self):
        forecast = ParteenForecast(
            discharge_statement_raw="unrecognised wording",
            discharge_classification=UNPARSED,
            date_of_prediction=None,
            planning_assumption_raw=None,
            planning_assumption_min_m3s=None,
            planning_assumption_max_m3s=None,
            source_url="http://www.esbhydro.ie/Shannon/01-Shannon-Hydro-Forecast.pdf",
        )
        doc = build_document(
            forecast,
            _flow_series("a", 0.0),
            _flow_series("b", 0.0),
            fetched_at=datetime(2026, 8, 9, 10, 0, tzinfo=timezone.utc),
        )
        self.assertEqual(doc["parteen_forecast"]["discharge_classification"], UNPARSED)
        self.assertIsNone(doc["parteen_forecast"]["date_of_prediction"])
        self.assertIsNone(doc["parteen_forecast"]["planning_assumption_raw"])


if __name__ == "__main__":
    unittest.main()
