from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class TideExtreme:
    at: datetime
    height_metres: float


def _crossing_fraction(low: float, high: float, threshold: float) -> float | None:
    """Where between a low and a high the water passes `threshold`, as a
    fraction of the run from one to the other.

    Tide between consecutive extremes is approximated as a half cosine — the
    standard curve behind the rule of twelfths — which is why the water spends
    longer near the turn than it does mid-run.
    """
    if threshold > high:
        return None
    if threshold <= low:
        return 0.0
    risen = (threshold - low) / (high - low)
    return math.acos(1 - 2 * risen) / math.pi


def rowable_interval(
    high_tide_at: datetime,
    extremes: list[TideExtreme],
    *,
    minimum_height_metres: float,
) -> tuple[datetime, datetime] | None:
    """How long the water stays at or above a rowable height around one high
    tide — not a fixed span, because a bigger tide holds the depth for longer.

    Each limb is measured against its own neighbouring low, so an uneven pair
    (a shallow low before, a high low after) gives an asymmetric window.
    """
    ordered = sorted(extremes, key=lambda extreme: extreme.at)
    index = next(
        (i for i, extreme in enumerate(ordered) if extreme.at == high_tide_at), None
    )
    if index is None:
        return None

    high = ordered[index]
    if high.height_metres < minimum_height_metres:
        return None

    previous_low = ordered[index - 1] if index > 0 else None
    next_low = ordered[index + 1] if index + 1 < len(ordered) else None
    if previous_low is None or next_low is None:
        return None

    rising = _crossing_fraction(
        previous_low.height_metres, high.height_metres, minimum_height_metres
    )
    falling = _crossing_fraction(
        next_low.height_metres, high.height_metres, minimum_height_metres
    )
    if rising is None or falling is None:
        return None

    starts_at = previous_low.at + rising * (high.at - previous_low.at)
    ends_at = next_low.at - falling * (next_low.at - high.at)
    return (starts_at, ends_at)
