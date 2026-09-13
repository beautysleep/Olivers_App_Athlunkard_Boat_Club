"""Reading a signup request off the wire, apart from acting on it, so the
refusals are testable without a Firebase user or a network call.
"""

from __future__ import annotations

from dataclasses import dataclass


class MalformedClaim(Exception):
    """The request did not carry what a profile needs."""


@dataclass(frozen=True)
class ClaimRequest:
    invite_code: str
    display_name: str
    child_uid: str | None = None


def read_claim(body: dict | None) -> ClaimRequest:
    """Checked before the code is looked up, so a malformed request never
    reaches Firestore."""
    invite_code = (body or {}).get("invite_code", "").strip()
    display_name = (body or {}).get("display_name", "").strip()
    if not invite_code or not display_name:
        raise MalformedClaim()
    return ClaimRequest(
        invite_code=invite_code,
        display_name=display_name,
        child_uid=(body or {}).get("child_uid") or None,
    )
