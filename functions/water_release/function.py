"""Triggered on a schedule over HTTP by Cloud Scheduler. No API key needed —
these are public PDFs. See firestore_docs.py for why the document is
overwritten rather than accreted.
"""

from __future__ import annotations

from datetime import datetime, timezone

from google.cloud import firestore

from firestore_docs import build_document
from main import fetch_water_release_status

COLLECTION = "water_release_status"
DOCUMENT_ID = "current"


def store_status(client: firestore.Client) -> None:
    """Fetch water-release status from ESB and overwrite the current doc."""
    forecast, ardnacrusha_flow, parteen_weir_flow = fetch_water_release_status()
    document = build_document(
        forecast,
        ardnacrusha_flow,
        parteen_weir_flow,
        fetched_at=datetime.now(timezone.utc),
    )
    client.collection(COLLECTION).document(DOCUMENT_ID).set(document)


def fetch_water_release(request):
    """HTTP entry point (Cloud Functions gen2 / functions-framework)."""
    store_status(firestore.Client())
    return ("Stored water release status.\n", 200)
