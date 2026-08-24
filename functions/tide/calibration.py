"""WorldTides resolves the club's coordinates to the nearest station, which for
the Shannon is ~Tarbert (outer estuary). Limerick Dock, at the tidal limit,
differs predictably, so the coach's empirical offsets are applied here.

These offsets are TUNABLE, not final — field estimates to be refined against the
OPW "Limerick Dock" gauge. Do not treat them as ground truth.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from models import TideExtreme

# --- Calibration parameters (tunable) ------------------------------------
# Limerick Dock high tide occurs ~1h07m AFTER Tarbert (tide propagates
# up-estuary). Applied to every extreme as a first approximation for the lag.
DEFAULT_TIME_OFFSET = timedelta(hours=1, minutes=7)

# Limerick Dock high water is ~0.80–0.90 m higher than Tarbert; 0.85 m midpoint.
DEFAULT_HIGH_HEIGHT_OFFSET_M = 0.85

# Low-water height offset is not yet measured. Left at 0.0 (raw Tarbert value)
# and flagged rather than guessed; refine with the coaches / gauge data.
DEFAULT_LOW_HEIGHT_OFFSET_M = 0.0


def parse_extremes(payload: dict) -> list[TideExtreme]:
    """Turn a WorldTides v3 `extremes` payload into TideExtreme objects.

    Uses the `dt` unix timestamp (UTC) as the source of truth for the time.
    """
    extremes: list[TideExtreme] = []
    for item in payload.get("extremes", []):
        extremes.append(
            TideExtreme(
                kind=item["type"],  # "High" | "Low"
                time_utc=datetime.fromtimestamp(item["dt"], tz=timezone.utc),
                height_m=float(item["height"]),
            )
        )
    return extremes


def apply_limerick_calibration(
    extremes: list[TideExtreme],
    *,
    time_offset: timedelta = DEFAULT_TIME_OFFSET,
    high_height_offset_m: float = DEFAULT_HIGH_HEIGHT_OFFSET_M,
    low_height_offset_m: float = DEFAULT_LOW_HEIGHT_OFFSET_M,
) -> list[TideExtreme]:
    """Shift Tarbert extremes to Limerick Dock using the calibration offsets."""
    calibrated: list[TideExtreme] = []
    for e in extremes:
        height_offset = (
            high_height_offset_m if e.kind == "High" else low_height_offset_m
        )
        calibrated.append(
            TideExtreme(
                kind=e.kind,
                time_utc=e.time_utc + time_offset,
                height_m=e.height_m + height_offset,
            )
        )
    return calibrated
