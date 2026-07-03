"""Offline tests for tide parsing and Tarbert->Limerick calibration.

No network or API key needed — these run against a fixed sample payload.
"""

import os
import sys
import unittest
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from calibration import (  # noqa: E402
    DEFAULT_HIGH_HEIGHT_OFFSET_M,
    DEFAULT_LOW_HEIGHT_OFFSET_M,
    DEFAULT_TIME_OFFSET,
    apply_limerick_calibration,
    parse_extremes,
)
from models import TideExtreme  # noqa: E402

# A fixed instant so assertions don't depend on the clock. dt is unix UTC.
_HIGH_DT = 1_700_000_000  # 2023-11-14T22:13:20Z
_LOW_DT = _HIGH_DT + 6 * 3600  # ~6h later

SAMPLE = {
    "status": 200,
    "station": "Tarbert",
    "responseLat": 52.57,
    "responseLon": -9.36,
    "responseDatum": "LAT",
    "extremes": [
        {"dt": _HIGH_DT, "date": "…", "height": 3.20, "type": "High"},
        {"dt": _LOW_DT, "date": "…", "height": 0.40, "type": "Low"},
    ],
}


class ParseTests(unittest.TestCase):
    def test_parses_both_extremes_as_utc(self):
        extremes = parse_extremes(SAMPLE)
        self.assertEqual(len(extremes), 2)
        high, low = extremes
        self.assertEqual(high.kind, "High")
        self.assertEqual(low.kind, "Low")
        self.assertEqual(
            high.time_utc, datetime.fromtimestamp(_HIGH_DT, tz=timezone.utc)
        )
        self.assertEqual(high.height_m, 3.20)

    def test_empty_payload_is_empty(self):
        self.assertEqual(parse_extremes({}), [])


class CalibrationTests(unittest.TestCase):
    def setUp(self):
        self.raw = parse_extremes(SAMPLE)
        self.cal = apply_limerick_calibration(self.raw)

    def test_time_offset_is_one_hour_seven_minutes(self):
        self.assertEqual(DEFAULT_TIME_OFFSET, timedelta(hours=1, minutes=7))

    def test_all_times_shifted_by_the_lag(self):
        for raw, cal in zip(self.raw, self.cal):
            self.assertEqual(cal.time_utc - raw.time_utc, DEFAULT_TIME_OFFSET)

    def test_high_water_height_raised(self):
        high = next(e for e in self.cal if e.kind == "High")
        self.assertAlmostEqual(high.height_m, 3.20 + DEFAULT_HIGH_HEIGHT_OFFSET_M)

    def test_low_water_height_uses_low_offset(self):
        low = next(e for e in self.cal if e.kind == "Low")
        self.assertAlmostEqual(low.height_m, 0.40 + DEFAULT_LOW_HEIGHT_OFFSET_M)

    def test_offsets_are_overridable(self):
        cal = apply_limerick_calibration(
            self.raw,
            time_offset=timedelta(minutes=30),
            high_height_offset_m=1.0,
        )
        high = next(e for e in cal if e.kind == "High")
        self.assertAlmostEqual(high.height_m, 4.20)
        self.assertEqual(
            high.time_utc,
            datetime.fromtimestamp(_HIGH_DT, tz=timezone.utc) + timedelta(minutes=30),
        )


class LocalTimeTests(unittest.TestCase):
    """Daylight-saving must be applied via the Europe/Dublin zone, so a UTC
    instant reads correctly in local time year-round."""

    def test_summer_instant_is_irish_summer_time(self):
        # 19:51 UTC on 3 Jul is 20:51 local (IST, +1h).
        e = TideExtreme(
            "High", datetime(2026, 7, 3, 19, 51, tzinfo=timezone.utc), 5.47
        )
        self.assertEqual(e.time_local.utcoffset(), timedelta(hours=1))
        self.assertEqual((e.time_local.hour, e.time_local.minute), (20, 51))

    def test_winter_instant_is_gmt(self):
        # 09:00 UTC on 15 Jan is 09:00 local (GMT, +0h).
        e = TideExtreme(
            "Low", datetime(2026, 1, 15, 9, 0, tzinfo=timezone.utc), 1.0
        )
        self.assertEqual(e.time_local.utcoffset(), timedelta(0))
        self.assertEqual(e.time_local.hour, 9)

    def test_to_dict_carries_both_utc_and_local(self):
        e = TideExtreme(
            "High", datetime(2026, 7, 3, 19, 51, tzinfo=timezone.utc), 5.47
        )
        d = e.to_dict()
        self.assertTrue(d["time_utc"].endswith("+00:00"))
        self.assertTrue(d["time_local"].endswith("+01:00"))


if __name__ == "__main__":
    unittest.main()
