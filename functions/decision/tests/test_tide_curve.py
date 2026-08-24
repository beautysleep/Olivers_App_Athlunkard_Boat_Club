import pytest

from datetime import datetime, timedelta, timezone

from tide_curve import TideExtreme, rowable_interval

LOW = datetime(2026, 8, 26, 0, tzinfo=timezone.utc)
HIGH = datetime(2026, 8, 26, 6, tzinfo=timezone.utc)
NEXT_LOW = datetime(2026, 8, 26, 12, tzinfo=timezone.utc)

ROWABLE = 4.2


def curve(high_metres, low_metres=1.0):
    return [
        TideExtreme(at=LOW, height_metres=low_metres),
        TideExtreme(at=HIGH, height_metres=high_metres),
        TideExtreme(at=NEXT_LOW, height_metres=low_metres),
    ]


def test_the_window_opens_and_closes_where_the_tide_crosses_the_threshold():
    start, end = rowable_interval(HIGH, curve(5.0), minimum_height_metres=ROWABLE)

    # Half-cosine between 1.0 m at 00:00 and 5.0 m at 06:00 reaches 4.2 m at
    # acos(-0.6)/pi of the 6h run: 15224.4s, or 4h 13m 44s, after the low and
    # the same again before the next one. Not the midpoint — the water lingers
    # near the turn, which is the whole reason a fixed span was wrong.
    assert (start - LOW).total_seconds() == pytest.approx(15224.4, abs=0.1)
    assert (NEXT_LOW - end).total_seconds() == pytest.approx(15224.4, abs=0.1)


def test_a_bigger_high_tide_stays_rowable_for_longer():
    big = rowable_interval(HIGH, curve(5.4), minimum_height_metres=ROWABLE)
    small = rowable_interval(HIGH, curve(4.5), minimum_height_metres=ROWABLE)

    assert (big[1] - big[0]) > (small[1] - small[0])


def test_a_high_tide_that_never_reaches_the_threshold_has_no_window():
    assert rowable_interval(HIGH, curve(4.0), minimum_height_metres=ROWABLE) is None


def test_a_tide_that_never_drops_below_the_threshold_is_rowable_throughout():
    start, end = rowable_interval(
        HIGH, curve(5.0, low_metres=4.5), minimum_height_metres=ROWABLE
    )

    assert (start, end) == (LOW, NEXT_LOW)


def test_the_window_is_measured_against_each_neighbouring_low_separately():
    falling_to_a_higher_low = [
        TideExtreme(at=LOW, height_metres=1.0),
        TideExtreme(at=HIGH, height_metres=5.0),
        TideExtreme(at=NEXT_LOW, height_metres=4.0),
    ]

    start, end = rowable_interval(
        HIGH, falling_to_a_higher_low, minimum_height_metres=ROWABLE
    )

    assert HIGH - start < timedelta(hours=2)
    assert end - HIGH > timedelta(hours=4)
