from datetime import datetime, timezone

from firestore_docs import build_rating_document
from models import AMBER, GREEN, RED, DayRating, WindowRating

COMPUTED_AT = datetime(2026, 8, 26, 6, 30, tzinfo=timezone.utc)
MORNING = datetime(2026, 8, 26, 6, 41, tzinfo=timezone.utc)
EVENING = datetime(2026, 8, 26, 18, 51, tzinfo=timezone.utc)


def test_each_rowable_tide_is_reported_with_its_own_verdict():
    rating = DayRating(
        GREEN,
        [],
        [
            WindowRating(MORNING, RED, None, ["Too windy all morning."]),
            WindowRating(
                EVENING,
                GREEN,
                (
                    datetime(2026, 8, 26, 17, tzinfo=timezone.utc),
                    datetime(2026, 8, 26, 20, tzinfo=timezone.utc),
                ),
                [],
            ),
        ],
    )

    document = build_rating_document("2026-08-26", rating, computed_at=COMPUTED_AT)

    assert document["rating"] == GREEN
    assert [w["rating"] for w in document["windows"]] == [RED, GREEN]
    assert [w["high_tide_at"] for w in document["windows"]] == [MORNING, EVENING]
    assert document["windows"][0]["window_start"] is None
    assert document["windows"][1]["window_end"] == datetime(
        2026, 8, 26, 20, tzinfo=timezone.utc
    )


def test_an_override_settles_the_day_and_leaves_no_windows_to_report():
    document = build_rating_document(
        "2026-08-26",
        DayRating(RED, ["ESB expects a discharge at Parteen Weir — no rowing."]),
        computed_at=COMPUTED_AT,
    )

    assert document["rating"] == RED
    assert document["windows"] == []
    assert document["reasons"] == [
        "ESB expects a discharge at Parteen Weir — no rowing."
    ]


def test_an_unrated_day_stores_a_null_rating_not_a_guess():
    document = build_rating_document(
        "2026-09-20",
        DayRating(None, ["No forecast reaches this day yet."]),
        computed_at=COMPUTED_AT,
    )

    assert document["rating"] is None


def test_a_day_level_reason_is_not_repeated_onto_every_window():
    rating = DayRating(
        AMBER,
        ["Weir state unconfirmed."],
        [WindowRating(MORNING, GREEN, (MORNING, EVENING), [])],
    )

    document = build_rating_document("2026-08-26", rating, computed_at=COMPUTED_AT)

    assert document["reasons"] == ["Weir state unconfirmed."]
    assert document["windows"][0]["reasons"] == []


def test_the_tide_window_is_written_alongside_the_weather_window():
    # The weather window can be shorter than the tide window (wind drops the
    # usable part), and on an override-red day the weather window is null while
    # the tide window still stands — the card needs both to tell them apart.
    tide_window = (
        datetime(2026, 8, 26, 15, tzinfo=timezone.utc),
        datetime(2026, 8, 26, 21, tzinfo=timezone.utc),
    )
    weather_window = (
        datetime(2026, 8, 26, 17, tzinfo=timezone.utc),
        datetime(2026, 8, 26, 20, tzinfo=timezone.utc),
    )
    rating = DayRating(
        GREEN,
        [],
        [
            WindowRating(
                EVENING,
                GREEN,
                weather_window,
                [],
                tide_window=tide_window,
            )
        ],
    )

    document = build_rating_document("2026-08-26", rating, computed_at=COMPUTED_AT)

    assert document["windows"][0]["tide_window_start"] == tide_window[0]
    assert document["windows"][0]["tide_window_end"] == tide_window[1]
    assert document["windows"][0]["window_start"] == weather_window[0]
    assert document["windows"][0]["window_end"] == weather_window[1]
