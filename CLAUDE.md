# CLAUDE.md

Persistent context for this project. Read this first every session. Keep it
concise and current — if scope, stack, or conventions change, update this file.

## What this is

A cross-platform mobile app that removes the manual coordination burden of
organising on-water rowing sessions from the coach: it checks conditions
automatically, surfaces viable session days, runs the proposal → commitment →
confirmation → change loop, and notifies the right people when things change.

## Current status

Planning is complete; **no code exists yet**. The planning documents (see below)
are the agreed foundation. The next step is to plan project structure
conversationally before scaffolding.

## How to work with me (important)

I am using this project to learn, not just to get a finished result. Teach as you
go:

- Before writing code, explain the approach and the reasoning, and check it with
  me. Prefer a short conversational plan over jumping straight to implementation.
- When you make a non-obvious decision (a library, a data model, a tradeoff), say
  **why**, and name the alternatives you considered and rejected.
- Explain unfamiliar concepts, commands, and patterns in plain terms as they come
  up.
- Work in small, reviewable steps I can follow and understand — not large changes
  I can only accept or reject wholesale.
- When you run a command or install a tool, tell me what it does and why before
  or as you do it.

## Scope — hold the line

The whole point of v1 is to solve **one** pain well. Resist scope creep. If a
good idea is out of scope, note it for the backlog rather than building it.

**In scope for v1:**

- Automatic condition checks that rate upcoming days green / amber / red.
- Coach confirms a day and sends a proposal to athletes.
- Athletes are notified and accept / decline.
- Session confirms automatically once commitments reach the minimum (4); below
  that it shows "not yet possible".
- A confirmed session always has a coach who has committed to run it (incl.
  safety boat).
- If conditions later deteriorate, the system notifies the coach to decide:
  cancel, or pivot to land training — then auto-notifies committed athletes.
- Three roles: coach (primary), athlete (secondary), parent (tertiary).
- Simple auth (email / username / password). Push notifications.

**Explicitly OUT of scope for v1** (these live in
`Backlog_Hopper_of_Ideas_to_Consider_Implementing.md` — do not build without an
explicit decision):

- Attendance analytics / statistics.
- Crew matching and boat assignment.
- Variable headcount threshold by boat type.
- Event / regatta attendance management.
- Assistant-coach substitution.
- Any other club workflow.

## Tech stack

- **Mobile:** Flutter (single codebase → iOS + Android).
- **Backend:** Cloud Run (Python).
- **Database:** Firestore.
- **Notifications:** Firebase Cloud Messaging (FCM).
- **Condition-check jobs:** Cloud Scheduler → Cloud Functions.
- **Infrastructure:** Terraform — everything provisioned from code. **No manual
  clicking in the GCP console.**
- **Cloud:** Google Cloud Platform.

## Architecture — key points

- **Two-tier condition model.** Stable inputs (tide times, sunrise/sunset) drive
  the far-ahead *planning* view so the coach can propose early and collect
  commitments. Volatile inputs (wind, rainfall) are re-checked as a day nears for
  *confirmation*; forecasts only stay accurate ~7 days out.
- **Deterioration does not auto-cancel.** A re-check that detects worsening
  conditions notifies the coach and routes them to the existing cancel / pivot
  flow. The decision stays human; only detection and downstream notifications are
  automated. Do not add a separate cancellation path.
- Each external data source is its own scheduled service with its own refresh
  rate. See `Architectural_Key_Components.md`.

## The row / no-row decision

Four metrics: **wind speed, tide height, tide time, rainfall** (at the prospective
time, plus cumulative over 24h and 72h). Two **hard overrides** that beat
everything else:

1. **Upstream water release** — if water is being released, no rowing. No API.
   The deciding signal is **Parteen Weir** discharge (the last weir before the
   club's launch point), published by ESB **Ardnacrusha** as daily **PDFs** (not
   Excel) — primary: `01-Shannon-Hydro-Forecast.pdf` (prose ~5-day Parteen
   forecast); secondary/corroborating: `07-Total-Ardnacrusha-Flow.pdf`
   (< ~300 m³/s ≈ fine). Scrape + parse the PDF text. Linked from the ESB
   hydrometric page.
2. **Daylight** — must be light enough to row; sunrise/sunset bounds every window.

Exact numeric thresholds are **TBD with the coaches** — keep them as tunable
parameters, do not hard-code guesses. Full detail:
`Data_needed_for_rowing_safety_decision.md`.

## Personas (one line each)

- **Coach (primary):** proposes and manages sessions; the person we're relieving.
- **Athlete (secondary):** commits to sessions; sees who else is going.
- **Parent (tertiary):** notified when their child commits, to plan transport.

Detail in `Primary_Personas.md` and `Primary_User_Flows.md`.

## Project documents

| File | What it holds |
| --- | --- |
| `README.md` | Orientation and scope. |
| `Objective_of_project.md` | The single objective and the discipline behind it. |
| `Key_Results_of_project.md` | Measurable outcomes for v1. |
| `Primary_Personas.md` | Who we build for. |
| `Primary_User_Flows.md` | Step-by-step flows per role. |
| `Architectural_Key_Components.md` | Technical shape and how pieces connect. |
| `Data_needed_for_rowing_safety_decision.md` | Metrics, sources, thresholds, refresh logic. |
| `Backlog_Hopper_of_Ideas_to_Consider_Implementing.md` | Parked ideas, as user stories. |

## Guiding principles

- Ship one genuinely useful feature end-to-end, then learn from real use before
  building more. Scope discipline is a feature.
- Infrastructure as code; reproducible from this repo.
- Keep this file accurate as the project evolves.

## Commands

_To be filled in once the project is scaffolded (e.g. how to run the app, run
tests, deploy infrastructure). Add them here so every session knows them._
