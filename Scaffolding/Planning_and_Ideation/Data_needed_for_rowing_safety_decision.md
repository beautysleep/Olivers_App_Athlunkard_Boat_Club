# Data Needed for the Rowing Safety Decision

There is no off-the-shelf service that answers "is it safe to row here today?" —
that absence is the whole reason this project exists. This document defines the
inputs we use to make that call ourselves, where each comes from, how often it
refreshes, and how it maps to the green / amber / red rating shown to users.

> **Source confirmed (2026-06-24):** the controlling facility is the ESB
> **Ardnacrusha** hydro scheme on the Shannon, but the signal that actually
> matters for Athlunkard is the discharge at **Parteen Weir** — the last weir
> upstream of the club's launching point. ESB publishes the data as **PDFs**
> (not Excel, as earlier drafts assumed) linked from its hydrometric page:
> <https://esb.ie/what-we-do/generation-and-trading/hydrometric-information>.

---

## The core metrics

Four primary metrics drive the routine decision:

1. **Wind speed** — high wind makes rowing unsafe/unworkable.
2. **Tide height** — affects whether and where rowing is possible.
3. **Tide time** — *when* high tide occurs determines the usable rowing window on
   a given day.
4. **Rainfall**, considered in three forms:
   - Rain **at the prospective rowing time**.
   - **Cumulative rainfall over the last 24 hours.**
   - **Cumulative rainfall over the last 72 hours.**
   (Recent cumulative rain matters because it affects river state, not just
   conditions in the moment — hence collecting rainfall over time rather than a
   single snapshot.)

## The overriding constraints

Two factors can override an otherwise-good assessment. If either fails, it does
not matter how good the other metrics are.

### A. Upstream water release (hard override)

The ESB **Ardnacrusha** hydro scheme controls flow on the lower Shannon above the
club. When water is being released, **rowing is not possible** — this overrules
every other metric. There is **no API**; ESB publishes the data as **PDFs** linked
from its hydrometric page, which we **scrape** on each check.

Two documents matter, in priority order:

1. **Parteen Weir discharge forecast — the primary, dominant signal.**
   `01-Shannon-Hydro-Forecast.pdf`
   (e.g. <http://www.esbhydro.ie/Shannon/01-Shannon-Hydro-Forecast.pdf>) contains
   a prose forecast such as:

   > *"It is expected that no additional discharge will be necessary at Parteen
   > Weir over the next 5 days based on current weather forecast."*

   Parteen Weir is the **last weir before the Athlunkard launching point**, so
   whether it is discharging is the highest-signal indicator of safe/unsafe
   conditions. This forecast looks ahead roughly **5 days**. We must parse the PDF
   text to extract the Parteen Weir discharge statement and store it.

2. **Total Ardnacrusha flow — a secondary, corroborating signal.**
   `07-Total-Ardnacrusha-Flow.pdf`
   (e.g. <http://www.esbhydro.ie/Shannon/07-Total-Ardnacrusha-Flow.pdf>) gives
   total flow through Ardnacrusha. Rule of thumb from experience on the river:
   **below ~300 m³/s is fine.** This *correlates* with conditions but is **not
   identical** to the Parteen signal — treat it as supporting evidence, not the
   deciding factor.

> For the initial prototype, capture the rest of the information in these PDFs as
> well — not just the two values above — since it is cheap to store and may prove
> useful once we see real data.

### B. Daylight (hard override)

It must be **bright enough to row**. If high tide falls at night, the window is
useless. So sunrise/sunset bounds every candidate window — a session can only be
proposed within daylight hours.

---

## Data sources

| Input | Source type | Notes |
| --- | --- | --- |
| Wind speed | Weather API | Also used to accumulate context over time |
| Rainfall (at time + 24h + 72h cumulative) | Weather API | Collected over time to compute cumulative totals |
| Tide time & height | Tide API | Predictable well ahead |
| Sunrise / sunset | Sunrise–sunset API | Bounds usable daylight window |
| Parteen Weir discharge forecast (primary) | **PDF scrape** — `01-Shannon-Hydro-Forecast.pdf` | Prose ~5-day forecast; no API |
| Total Ardnacrusha flow (secondary) | **PDF scrape** — `07-Total-Ardnacrusha-Flow.pdf` | < ~300 m³/s ≈ fine; corroborating only |

---

## Refresh cadence

Each source refreshes at its own rate, reflecting how far ahead it stays
accurate. (This is the basis for the two-tier model in
`Architectural_Key_Components.md`.)

| Input | Refresh rate | Why |
| --- | --- | --- |
| Parteen / Ardnacrusha PDFs | **Once daily** | The published PDFs only update that often |
| Sunrise / sunset | **Daily**, fetching ~next 30 days | Very stable |
| Tide time / height | **Periodic / stable** | Predictable far in advance |
| Wind | **Frequent**, but not for sessions >7 days out | Forecast is inaccurate beyond ~7 days |
| Rainfall | **Frequent**, limited horizon | Same accuracy limits as wind |

---

## Two-tier evaluation

Because the inputs differ in how far ahead they're reliable, the decision is
formed in two stages:

- **Tier 1 — planning (stable inputs):** tide times and sunrise/sunset establish
  that a session *might* be possible on a future day — far enough out that the
  coach can start collecting commitments. (There's no value in good conditions if
  nobody is available, so early proposal matters.)
- **Tier 2 — confirmation (volatile inputs):** as the day nears, wind and
  rainfall are re-checked. If they degrade, the coach is notified to decide
  whether to cancel or pivot to land training. A two-week-out forecast can be
  wrong by three days out — re-evaluation handles that.

---

## Mapping conditions to the rating

The metrics combine into the colour shown on the calendar. The override
constraints can force **red** regardless of everything else.

| Rating | Meaning |
| --- | --- |
| 🟢 **Green** | Conditions good — any type of boat could go out. |
| 🟠 **Amber** | Not perfect, but good enough — larger boats / more experienced crews only. |
| 🔴 **Red** | Not rowable. **Forced red** if Parteen Weir is discharging (per the forecast PDF), or if the only suitable tide window falls outside daylight. |

> **To be defined with the coaches:** the exact numeric thresholds — e.g. the
> wind speed cut-offs separating green/amber/red, acceptable tide-height range,
> and the cumulative-rainfall limits over 24h/72h. These are deliberately left as
> tunable parameters; capture the real-world values from the coaches rather than
> hard-coding guesses.

---

## Provisional thresholds & session-window logic

> **Status: provisional (added 2026-07-18).** Working values to build and test
> against — **not yet confirmed with the coaches.** Kept as tunable parameters,
> never hard-coded; supersede once the coaches give real figures.

The routine (non-override) decision is **windowed**, not a daily snapshot. Within
a day's tide-high + daylight window, find the **longest contiguous interval of at
least 1.5 hours in which wind stays below threshold for the whole interval** —
that interval is the session time recommended to the user. The same windowing is
applied to rainfall. (Example: tide high 06:00–10:00 but wind acceptable only
07:30–09:00 → recommend 07:30–09:00.)

| Metric | Big boats | All boats |
| --- | --- | --- |
| Wind (sustained) | 30 km/h | 20 km/h |
| Rain (at prospective time) | 15 mm | 5 mm |
| Cumulative rain — last 24 h | 100 mm | 100 mm |
| Cumulative rain — last 48 h | 150 mm | 150 mm |
| Cumulative rain — last 72 h | 150 mm | 150 mm |

"Big boats" tolerate more than "all boats" (the all-boats figure is the stricter
gate). The 48 h cumulative band is additional to the 24 h / 72 h bands named
above.

**Forecast resolution.** The windowing needs intraday detail. The weather API
gives **hourly** wind/rain to ~48 h and **daily** beyond that, so near-term
windows are evaluated on the hour. For days beyond 48 h we take the pragmatic
assumption of **constant hourly wind/rain across the day** (that day's single
forecast figure) — enough for Tier-1 planning, since those days are re-checked at
hourly resolution once they enter the 48 h horizon.

---

## Open items to confirm before building

- ~~Dam name / source URL~~ — **confirmed:** ESB Ardnacrusha; signal is Parteen
  Weir discharge; PDFs linked from the ESB hydrometric page (see top of file).
- Specific weather, tide, and sunrise/sunset API providers and their limits.
- Numeric thresholds for each metric, per the table above (and confirm the
  ~300 m³/s Ardnacrusha-flow rule of thumb with the coaches).
- Stability of the ESB PDF layout (filenames, wording of the Parteen forecast
  sentence) to make text parsing robust — and a fallback if the wording changes.
