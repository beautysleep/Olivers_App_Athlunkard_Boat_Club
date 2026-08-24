from datetime import datetime, timezone

from firestore_docs import build_rating_document
from models import AMBER, DayRating

COMPUTED_AT = datetime(2026, 8, 26, 6, 30, tzinfo=timezone.utc)


def test_a_rated_day_carries_its_window_and_its_reasons():
    rating = DayRating(
        AMBER,
        (
            datetime(2026, 8, 26, 6, tzinfo=timezone.utc),
            datetime(2026, 8, 26, 9, tzinfo=timezone.utc),
        ),
        ["Bigger boats only."],
    )

    document = build_rating_document("2026-08-26", rating, computed_at=COMPUTED_AT)

    assert document == {
        "date": "2026-08-26",
        "rating": "amber",
        "window_start": datetime(2026, 8, 26, 6, tzinfo=timezone.utc),
        "window_end": datetime(2026, 8, 26, 9, tzinfo=timezone.utc),
        "reasons": ["Bigger boats only."],
        "computed_at": COMPUTED_AT,
    }


def test_a_day_with_no_window_says_so_rather_than_omitting_the_field():
    rating = DayRating("red", None, ["No rowable depth in daylight."])

    document = build_rating_document("2026-08-26", rating, computed_at=COMPUTED_AT)

    assert document["window_start"] is None
    assert document["window_end"] is None


def test_an_unrated_day_stores_a_null_rating_not_a_guess():
    document = build_rating_document(
        "2026-09-20",
        DayRating(None, None, ["No forecast reaches this day yet."]),
        computed_at=COMPUTED_AT,
    )

    assert document["rating"] is None
