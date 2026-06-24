# Data Needed for the Rowing Safety Decision

There is no off-the-shelf service that answers "is it safe to row here today?" —
that absence is the whole reason this project exists. This document defines the
inputs we use to make that call ourselves, where each comes from, how often it
refreshes, and how it maps to the green / amber / red rating shown to users.

> **Naming note to verify:** the upstream dam is referred to here as
> **Inniscarra Dam** based on the conversation. Please confirm the exact dam name
> and the URL of its published release schedule before implementation.

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

### A. Upstream dam water release (hard override)

**Inniscarra Dam** sits upstream of the club. When the dam is releasing water,
**rowing is not possible** — this overrules every other metric. There is **no
API** for this. The dam operator publishes a consistent daily **Excel file** to
their website stating the release rate over the coming days. We therefore
**scrape that website** on each check to retrieve the latest schedule, which
supports forecasting roughly **7 days** ahead.

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
| Dam release schedule | **Web scrape** of operator's site | Daily Excel upload; no API available |

---

## Refresh cadence

Each source refreshes at its own rate, reflecting how far ahead it stays
accurate. (This is the basis for the two-tier model in
`Architectural_Key_Components.md`.)

| Input | Refresh rate | Why |
| --- | --- | --- |
| Dam release schedule | **Once daily** | The published data only updates that often |
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
| 🔴 **Red** | Not rowable. **Forced red** if the dam is releasing water, or if the only suitable tide window falls outside daylight. |

> **To be defined with the coaches:** the exact numeric thresholds — e.g. the
> wind speed cut-offs separating green/amber/red, acceptable tide-height range,
> and the cumulative-rainfall limits over 24h/72h. These are deliberately left as
> tunable parameters; capture the real-world values from the coaches rather than
> hard-coding guesses.

---

## Open items to confirm before building

- Exact name and published-schedule URL for the upstream dam (assumed Inniscarra).
- Specific weather, tide, and sunrise/sunset API providers and their limits.
- Numeric thresholds for each metric, per the table above.
- Format/stability of the dam's daily Excel file (column layout) to make scraping
  robust.
