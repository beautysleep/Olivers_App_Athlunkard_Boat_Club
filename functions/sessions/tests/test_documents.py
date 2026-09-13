from datetime import datetime, timezone

from documents import build_proposed_session_document
from models import GREEN, PROPOSED


class TestBuildProposedSessionDocument:
    def test_the_shape_matches_what_the_app_reads_back(self):
        meeting_time = datetime(2026, 9, 20, 6, 0, tzinfo=timezone.utc)
        high_tide_time = datetime(2026, 9, 20, 6, 41, tzinfo=timezone.utc)

        document = build_proposed_session_document(
            coach_id="uid_coach",
            meeting_time=meeting_time,
            high_tide_time=high_tide_time,
            condition_rating=GREEN,
        )

        assert document == {
            "meeting_time": meeting_time,
            "high_tide_time": high_tide_time,
            "condition_rating": GREEN,
            "coach_id": "uid_coach",
            "committed_athlete_ids": [],
            "lifecycle": PROPOSED,
            "minimum_crew": 4,
        }

    def test_nobody_starts_committed(self):
        document = build_proposed_session_document(
            coach_id="uid_coach",
            meeting_time=datetime(2026, 9, 20, 6, 0, tzinfo=timezone.utc),
            high_tide_time=datetime(2026, 9, 20, 6, 41, tzinfo=timezone.utc),
            condition_rating=GREEN,
        )

        assert document["committed_athlete_ids"] == []

    def test_a_new_proposal_is_always_proposed_not_already_cancelled(self):
        document = build_proposed_session_document(
            coach_id="uid_coach",
            meeting_time=datetime(2026, 9, 20, 6, 0, tzinfo=timezone.utc),
            high_tide_time=datetime(2026, 9, 20, 6, 41, tzinfo=timezone.utc),
            condition_rating=GREEN,
        )

        assert document["lifecycle"] == PROPOSED
