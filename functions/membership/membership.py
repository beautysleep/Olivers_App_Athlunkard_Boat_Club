"""Who a signup turns into: an invite code decides the role, and the profile
document is what the app shows.

Pure — the caller supplies the code lookup — so every refusal is testable
without Firestore or a Firebase user.
"""

from __future__ import annotations

from typing import Callable

from models import PARENT, ROLES


class UnknownInviteCode(Exception):
    """Raised for any code we did not issue.

    Deliberately says nothing about which part was wrong: the caller is
    unauthenticated as far as club membership goes, and a code is a shared
    secret worth no hints.
    """


def role_for_code(code: str, find_code: Callable[[str], dict | None]) -> str:
    """Codes are matched whole and case-insensitively — people type them off a
    noticeboard, and a stray capital is not a reason to refuse someone."""
    document = find_code(code.strip().lower()) if code else None
    role = (document or {}).get("role")
    if role not in ROLES:
        raise UnknownInviteCode()
    return role


def build_member_document(
    *,
    uid: str,
    email: str,
    display_name: str,
    role: str,
    child_uid: str | None = None,
) -> dict:
    """[uid] is the document key, so it is not repeated inside. Only a parent
    carries a child, so a stray one on any other role is dropped rather than
    stored where nothing will ever read it."""
    if not display_name.strip():
        raise ValueError("a member needs a name to show beside their commitment")
    return {
        "display_name": display_name.strip(),
        "email": email,
        "role": role,
        "child_uid": child_uid if role == PARENT else None,
    }
