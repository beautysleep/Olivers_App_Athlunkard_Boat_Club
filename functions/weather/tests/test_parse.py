"""Offline tests for parsing One Call 4.0 timeline responses.

Runs against CAPTURED REAL responses (API key scrubbed) under fixtures/, so the
assertions pin the parser to the shape OpenWeather actually returned — not
hand-invented data. The companion live *contract* test (which detects when OWM
changes that shape) is added from the next data source on; see the project's
testing-approach note.
"""

import json
import os
import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from parse import _rain_mm, parse_points  # noqa: E402

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _load(name):
    with open(os.path.join(FIXTURES, name)) as f:
        return json.load(f)


class HourlyParseTests(unittest.TestCase):
    def setUp(self):
        self.points = parse_points(_load("onecall_4_hourly.json"))

    def test_parses_every_record(self):
        self.assertEqual(len(self.points), 20)

    def test_first_point_matches_source(self):
        p = self.points[0]
        self.assertEqual(
            p.time_utc, datetime.fromtimestamp(1784332800, tz=timezone.utc)
        )
        self.assertEqual(p.wind_speed_ms, 2.31)
        self.assertEqual(p.wind_gust_ms, 2.53)
        self.assertEqual(p.pop, 0.0)

    def test_dry_period_defaults_rain_to_zero(self):
        # the sample is a clear-sky window: no `rain` key on any record
        self.assertTrue(all(p.rain_mm == 0.0 for p in self.points))


class DailyParseTests(unittest.TestCase):
    def setUp(self):
        self.points = parse_points(_load("onecall_4_daily.json"))

    def test_parses_every_record(self):
        self.assertEqual(len(self.points), 10)

    def test_first_point_and_absent_fields_are_null(self):
        p = self.points[0]
        self.assertEqual(p.wind_speed_ms, 5.51)
        self.assertIsNone(p.wind_gust_ms)  # 4.0 daily omits gust
        self.assertIsNone(p.pop)           # 4.0 daily omits pop
        self.assertEqual(p.rain_mm, 0.0)   # dry

    def test_daily_records_carry_sunrise_and_sunset(self):
        p = self.points[0]
        self.assertEqual(
            p.sunrise_utc, datetime.fromtimestamp(1784349155, tz=timezone.utc)
        )
        self.assertEqual(
            p.sunset_utc, datetime.fromtimestamp(1784407710, tz=timezone.utc)
        )

    def test_every_daily_record_has_a_daylight_window(self):
        """Daylight is a hard override in the row/no-row decision, so a day
        silently missing it would be a real gap - assert the whole horizon."""
        for point in self.points:
            self.assertIsNotNone(point.sunrise_utc)
            self.assertIsNotNone(point.sunset_utc)
            self.assertLess(point.sunrise_utc, point.sunset_utc)


class HourlyDaylightTests(unittest.TestCase):
    def test_hourly_records_have_no_daylight_window(self):
        """OWM puts sunrise/sunset only on daily records - the mirror of daily
        omitting wind_gust/pop. Absent stays None rather than invented."""
        points = parse_points(_load("onecall_4_hourly.json"))
        self.assertTrue(all(p.sunrise_utc is None for p in points))
        self.assertTrue(all(p.sunset_utc is None for p in points))


class RainShapeTests(unittest.TestCase):
    def test_hourly_object_shape(self):
        self.assertEqual(_rain_mm({"rain": {"1h": 1.2}}), 1.2)

    def test_daily_number_shape(self):
        self.assertEqual(_rain_mm({"rain": 3.4}), 3.4)

    def test_absent_rain_is_zero(self):
        self.assertEqual(_rain_mm({}), 0.0)


if __name__ == "__main__":
    unittest.main()
