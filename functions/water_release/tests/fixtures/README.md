# Water-release test fixtures — provenance

Every file here is **captured real ESB output**. Nothing is hand-written or
invented. This file records exactly where each came from so any assertion can be
traced back to something ESB actually published.

## Fetched directly from esbhydro.ie (2026-08-09)

| File | Source |
| --- | --- |
| `01-Shannon-Hydro-Forecast.pdf` | `http://www.esbhydro.ie/Shannon/01-Shannon-Hydro-Forecast.pdf` |
| `07-Total-Ardnacrusha-Flow.pdf` | `http://www.esbhydro.ie/Shannon/07-Total-Ardnacrusha-Flow.pdf` |
| `08-Total-Parteen-Weir-Flow.pdf` | `http://www.esbhydro.ie/Shannon/08-Total-Parteen-Weir-Flow.pdf` |
| `shannon_hydro_forecast.txt` | `pdfplumber` text extraction of the `01` PDF above |
| `ardnacrusha_flow_extracted.json` | `esbhydro_client._extract_flow_table()` output for the `07` PDF |
| `parteen_weir_flow_extracted.json` | `esbhydro_client._extract_flow_table()` output for the `08` PDF |

## Retrieved from the Internet Archive (2026-08-23)

ESB overwrites `01-Shannon-Hydro-Forecast.pdf` in place, so the only way to
observe how the Parteen Weir discharge statement is worded on a day it is
*actually discharging* is the Internet Archive's snapshots of that same URL.
Fourteen distinct snapshots exist (2017–2026); these five cover every distinct
phrasing among them. Each was fetched with the `id_` modifier, which returns the
original bytes rather than a rewritten page:

`http://web.archive.org/web/<timestamp>id_/http://www.esbhydro.ie/Shannon/01-Shannon-Hydro-Forecast.pdf`

| File | Snapshot timestamp | Why it is here |
| --- | --- | --- |
| `shannon_hydro_forecast_no_discharge_older_phrasing_2020-10-27.txt` | `20201028083406` | The older no-discharge wording: "there will be **no additional discharge necessary**" |
| `shannon_hydro_forecast_discharge_ceased_then_none_2017-11-02.txt` | `20171104033118` | A past-discharge sentence ("ceased as of this morning") preceding a no-discharge expectation |
| `shannon_hydro_forecast_discharging_of_between_2020-11-09.txt` | `20201111212724` | Discharging: "a discharge **of between** 55m3/s and 95 m3/s" |
| `shannon_hydro_forecast_discharging_ranging_between_2022-11-03.txt` | `20221106080727` | Discharging: "a discharge **ranging between** 55 and 170m3/s" |
| `shannon_hydro_forecast_discharging_descending_range_2024-02-24.txt` | `20240225112427` | Discharging with a **descending** range: "between 95 and 55m3/s" |

The `.txt` files are `pdfplumber` text extractions of those archived PDFs,
produced by the same `esbhydro_client._extract_forecast_text()` step the live
service uses. The archived PDFs themselves are not committed — they are large
and the extracted text is what `parse.py` actually consumes.

Two `Date of Prediction:` formats appear across these snapshots and are both
covered by the parser: `02 November 2017` (2017–2024) and
`Friday 16 January 2026` (2026 onwards, with the weekday).
