"""Cloud Function entry point: fetch Athlunkard weather and store it.

Triggered on a schedule (HTTP) by Cloud Scheduler. Reads the OpenWeather key from
an env var injected from Secret Manager, and writes one document per local day to
the `weather_forecasts` collection. All the non-trivial logic lives in the pure,
unit-tested modules; this file is just the I/O wiring (mirrors the tide service).
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
