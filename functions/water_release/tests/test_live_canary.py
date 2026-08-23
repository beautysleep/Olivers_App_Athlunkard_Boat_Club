"""Live contract/canary test: hits the real ESB endpoints and asserts the
response shape this service depends on still holds.

Unlike the WorldTides/OpenWeather canaries, no API key is needed for these
three public PDFs, so this gates on an explicit opt-in env var instead of key
presence — hitting a small public-sector server on every offline test run
(e.g. in CI, or on every commit) would be bad etiquette and risks the
production daily fetch getting rate-limited. Skipped by default; run with:

    RUN_LIVE_CANARY=1 python -m unittest functions.water_release.tests.test_live_canary
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from esbhydro_client import (  # noqa: E402
    ARDNACRUSHA_FLOW_URL,
    FORECAST_URL,
    PARTEEN_WEIR_FLOW_URL,
    fetch_flow_table,
    fetch_forecast_text,
)
from models import DISCHARGE_EXPECTED, NO_DISCHARGE_EXPECTED  # noqa: E402
from parse import parse_flow_table, parse_forecast  # noqa: E402

_RUN = os.environ.get("RUN_LIVE_CANARY") == "1"


@unittest.skipUnless(_RUN, "set RUN_LIVE_CANARY=1 to hit the real ESB endpoints")
class LiveCanaryTests(unittest.TestCase):
    def test_forecast_pdf_still_parses_to_a_known_classification(self):
        forecast = parse_forecast(
            fetch_forecast_text(FORECAST_URL), source_url=FORECAST_URL
        )
        # Every one of the 15 real forecasts captured so far (2017-2026, see
        # tests/fixtures/README.md) classifies. So a live UNPARSED means ESB
        # has started wording the statement in a way we have never seen — a
        # genuine contract break that must fail loudly, because the app
        # degrades it to "Unknown" and the coach silently loses the override.
        self.assertIn(
            forecast.discharge_classification,
            (NO_DISCHARGE_EXPECTED, DISCHARGE_EXPECTED),
            f"unrecognised ESB wording: {forecast.discharge_statement_raw!r}",
        )
        self.assertTrue(forecast.discharge_statement_raw)

    def test_a_discharging_forecast_always_carries_a_range(self):
        forecast = parse_forecast(
            fetch_forecast_text(FORECAST_URL), source_url=FORECAST_URL
        )
        if forecast.discharge_classification == DISCHARGE_EXPECTED:
            self.assertIsNotNone(forecast.expected_discharge_min_m3s)
            self.assertLessEqual(
                forecast.expected_discharge_min_m3s,
                forecast.expected_discharge_max_m3s,
            )

    def test_ardnacrusha_flow_pdf_still_has_thirty_readings(self):
        series = parse_flow_table(
            fetch_flow_table(ARDNACRUSHA_FLOW_URL),
            label="x",
            source_url=ARDNACRUSHA_FLOW_URL,
        )
        self.assertEqual(len(series.readings), 30)
        self.assertGreaterEqual(series.current_value_m3s, 0)

    def test_parteen_weir_flow_pdf_still_has_thirty_readings(self):
        series = parse_flow_table(
            fetch_flow_table(PARTEEN_WEIR_FLOW_URL),
            label="x",
            source_url=PARTEEN_WEIR_FLOW_URL,
        )
        self.assertEqual(len(series.readings), 30)
        self.assertGreaterEqual(series.current_value_m3s, 0)


if __name__ == "__main__":
    unittest.main()
