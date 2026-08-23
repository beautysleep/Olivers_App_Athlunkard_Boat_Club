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

Scrapes and parses the ESB hydrometric PDFs (there is no API, and no HTTPS
either — `esbhydro.ie` serves plain HTTP only):

- **Primary signal — Parteen Weir discharge forecast.**
  `01-Shannon-Hydro-Forecast.pdf` carries a prose ~5-day forecast; Parteen Weir
  is the last weir before the club's launch point, so its discharge is the
  dominant indicator. Discharging ⇒ no rowing. In practice this is fragile
  prose-parsing — ESB words the statement five different ways across the
  fifteen real forecasts captured so far (2017–2026, via the Internet Archive),
  all covered; unrecognised wording is classified "unparsed" rather than
  guessed as clear. See `water_release/README.md`.
- **Secondary signal — total Ardnacrusha flow.** `07-Total-Ardnacrusha-Flow.pdf`;
  below roughly 300 m³/s is fine. Corroborating, not deciding. Turned out to be
  a clean structured table, not prose.
- **Also captured — total Parteen Weir flow.** `08-Total-Parteen-Weir-Flow.pdf`
  — not in the original planning doc; found while building this job. Same clean
  table shape as #07, but a direct current numeric reading at Parteen Weir
  itself, arguably a more robust signal than the primary prose forecast.

All three are linked from the ESB hydrometric page. See
`../Scaffolding/Planning_and_Ideation/Data_needed_for_rowing_safety_decision.md`
and `water_release/README.md` for the full detail, including the classifier's
known limitation.

## A note on shared code

Sharing code across separately packaged Cloud Functions is awkward, so `shared/`
is kept intentionally small. If real shared logic emerges, we will extract it then
rather than forcing the structure up front.

## Local secrets (API keys)

Each job that calls an external API needs a key when run locally. Keep **all**
local keys in a single file **outside any repo or git worktree** — e.g.
`~/.abc_secrets.env`:

```sh
export WORLDTIDES_API_KEY=...
export OPENWEATHER_API_KEY=...
```

then `source ~/.abc_secrets.env` once per shell before running a job or its
tests. One place, never sitting next to git, and — crucially — it survives every
git worktree, whereas a gitignored in-repo `.env` does **not** follow you into a
new worktree. In production the Cloud Function reads each key from **GCP Secret
Manager**, never from a file.

## Not generated yet

Each job's `main.py` and `requirements.txt` are added when we build that job.
