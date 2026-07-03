"""Domain types for the tide service.

Kept free of any HTTP/library dependency so the parsing and calibration logic
can be unit-tested without a network call or an API key.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from zoneinfo import ZoneInfo

# The club's local timezone. Using the IANA zone (not a fixed offset) means
# Irish Summer Time / GMT — i.e. daylight-saving — is handled automatically.
CLUB_TZ = ZoneInfo("Europe/Dublin")


@dataclass(frozen=True)
class TideExtreme:
    """A single predicted high- or low-water event.

    The time is stored as a UTC instant (unambiguous); local time is derived on
    demand so daylight-saving is always applied correctly for the display.
    """

    kind: str  # "High" or "Low"
    time_utc: datetime  # timezone-aware, UTC
    height_m: float  # metres, referenced to the response datum

    @property
    def time_local(self) -> datetime:
        """The event in the club's local time (Europe/Dublin, DST-aware)."""
        return self.time_utc.astimezone(CLUB_TZ)

    def to_dict(self) -> dict:
        return {
            "kind": self.kind,
            "time_utc": self.time_utc.isoformat(),
            "time_local": self.time_local.isoformat(),
            "height_m": round(self.height_m, 3),
        }
