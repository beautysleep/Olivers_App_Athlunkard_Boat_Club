"""Offline tests for weather domain types. No network or API key needed."""

import os
import sys
import unittest
from datetime import datetime, timedelta

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from models import WeatherPoint  # noqa: E402


def _weather_point(iso_utc, wind=5.0, gust=8.0, rain=0.0, pop=0.1, sunrise=None, sunset=None):
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
        point = _weather_point("2026-07-03T19:00:00+00:00")
        self.assertEqual(point.time_local.utcoffset(), timedelta(hours=1))
        self.assertEqual((point.time_local.hour, point.time_local.minute), (20, 0))

    def test_winter_instant_is_gmt(self):
        # 09:00 UTC on 15 Jan is 09:00 local (GMT, +0h).
        point = _weather_point("2026-01-15T09:00:00+00:00")
        self.assertEqual(point.time_local.utcoffset(), timedelta(0))
        self.assertEqual(point.time_local.hour, 9)


class SerialisationTests(unittest.TestCase):
    def test_to_dict_carries_time_and_rounded_metrics(self):
        point = _weather_point(
            "2026-07-03T19:00:00+00:00",
            wind=5.123,
            gust=8.987,
            rain=1.234,
            pop=0.666,
        )
        document = point.to_dict()
        self.assertEqual(document["time_utc"], point.time_utc)  # datetime -> Firestore Timestamp
        self.assertEqual(document["wind_speed_ms"], 5.12)
        self.assertEqual(document["wind_gust_ms"], 8.99)
        self.assertEqual(document["rain_mm"], 1.23)
        self.assertEqual(document["pop"], 0.67)

    def test_metrics_omit_the_timestamp(self):
        point = _weather_point("2026-07-03T19:00:00+00:00")
        self.assertNotIn("time_utc", point.metrics())
        self.assertEqual(
            set(point.metrics()),
            {"wind_speed_ms", "wind_gust_ms", "rain_mm", "pop"},
        )

    def test_gust_may_be_absent(self):
        point = _weather_point("2026-07-03T19:00:00+00:00", gust=None)
        self.assertIsNone(point.to_dict()["wind_gust_ms"])
        self.assertIsNone(point.metrics()["wind_gust_ms"])

    def test_pop_may_be_absent(self):
        # 4.0 daily records omit pop; represent that as null, not a fake 0.
        point = _weather_point("2026-07-03T19:00:00+00:00", pop=None)
        self.assertIsNone(point.to_dict()["pop"])
        self.assertIsNone(point.metrics()["pop"])


if __name__ == "__main__":
    unittest.main()
