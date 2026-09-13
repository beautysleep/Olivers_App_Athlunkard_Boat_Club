"""Reading a session request off the wire, apart from acting on it, so the
refusals are testable without a Firebase user, Firestore, or a network call.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from models import RATINGS


class MalformedRequest(Exception):
    """The request did not carry what this action needs."""


def _parse_time(raw: object) -> datetime | None:
    """Dart sends `.toUtc().toIso8601String()` — a trailing "Z" fromisoformat
    (3.11+) reads as timezone-aware UTC, which Firestore's client accepts
    directly. A naive datetime here would be a silent bug, not a refusal, so
    the caller is left to check for None."""
    if not isinstance(raw, str) or not raw:
        return None
    try:
        return datetime.fromisoformat(raw)
    except ValueError:
        return None


@dataclass(frozen=True)
class ProposalRequest:
    meeting_time: datetime
    high_tide_time: datetime
    condition_rating: str


def read_proposal_request(body: dict | None) -> ProposalRequest:
    body = body or {}
    meeting_time = _parse_time(body.get("meeting_time"))
    high_tide_time = _parse_time(body.get("high_tide_time"))
    condition_rating = body.get("condition_rating")
    if meeting_time is None or high_tide_time is None:
        raise MalformedRequest()
    if condition_rating not in RATINGS:
        raise MalformedRequest()
    return ProposalRequest(
        meeting_time=meeting_time,
        high_tide_time=high_tide_time,
        condition_rating=condition_rating,
    )


@dataclass(frozen=True)
class ResponseRequest:
    session_id: str
    accept: bool


def read_response_request(body: dict | None) -> ResponseRequest:
    body = body or {}
    session_id = body.get("session_id")
    accept = body.get("accept")
    if not session_id or not isinstance(accept, bool):
        raise MalformedRequest()
    return ResponseRequest(session_id=session_id, accept=accept)


@dataclass(frozen=True)
class CancelRequest:
    session_id: str
    pivot_to_land: bool


def read_cancel_request(body: dict | None) -> CancelRequest:
    body = body or {}
    session_id = body.get("session_id")
    pivot_to_land = body.get("pivot_to_land")
    if not session_id or not isinstance(pivot_to_land, bool):
        raise MalformedRequest()
    return CancelRequest(session_id=session_id, pivot_to_land=pivot_to_land)


@dataclass(frozen=True)
class DeviceTokenRequest:
    token: str


def read_device_token_request(body: dict | None) -> DeviceTokenRequest:
    token = (body or {}).get("token", "").strip()
    if not token:
        raise MalformedRequest()
    return DeviceTokenRequest(token=token)
