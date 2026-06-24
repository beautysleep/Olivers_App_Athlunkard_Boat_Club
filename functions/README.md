# Functions (scheduled condition collection)

The automation that gathers the raw inputs for the row / no-row decision. Each
external data source is its own job, on its own schedule, triggered by Cloud
Scheduler and run as a Cloud Function. Every job writes what it collects back to
Firestore for the backend to read and rate.

These jobs **collect only**. They do not decide whether it is safe to row — that
single decision lives in `../backend` so the logic has one home.

## Jobs

```
weather/          Wind and rainfall. Frequent; meaningful only ~7 days ahead.
tide/             Tide times and heights. Stable, predictable far in advance.
sunrise_sunset/   Daylight bounds. Daily, fetching roughly the next 30 days.
water_release/    ESB Shannon PDF scrape — the hard override.
shared/           Small common helpers (Firestore client, condition data model).
```

### water_release — the hard override

Scrapes and parses the ESB hydrometric PDFs (there is no API):

- **Primary signal — Parteen Weir discharge.** `01-Shannon-Hydro-Forecast.pdf`
  carries a prose ~5-day forecast; Parteen Weir is the last weir before the club's
  launch point, so its discharge is the dominant indicator. Discharging ⇒ no
  rowing.
- **Secondary signal — total Ardnacrusha flow.** `07-Total-Ardnacrusha-Flow.pdf`;
  below roughly 300 m³/s is fine. Corroborating, not deciding.

Both are linked from the ESB hydrometric page. See
`../Scaffolding/Planning_and_Ideation/Data_needed_for_rowing_safety_decision.md`.

## A note on shared code

Sharing code across separately packaged Cloud Functions is awkward, so `shared/`
is kept intentionally small. If real shared logic emerges, we will extract it then
rather than forcing the structure up front.

## Not generated yet

Each job's `main.py` and `requirements.txt` are added when we build that job.
