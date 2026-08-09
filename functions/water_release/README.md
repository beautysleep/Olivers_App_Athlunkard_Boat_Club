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

Only one real example of the "Discharge at Parteen Weir" sentence has ever
been captured (fetched 2026-08-09):

> "It is expected that no additional discharge will be necessary at Parteen
> Weir over the next 5 days based on current weather forecast."

There is **no captured example of the wording ESB uses when Parteen Weir *is*
discharging**. Rather than guess a pattern for text nobody has seen,
`discharge_classification` has exactly two values:

- `no_discharge_expected` — the one observed phrasing matched.
- `unparsed` — anything else, including a real "discharging" statement. The
  raw sentence is always stored verbatim regardless, for a human to read.

**Consequence: this service can never positively assert "danger" from PDF #1
alone.** That's a real gap, not hidden — if ESB's wording changes (including to
announce an actual discharge), it degrades to `unparsed`, not a false "clear."
Fix requires capturing a real example of the alternate wording first.

## Firestore shape

One **evolving document** (not per-day, unlike tide/weather — there's no
natural "forecast day" here, and the flow PDFs already carry their own 30-day
trailing window on every fetch):

```
water_release_status/current
  source, fetched_at
  parteen_forecast:
    date_of_prediction, discharge_statement_raw, discharge_classification,
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
