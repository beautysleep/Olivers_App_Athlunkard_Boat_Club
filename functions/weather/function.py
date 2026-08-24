"""Triggered on a schedule over HTTP by Cloud Scheduler. The OpenWeather key
arrives in an environment variable injected from Secret Manager.
"""

from __future__ import annotations

from datetime import datetime, timezone

from google.cloud import firestore

from firestore_docs import build_documents
from main import fetch_club_weather

COLLECTION = "weather_forecasts"


def store_forecast(client: firestore.Client) -> int:
    """Fetch the daily + hourly forecast and upsert one doc per local day.

    Returns the number of day-documents written.
    """
    daily, hourly = fetch_club_weather()
    documents = build_documents(daily, hourly, fetched_at=datetime.now(timezone.utc))

    batch = client.batch()
    for date_str, document in documents.items():
        batch.set(client.collection(COLLECTION).document(date_str), document)
    batch.commit()
    return len(documents)


def fetch_weather(request):
    """HTTP entry point (Cloud Functions gen2 / functions-framework)."""
    written = store_forecast(firestore.Client())
    return (f"Stored {written} day(s) of weather forecast.\n", 200)
