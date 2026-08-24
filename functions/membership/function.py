"""HTTPS entry point for signup. Unlike the four scheduled services this one is
called by the app, so it is the only publicly-invokable function in the project.

Its gate is two-part: a Firebase ID token proving the caller just created an
account, and an invite code proving they belong to the club. Neither alone is
enough — the token says who you are, the code says you were let in.
"""

from __future__ import annotations

import json

import firebase_admin
from firebase_admin import auth, firestore

from membership import UnknownInviteCode, build_member_document, role_for_code
from request import MalformedClaim, read_claim

MEMBERS = "users"
INVITE_CODES = "invite_codes"

firebase_admin.initialize_app()


def _uid_from_authorization(header: str | None) -> str:
    if not header or not header.startswith("Bearer "):
        raise auth.InvalidIdTokenError("no bearer token", cause=None)
    return auth.verify_id_token(header.removeprefix("Bearer "))["uid"]


def claim_membership(request):
    try:
        uid = _uid_from_authorization(request.headers.get("Authorization"))
    except Exception:
        return ("Sign in first.\n", 401)

    try:
        claim = read_claim(request.get_json(silent=True))
    except MalformedClaim:
        return ("A name and an invite code are both needed.\n", 400)

    client = firestore.client()

    def find_code(code: str) -> dict | None:
        document = client.collection(INVITE_CODES).document(code).get()
        return document.to_dict() if document.exists else None

    try:
        role = role_for_code(claim.invite_code, find_code)
    except UnknownInviteCode:
        return ("That invite code is not one of ours.\n", 403)

    member = build_member_document(
        uid=uid,
        email=auth.get_user(uid).email or "",
        display_name=claim.display_name,
        role=role,
        child_uid=claim.child_uid,
    )

    # The claim is what Firestore rules read, so it must be set before the app
    # is told it succeeded. The document is what the app displays.
    auth.set_custom_user_claims(uid, {"role": role})
    client.collection(MEMBERS).document(uid).set(member)

    return (json.dumps({"role": role}), 200, {"Content-Type": "application/json"})
