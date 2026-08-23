# Water release (Parteen Weir / Ardnacrusha) service

Fetches the hard **water-release override** for the row/no-row decision: if
ESB is discharging at Parteen Weir — the last weir before the club's launch
point — rowing is not possible, full stop. See
`../../Scaffolding/Planning_and_Ideation/Data_needed_for_rowing_safety_decision.md`.

## Source

ESB publishes this as **PDFs, not an API**, linked from its hydrometric page
(`https://esb.ie/what-we-do/generation-and-trading/hydrometric-information`).
**Plain HTTP only** — `esbhydro.ie` has no HTTPS listener on port 443
(confirmed by a direct connection test) — so requests are made over `http://`
deliberately, not as an oversight. No API key.

| PDF | What it is | Role |
| --- | --- | --- |
| `01-Shannon-Hydro-Forecast.pdf` | 5-page prose, ~5-day forecast | **Primary** per the planning doc — the "Discharge at Parteen Weir" sentence |
| `07-Total-Ardnacrusha-Flow.pdf` | Clean table: current reading + 30-day history | **Secondary/corroborating** — total flow through the power station |
| `08-Total-Parteen-Weir-Flow.pdf` | Same table shape as #07, but at Parteen Weir itself | Not in the original planning doc — found while building this; a direct numeric reading at the exact location that matters |

**A real tension worth stating plainly:** the planning doc calls #1
"primary" and #7 "secondary," but #1 is fragile prose and #7/#8 are clean
tables. See "Known limitation" below — this service does not resolve that
tension (no thresholding/weighting logic here; that belongs to the not-yet-built
`../../backend`, per the note below).

## Known limitation: the discharge classifier can only ever recognise ONE phrasing

ESB overwrites this PDF in place, so the live URL only ever shows today's
wording. Fifteen real forecasts have now been captured — today's plus fourteen
Internet Archive snapshots of the same URL spanning 2017-2026, which is the
only way to observe the wording used on a day Parteen Weir *is* discharging.
See `tests/fixtures/README.md` for provenance. Across those, ESB words the
statement five ways:

| Wording | Meaning |
| --- | --- |
| "no additional discharge **will be** necessary" (2024-) | clear |
| "there will be **no additional discharge necessary**" (2017-2023) | clear |
| "a discharge **of between** 55m3/s and 95 m3/s will be necessary" | discharging |
| "a discharge **ranging between** 55 and 170m3/s will be necessary" | discharging |
| "a discharge of between **95 and 55**m3/s will be necessary" (descending) | discharging |

`discharge_classification` therefore has three values:

- `no_discharge_expected` — either "clear" phrasing matched.
- `discharge_expected` — a discharge range matched; `expected_discharge_min_m3s`
  / `expected_discharge_max_m3s` carry it, ordered so min is the smaller even
  when ESB writes the range descending.
- `unparsed` — wording matching none of the above. The raw sentence is always
  stored verbatim regardless, for a human to read.

Classification reads only ESB's **forward-looking clause** ("It is expected
that … based on current weather forecast"). One captured forecast opens with a
past fact — "Additional discharge of 50m3/s at Parteen Weir ceased as of this
morning." — which must not be read as a live discharge.

`unparsed` remains the deliberate never-guess state: wording ESB has not been
observed to use is never read as "clear". Since all fifteen captured forecasts
classify, a live `unparsed` means genuinely new wording, and the canary test
fails on it rather than letting the app quietly degrade to "Unknown".

## Firestore shape

One **evolving document** (not per-day, unlike tide/weather — there's no
natural "forecast day" here, and the flow PDFs already carry their own 30-day
trailing window on every fetch):

```
water_release_status/current
  source, fetched_at
  parteen_forecast:
    date_of_prediction, discharge_statement_raw, discharge_classification,
    expected_discharge_min_m3s, expected_discharge_max_m3s,
    planning_assumption_raw, planning_assumption_min_m3s, planning_assumption_max_m3s,
    source_url
  ardnacrusha_flow:   { label, current_value_m3s, current_reading_at, units,
                         readings: [{reading_at, value_m3s}, ...], source_url }
  parteen_weir_flow:  { same shape as ardnacrusha_flow }
```

## Files

- `models.py` — `FlowReading`, `FlowSeries`, `ParteenForecast` (pure, no deps).
- `esbhydro_client.py` — HTTP (plain `http://`) + pdfplumber extraction, split
  from parsing so the rest of the service is testable without the network.
- `parse.py` — `parse_forecast()` / `parse_flow_table()`: extracted text/rows →
  domain types (pure).
- `firestore_docs.py` — `build_document()`: the Firestore envelope (pure).
- `main.py` — `fetch_water_release_status()` + CLI.
- `function.py` — Cloud Function entry; writes `water_release_status/current`.

## Run

```sh
python functions/water_release/main.py
```

No secret to source — these are public PDFs.

## Test

```sh
# Offline (fixtures only, no network) — captured real PDF bytes / extracted
# text under tests/fixtures/, fetched from esbhydro.ie on 2026-08-09.
python -m unittest discover -s functions/water_release/tests

# Live canary (opt-in — no key needed here, unlike WorldTides/OpenWeather, so
# this gates on an explicit env var rather than credential presence):
RUN_LIVE_CANARY=1 python -m unittest functions.water_release.tests.test_live_canary
```

## Open risks

- **PDF layout stability** — page order/count, table structure, and the exact
  "Date of Prediction" label format are only confirmed against the one
  real fetch this service was built against; ESB could change any of it
  without notice.
- **Timestamp timezone** — the flow tables' `09:00:00` reading times are
  assumed Europe/Dublin local; not confirmed with ESB documentation.
- **PDF #1's own refresh cadence** is uncertain — fetched 9 Aug, dated 7 Aug —
  so it does not necessarily reissue daily even though #7/#8 do.
