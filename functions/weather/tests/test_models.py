"""Offline tests for weather domain types. No network or API key needed."""

import os
import sys
import unittest
from datetime import datetime, timedelta

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from models import WeatherPoint  # noqa: E402


def _pt(iso_utc, wind=5.0, gust=8.0, rain=0.0, pop=0.1, sunrise=None, sunset=None):
    return WeatherPoint(
        time_utc=datetime.fromisoformat(iso_utc),
        wind_speed_ms=wind,
        wind_gust_ms=gust,
        rain_mm=rain,
        pop=pop,
        sunrise_utc=sunrise,
        sunset_utc=sunset,
    )


class LocalTimeTests(unittest.TestCase):
    """Daylight-saving must come from the Europe/Dublin zone, so a UTC instant
    reads correctly in local time year-round."""

    def test_summer_instant_is_irish_summer_time(self):
        # 19:00 UTC on 3 Jul is 20:00 local (IST, +1h).
        p = _pt("2026-07-03T19:00:00+00:00")
        self.assertEqual(p.time_local.utcoffset(), timedelta(hours=1))
        self.assertEqual((p.time_local.hour, p.time_local.minute), (20, 0))

    def test_winter_instant_is_gmt(self):
        # 09:00 UTC on 15 Jan is 09:00 local (GMT, +0h).
        p = _pt("2026-01-15T09:00:00+00:00")
        self.assertEqual(p.time_local.utcoffset(), timedelta(0))
        self.assertEqual(p.time_local.hour, 9)


class SerialisationTests(unittest.TestCase):
    def test_to_dict_carries_time_and_rounded_metrics(self):
        p = _pt(
            "2026-07-03T19:00:00+00:00",
            wind=5.123,
            gust=8.987,
            rain=1.234,
            pop=0.666,
        )
        d = p.to_dict()
        self.assertEqual(d["time_utc"], p.time_utc)  # datetime -> Firestore Timestamp
        self.assertEqual(d["wind_speed_ms"], 5.12)
        self.assertEqual(d["wind_gust_ms"], 8.99)
        self.assertEqual(d["rain_mm"], 1.23)
        self.assertEqual(d["pop"], 0.67)

    def test_metrics_omit_the_timestamp(self):
        p = _pt("2026-07-03T19:00:00+00:00")
        self.assertNotIn("time_utc", p.metrics())
        self.assertEqual(
            set(p.metrics()),
            {"wind_speed_ms", "wind_gust_ms", "rain_mm", "pop"},
        )

    def test_gust_may_be_absent(self):
        p = _pt("2026-07-03T19:00:00+00:00", gust=None)
        self.assertIsNone(p.to_dict()["wind_gust_ms"])
        self.assertIsNone(p.metrics()["wind_gust_ms"])

    def test_pop_may_be_absent(self):
        # 4.0 daily records omit pop; represent that as null, not a fake 0.
        p = _pt("2026-07-03T19:00:00+00:00", pop=None)
        self.assertIsNone(p.to_dict()["pop"])
        self.assertIsNone(p.metrics()["pop"])


if __name__ == "__main__":
    unittest.main()
