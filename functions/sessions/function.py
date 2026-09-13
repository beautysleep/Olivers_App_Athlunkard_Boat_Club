"""HTTPS entry points the app calls for the session lifecycle: propose,
respond, cancel, and registering a device for push. Gated the same way
membership's signup endpoint is — a Firebase ID token proving who the caller
is — except here the token's role claim (already set at signup) decides what
they may do, so there is no second Firestore read just to find out.

Along with membership, these are the only publicly-invokable functions in
the project — the four condition-collecting/deciding jobs are
scheduler-only. The worst an abuser without a valid role achieves is a 403;
every write here is scoped to the caller's own verified identity, never to
whatever the request body claims.
"""

from __future__ import annotations

import json

import firebase_admin
from firebase_admin import auth, firestore, messaging

from documents import build_proposed_session_document
from models import ATHLETE, CANCELLED_OUTRIGHT, CANCELLED_WEATHER_PIVOT, COACH
from notifications import PROPOSAL_BODY, PROPOSAL_TITLE
from request import (
    MalformedRequest,
    read_cancel_request,
    read_device_token_request,
    read_proposal_request,
    read_response_request,
)

SESSIONS = "sessions"
USERS = "users"
DEVICE_TOKENS = "device_tokens"

firebase_admin.initialize_app()


def _claims_from_authorization(header: str | None) -> dict:
    if not header or not header.startswith("Bearer "):
        raise auth.InvalidIdTokenError("no bearer token", cause=None)
    return auth.verify_id_token(header.removeprefix("Bearer "))


def _push_proposal_to_every_athlete(client) -> None:
    """Best-effort: one unregistered token must not fail the write that
    already succeeded. There is no eventarc/Firestore-trigger precedent in
    this project yet, so this runs inline rather than decoupled — new
    trigger infrastructure for a feature with exactly one call site isn't
    worth the deployment risk."""
    athlete_uids = [
        doc.id for doc in client.collection(USERS).where("role", "==", ATHLETE).stream()
    ]
    for uid in athlete_uids:
        token_doc = client.collection(DEVICE_TOKENS).document(uid).get()
        token = (token_doc.to_dict() or {}).get("token") if token_doc.exists else None
        if not token:
            continue
        try:
            messaging.send(
                messaging.Message(
                    notification=messaging.Notification(
                        title=PROPOSAL_TITLE, body=PROPOSAL_BODY
                    ),
                    token=token,
                )
            )
        except Exception:
            continue


def propose_session(request):
    try:
        claims = _claims_from_authorization(request.headers.get("Authorization"))
    except Exception:
        return ("Sign in first.\n", 401)
    if claims.get("role") != COACH:
        return ("Only a coach can propose a session.\n", 403)

    try:
        proposal = read_proposal_request(request.get_json(silent=True))
    except MalformedRequest:
        return ("A meeting time, tide time, and rating are all needed.\n", 400)

    client = firestore.client()
    document = build_proposed_session_document(
        coach_id=claims["uid"],
        meeting_time=proposal.meeting_time,
        high_tide_time=proposal.high_tide_time,
        condition_rating=proposal.condition_rating,
    )
    _, ref = client.collection(SESSIONS).add(document)
    _push_proposal_to_every_athlete(client)

    return (json.dumps({"id": ref.id}), 200, {"Content-Type": "application/json"})


def respond_to_session(request):
    try:
        claims = _claims_from_authorization(request.headers.get("Authorization"))
    except Exception:
        return ("Sign in first.\n", 401)
    if claims.get("role") != ATHLETE:
        return ("Only an athlete can respond to a session.\n", 403)

    try:
        response = read_response_request(request.get_json(silent=True))
    except MalformedRequest:
        return ("A session id and a yes/no answer are both needed.\n", 400)

    ref = firestore.client().collection(SESSIONS).document(response.session_id)
    if not ref.get().exists:
        return ("That session does not exist.\n", 404)

    uid = claims["uid"]
    ref.update(
        {
            "committed_athlete_ids": (
                firestore.ArrayUnion([uid])
                if response.accept
                else firestore.ArrayRemove([uid])
            )
        }
    )

    return ("", 200)


def cancel_session(request):
    try:
        claims = _claims_from_authorization(request.headers.get("Authorization"))
    except Exception:
        return ("Sign in first.\n", 401)
    if claims.get("role") != COACH:
        return ("Only a coach can cancel a session.\n", 403)

    try:
        cancellation = read_cancel_request(request.get_json(silent=True))
    except MalformedRequest:
        return ("A session id and a pivot-or-not answer are both needed.\n", 400)

    ref = firestore.client().collection(SESSIONS).document(cancellation.session_id)
    if not ref.get().exists:
        return ("That session does not exist.\n", 404)

    ref.update(
        {
            "lifecycle": (
                CANCELLED_WEATHER_PIVOT
                if cancellation.pivot_to_land
                else CANCELLED_OUTRIGHT
            )
        }
    )

    return ("", 200)


def register_device_token(request):
    try:
        claims = _claims_from_authorization(request.headers.get("Authorization"))
    except Exception:
        return ("Sign in first.\n", 401)

    try:
        registration = read_device_token_request(request.get_json(silent=True))
    except MalformedRequest:
        return ("A token is needed.\n", 400)

    firestore.client().collection(DEVICE_TOKENS).document(claims["uid"]).set(
        {"token": registration.token}
    )
    return ("", 200)
