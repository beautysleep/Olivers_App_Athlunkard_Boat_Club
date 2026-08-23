"""Live contract/canary test: hits the real OpenWeather One Call 4.0 daily
endpoint and asserts the response shape this service depends on still holds.

The offline tests in test_parse.py run against a captured real response, which
stays green forever even if OpenWeather changes the live shape underneath us.
This is the test that notices. "Canary red + units green" means the API
changed; "canary green + units red" means our logic broke.

Gated on the API key being present, so it simply skips wherever no credential
is configured (CI, a fresh clone) rather than failing. The water-release canary
gates on an explicit RUN_LIVE_CANARY instead, because its ESB PDFs need no key
and hammering a small public-sector server on every test run would be rude.

    export OPENWEATHER_API_KEY=...   # see ../README.md "Local secrets"
    python -m unittest discover -s tests -p "test_live_canary.py"
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from main import CLUB_LAT, CLUB_LON  # noqa: E402
from openweather_client import fetch_daily  # noqa: E402
from parse import parse_points  # noqa: E402

_API_KEY = os.environ.get("OPENWEATHER_API_KEY")


@unittest.skipUnless(_API_KEY, "set OPENWEATHER_API_KEY to hit the real API")
class LiveDailyCanaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.points = parse_points(fetch_daily(CLUB_LAT, CLUB_LON, _API_KEY))

    def test_daily_horizon_is_still_multi_day(self):
        """The app's calendar shows 10 days. If OpenWeather shortens this
        horizon, days beyond it lose live data entirely."""
        self.assertGreaterEqual(len(self.points), 10)

    def test_every_day_still_carries_a_daylight_window(self):
        """Daylight is a hard override in the row/no-row decision. A day
        arriving without it is a contract break, not a soft gap."""
        for point in self.points:
            self.assertIsNotNone(point.sunrise_utc, f"no sunrise on {point.time_utc}")
            self.assertIsNotNone(point.sunset_utc, f"no sunset on {point.time_utc}")
            self.assertLess(point.sunrise_utc, point.sunset_utc)

    def test_daylight_length_is_physically_plausible_for_ireland(self):
        """Guards against a unit or timezone change slipping through: at
        Limerick's latitude the shortest day is ~7.5h and the longest ~17h."""
        for point in self.points:
            hours = (point.sunset_utc - point.sunrise_utc).total_seconds() / 3600
            self.assertGreater(hours, 7.0, f"implausibly short day: {hours:.1f}h")
            self.assertLess(hours, 17.5, f"implausibly long day: {hours:.1f}h")

    def test_decision_metrics_are_still_present(self):
        """The wind/rain fields the row/no-row thresholds read."""
        point = self.points[0]
        self.assertIsInstance(point.wind_speed_ms, float)
        self.assertIsInstance(point.rain_mm, float)


if __name__ == "__main__":
    unittest.main()
