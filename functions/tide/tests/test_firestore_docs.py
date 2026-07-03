"""Offline tests for grouping extremes into local days and building the
Firestore document. No network, no Firestore, no key."""

import os
import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from firestore_docs import build_day_document, group_by_local_day  # noqa: E402
from models import TideExtreme  # noqa: E402


def _ext(kind, iso_utc, height):
    return TideExtreme(kind, datetime.fromisoformat(iso_utc), height)


class GroupByLocalDayTests(unittest.TestCase):
    def test_buckets_by_local_day_not_utc(self):
        # 23:30 UTC in summer is 00:30 the *next* day local (IST, +1h), so it
        # must land in the next local day — the whole point of grouping local.
        e_late = _ext("High", "2026-07-03T23:30:00+00:00", 5.0)  # local 07-04
        e_next = _ext("Low", "2026-07-04T09:00:00+00:00", 1.0)   # local 07-04
        e_day = _ext("High", "2026-07-03T10:00:00+00:00", 4.8)   # local 07-03

        groups = group_by_local_day([e_day, e_late, e_next])

        self.assertEqual(set(groups), {"2026-07-03", "2026-07-04"})
        self.assertEqual(len(groups["2026-07-03"]), 1)
        self.assertEqual(len(groups["2026-07-04"]), 2)


class BuildDayDocumentTests(unittest.TestCase):
    def test_document_shape(self):
        fetched = datetime(2026, 7, 3, 4, 0, tzinfo=timezone.utc)
        e = _ext("High", "2026-07-04T20:58:00+00:00", 5.473)

        doc = build_day_document(
            "2026-07-04",
            [e],
            station="TARBERT ISLAND",
            datum="CD",
            fetched_at=fetched,
            time_offset_minutes=67,
            high_height_offset_m=0.85,
        )

        self.assertEqual(doc["date"], "2026-07-04")
        self.assertEqual(doc["station"], "TARBERT ISLAND")
        self.assertEqual(doc["datum"], "CD")
        self.assertEqual(doc["source"], "worldtides")
        self.assertEqual(
            doc["calibration"],
            {"time_offset_minutes": 67, "high_height_offset_m": 0.85},
        )
        self.assertEqual(doc["fetched_at"], fetched)
        self.assertEqual(len(doc["extremes"]), 1)
        x = doc["extremes"][0]
        self.assertEqual(x["kind"], "High")
        self.assertEqual(x["time_utc"], e.time_utc)  # datetime -> Firestore Timestamp
        self.assertEqual(x["height_m"], 5.473)


if __name__ == "__main__":
    unittest.main()
