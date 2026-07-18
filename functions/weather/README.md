# Weather service

Fetches **wind** and **rainfall** for Limerick / Athlunkard and feeds the
volatile, near-term (Tier-2 confirmation) side of the row / no-row decision. See
`../../Scaffolding/Planning_and_Ideation/Data_needed_for_rowing_safety_decision.md`.

## Source

OpenWeather **One Call 4.0** timeline endpoints (the account is on the *One Call
by Call* plan; One Call 3.0 returns 401):

| Endpoint | Use |
| --- | --- |
| `/timeline/1day` | Daily aggregate — ~10 days in one call. Tier-1 planning. |
| `/timeline/1h` | Hourly, paginated forward to **48h**. Tier-2 confirmation / the ≥1.5h wind-window search. |

- Wind is stored in **m/s** (provider-native SI); the decision layer converts to
  km/h to apply the thresholds.
- Rain is per-slot **mm** (absent when dry → 0). `wind_gust` and `pop` are
  **nullable** — One Call 4.0 daily records omit them.

> **Key safety:** One Call 4.0 echoes the API key inside the `prev`/`next`
> pagination URLs. `openweather_client.py` drops those on arrival, paginates via
> its own `start` param, and never logs raw responses. Do not print raw payloads.

## Firestore shape

One document per **local (Europe/Dublin) day** in `weather_forecasts`, keyed by
date so the app reads a calendar day directly:

```
weather_forecasts/2026-07-20
  date, source, fetched_at
  daily:  { wind_speed_ms, wind_gust_ms, rain_mm, pop }
  hourly: [ { time_utc, wind_speed_ms, wind_gust_ms, rain_mm, pop }, ... ]   # empty beyond 48h
```

## Files

- `models.py` — `WeatherPoint` (pure, no deps).
- `parse.py` — `parse_points()`: 4.0 timeline JSON → WeatherPoints (pure).
- `firestore_docs.py` — `build_documents()`: per-local-day docs (pure).
- `openweather_client.py` — HTTP + pagination (`requests`).
- `main.py` — `fetch_club_weather()` + CLI (prints derived data only).
- `function.py` — Cloud Function entry; writes `weather_forecasts`.

## Run

```sh
export OPENWEATHER_API_KEY=...   # see ../README.md "Local secrets"; never commit
python functions/weather/main.py
```

## Test (offline, no key/network)

```sh
python -m unittest discover -s functions/weather/tests
```

Tests run against **captured real** One Call 4.0 responses under `tests/fixtures/`
(key scrubbed). A live *contract/canary* test is planned from the next data
source on.
