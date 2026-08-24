"""Live contract/canary test: reads the real Firestore collections and asserts
the stored shapes this service depends on still hold.

Unlike the other three services, our upstream is not an outside API — it is the
documents the tide, weather and water-release fetchers write. That makes this
the test that notices when one of them changes its schema. The offline tests
build their own inputs and stay green regardless, so "canary red + units green"
means a fetcher changed its output; "canary green + units red" means the engine
broke on its own.

It also runs the engine over the live data, because a rating of None everywhere
is exactly what a silent contract break looks like: no exception, no failing
assertion, just an app that quietly stops rating anything.

Gated on RUN_LIVE_CANARY, like the water-release canary — the credential here is
ambient (application default credentials), so there is no key whose absence
could gate it, and reading someone's Firestore on every test run should be a
deliberate act.

    export RUN_LIVE_CANARY=1
    python -m unittest discover -s tests -p "test_live_canary.py"
"""

import os
import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from engine import rate_day  # noqa: E402
from inputs import (  # noqa: E402
    all_tide_extremes,
    cumulative_rain_before,
    daily_weather_for,
    daylight_for,
    high_tides_on,
    hourly_slots_for,
)
from main import rate_all_days  # noqa: E402
from models import AMBER, GREEN, RED  # noqa: E402

_RUN = os.environ.get("RUN_LIVE_CANARY")


@unittest.skipUnless(_RUN, "set RUN_LIVE_CANARY=1 to read the real Firestore")
class LiveFirestoreCanaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from google.cloud import firestore

        client = firestore.Client()
        cls.tide = {
            d.id: d.to_dict() for d in client.collection("tide_predictions").stream()
        }
        cls.weather = {
            d.id: d.to_dict() for d in client.collection("weather_forecasts").stream()
        }
        cls.water_release = (
            client.collection("water_release_status")
            .document("current")
            .get()
            .to_dict()
        )
        cls.today = datetime.now(timezone.utc).date().isoformat()

    def upcoming(self, documents):
        return sorted(key for key in documents if key >= self.today)

    def test_tide_extremes_still_carry_kind_time_and_height(self):
        """The three field names the window calculation reads. Renaming any of
        them leaves every day unrated rather than raising."""
        for date_str in self.upcoming(self.tide)[:5]:
            for extreme in self.tide[date_str]["extremes"]:
                self.assertIn(extreme["kind"], ("High", "Low"))
                self.assertIsInstance(extreme["time_utc"], datetime)
                self.assertIsInstance(extreme["height_m"], float)

    def test_low_waters_are_still_stored_alongside_the_highs(self):
        """The window is derived from the curve between a high and its
        neighbouring lows. Storing only highs would silently collapse every
        window to nothing."""
        kinds = {
            extreme["kind"]
            for date_str in self.upcoming(self.tide)[:5]
            for extreme in self.tide[date_str]["extremes"]
        }
        self.assertIn("Low", kinds)
        self.assertIn("High", kinds)

    def test_weather_days_still_carry_daylight_and_a_daily_figure(self):
        """Daylight is a hard override, and the daily figure is what rates the
        days beyond the hourly horizon."""
        for date_str in self.upcoming(self.weather)[:5]:
            self.assertIsNotNone(daylight_for(self.weather, date_str))
            self.assertIsNotNone(daily_weather_for(self.weather, date_str))

    def test_hourly_detail_still_reaches_at_least_a_day_ahead(self):
        """Without hourly the engine can still rate a day, but every window is
        an approximation. Losing it entirely is a quiet downgrade worth
        catching."""
        with_hourly = [
            date_str
            for date_str in self.upcoming(self.weather)
            if hourly_slots_for(self.weather, date_str)
        ]
        self.assertGreaterEqual(len(with_hourly), 1)

    def test_the_water_release_classification_is_one_we_understand(self):
        """An unrecognised word is treated as unparsed, which never reads as
        clear — but it also means the override has stopped working."""
        classification = self.water_release["parteen_forecast"][
            "discharge_classification"
        ]
        self.assertIn(
            classification,
            ("no_discharge_expected", "discharge_expected", "unparsed"),
        )

    def test_the_engine_still_rates_the_days_ahead(self):
        """The catch-all: a contract break upstream shows up here as ratings
        that are all None, with nothing else failing."""
        rated = rate_all_days(
            self.tide,
            self.weather,
            self.water_release,
            computed_at=datetime.now(timezone.utc),
        )
        ratings = [
            document["rating"]
            for date_str, document in rated.items()
            if daily_weather_for(self.weather, date_str) is not None
        ]

        self.assertGreaterEqual(len(ratings), 5, "almost nothing was rated")
        self.assertTrue(
            all(rating in (GREEN, AMBER, RED) for rating in ratings),
            f"unexpected ratings among {ratings}",
        )

    def test_a_rated_day_reports_a_window_for_each_of_its_high_tides(self):
        """The card offers one proposal per rowable tide, so a day whose tides
        stop being reported individually breaks the coach's choice."""
        extremes = all_tide_extremes(self.tide)
        for date_str in self.upcoming(self.tide):
            highs = high_tides_on(self.tide, date_str)
            if daily_weather_for(self.weather, date_str) is None or not highs:
                continue
            verdict = rate_day(
                high_tides=highs,
                extremes=extremes,
                daylight=daylight_for(self.weather, date_str),
                slots=hourly_slots_for(self.weather, date_str),
                daily=daily_weather_for(self.weather, date_str),
                water_release_classification=self.water_release["parteen_forecast"][
                    "discharge_classification"
                ],
                cumulative_rain_mm=cumulative_rain_before(self.weather, date_str),
            )
            if verdict.windows:
                self.assertLessEqual(len(verdict.windows), len(highs))
                for window in verdict.windows:
                    self.assertIn(window.high_tide_at, highs)
                return
        self.fail("no upcoming day produced a window to check")


if __name__ == "__main__":
    unittest.main()
