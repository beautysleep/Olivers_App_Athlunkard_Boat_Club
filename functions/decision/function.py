"""Triggered on a schedule over HTTP by Cloud Scheduler. No API key needed: the
inputs are the three collections the other services already write, so this one
reads Firestore rather than the outside world.
"""

from __future__ import annotations

from datetime import datetime, timezone

from google.cloud import firestore

from main import COLLECTION, rate_all_days


def store_ratings(client: firestore.Client) -> int:
    tide = {d.id: d.to_dict() for d in client.collection("tide_predictions").stream()}
    weather = {
        d.id: d.to_dict() for d in client.collection("weather_forecasts").stream()
    }
    water_release = (
        client.collection("water_release_status").document("current").get().to_dict()
    )

    documents = rate_all_days(
        tide, weather, water_release, computed_at=datetime.now(timezone.utc)
    )

    batch = client.batch()
    for date_str, document in documents.items():
        batch.set(client.collection(COLLECTION).document(date_str), document)
    batch.commit()
    return len(documents)


def rate_days(request):
    """HTTP entry point (Cloud Functions gen2 / functions-framework)."""
    written = store_ratings(firestore.Client())
    return (f"Rated {written} day(s).\n", 200)
