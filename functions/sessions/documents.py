"""A proposed session as Firestore stores it — the Python mirror of the
app's `sessionToDocument`. Field names and values must match exactly: a
mismatch here fails silently on the Dart side (`sessionFromDocument` returns
null, and the session just never appears).

Pure — no Firestore dependency — so the shape is testable directly.
"""

from __future__ import annotations

from datetime import datetime

from models import PROPOSED


def build_proposed_session_document(
    *,
    coach_id: str,
    meeting_time: datetime,
    high_tide_time: datetime,
    condition_rating: str,
    minimum_crew: int = 4,
) -> dict:
    """[minimum_crew] defaults rather than reading from the request: v1 fixes
    it at 4 for every session — variable headcount by boat type is explicitly
    out of scope."""
    return {
        "meeting_time": meeting_time,
        "high_tide_time": high_tide_time,
        "condition_rating": condition_rating,
        "coach_id": coach_id,
        "committed_athlete_ids": [],
        "lifecycle": PROPOSED,
        "minimum_crew": minimum_crew,
    }
