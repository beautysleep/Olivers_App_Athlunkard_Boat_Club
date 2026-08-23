"""Offline tests for grouping forecast points into local days and building the
per-day Firestore document. No network, no Firestore, no key."""

import os
import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from firestore_docs import (  # noqa: E402
    build_day_document,
    build_documents,
    group_hourly_by_local_day,
)
from models import WeatherPoint  # noqa: E402


def _pt(iso_utc, wind=5.0, gust=8.0, rain=0.0, pop=0.1, sunrise=None, sunset=None):
    return WeatherPoint(
        datetime.fromisoformat(iso_utc), wind, gust, rain, pop, sunrise, sunset
    )


class DaylightInDocumentTests(unittest.TestCase):
    """sunrise/sunset sit at document level, not inside `daily` - they are
    day-level facts, whereas `daily` is documented as the decision metrics."""

    def test_daylight_is_written_at_document_level(self):
        sunrise = datetime(2026, 8, 24, 5, 30, tzinfo=timezone.utc)
        sunset = datetime(2026, 8, 24, 20, 45, tzinfo=timezone.utc)
        doc = build_day_document(
            "2026-08-24",
            _pt("2026-08-24T12:00:00+00:00", sunrise=sunrise, sunset=sunset),
            [],
            fetched_at=datetime(2026, 8, 24, 9, 0, tzinfo=timezone.utc),
        )
        self.assertEqual(doc["sunrise"], sunrise)
        self.assertEqual(doc["sunset"], sunset)
        self.assertNotIn("sunrise", doc["daily"])

    def test_a_day_without_a_daily_point_has_null_daylight(self):
        doc = build_day_document(
            "2026-08-24",
            None,
            [],
            fetched_at=datetime(2026, 8, 24, 9, 0, tzinfo=timezone.utc),
        )
        self.assertIsNone(doc["sunrise"])
        self.assertIsNone(doc["sunset"])


class GroupHourlyByLocalDayTests(unittest.TestCase):
    def test_buckets_by_local_day_not_utc(self):
        # 23:30 UTC in summer is 00:30 the *next* day local (IST, +1h), so it
        # must land in the next local day — the point of grouping on local time.
        late = _pt("2026-07-03T23:30:00+00:00")  # local 07-04
        day = _pt("2026-07-03T10:00:00+00:00")  # local 07-03
        nxt = _pt("2026-07-04T08:00:00+00:00")  # local 07-04

        groups = group_hourly_by_local_day([day, late, nxt])

        self.assertEqual(set(groups), {"2026-07-03", "2026-07-04"})
        self.assertEqual(len(groups["2026-07-03"]), 1)
        self.assertEqual(len(groups["2026-07-04"]), 2)


class BuildDocumentsTests(unittest.TestCase):
    def test_one_doc_per_daily_day_with_hourly_attached(self):
        fetched = datetime(2026, 7, 3, 4, 0, tzinfo=timezone.utc)
        # Two daily days; hourly points only for the first.
        d0 = _pt("2026-07-03T12:00:00+00:00", wind=6.0, gust=10.0, rain=0.5, pop=0.2)
        d1 = _pt("2026-07-04T12:00:00+00:00", wind=4.0, gust=7.0, rain=0.0, pop=0.0)
        h0a = _pt("2026-07-03T09:00:00+00:00", wind=5.5)
        h0b = _pt("2026-07-03T10:00:00+00:00", wind=6.5)

        docs = build_documents([d0, d1], [h0a, h0b], fetched_at=fetched)

        self.assertEqual(set(docs), {"2026-07-03", "2026-07-04"})

        doc0 = docs["2026-07-03"]
        self.assertEqual(doc0["date"], "2026-07-03")
        self.assertEqual(doc0["source"], "openweather")
        self.assertEqual(doc0["fetched_at"], fetched)
        self.assertEqual(
            doc0["daily"],
            {"wind_speed_ms": 6.0, "wind_gust_ms": 10.0, "rain_mm": 0.5, "pop": 0.2},
        )
        self.assertEqual(len(doc0["hourly"]), 2)
        self.assertEqual(doc0["hourly"][0]["time_utc"], h0a.time_utc)

    def test_day_beyond_hourly_horizon_has_empty_hourly(self):
        fetched = datetime(2026, 7, 3, 4, 0, tzinfo=timezone.utc)
        d0 = _pt("2026-07-03T12:00:00+00:00")
        d1 = _pt("2026-07-04T12:00:00+00:00", wind=4.0)
        # only day 0 has hourly coverage
        h0 = _pt("2026-07-03T09:00:00+00:00")

        docs = build_documents([d0, d1], [h0], fetched_at=fetched)

        self.assertEqual(docs["2026-07-04"]["daily"]["wind_speed_ms"], 4.0)
        self.assertEqual(docs["2026-07-04"]["hourly"], [])


if __name__ == "__main__":
    unittest.main()
