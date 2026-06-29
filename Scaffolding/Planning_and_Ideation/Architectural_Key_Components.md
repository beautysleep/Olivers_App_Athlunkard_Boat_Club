# Architectural Key Components

A cross-platform mobile app backed by services on Google Cloud Platform. The
guiding constraint: **everything is provisioned from code** — no manual clicking
in the GCP console. The whole environment should be reproducible from the
repository.

---

## High-level shape

```
            ┌──────────────────────────┐
            │   Flutter mobile app      │   iOS + Android, single codebase
            │   (coach / athlete /      │
            │    parent experiences)    │
            └───────────┬──────────────┘
                        │  HTTPS
            ┌───────────▼──────────────┐
            │   Backend API             │   Cloud Run (Python)
            │   auth, sessions,         │
            │   commitments, decisions  │
            └───────┬───────────┬───────┘
                    │           │
        ┌───────────▼──┐   ┌────▼─────────────┐
        │  Firestore    │   │ Firebase Cloud   │  push notifications
        │  users,       │   │ Messaging (FCM)  │  to phones
        │  sessions,    │   └──────────────────┘
        │  commitments  │
        └───────▲───────┘
                │ writes condition data / session viability
        ┌───────┴───────────────────────────┐
        │  Condition-check pipeline           │
        │  Cloud Scheduler → Cloud Functions  │  runs on schedule
        │  (weather, tide, sun, dam scrape)   │
        └─────────────────────────────────────┘
```

---

## Components

### Mobile app — Flutter

- One codebase deploys to both **iOS and Android**.
- Renders the three role-based experiences (coach / athlete / parent) described
  in `Primary_User_Flows.md`.
- Receives push notifications and prompts the user to enable them.
- Requires connectivity: it talks to the backend and relies on push delivery, so
  it is an online app with a backend service rather than a standalone local app.

### Backend API — Cloud Run

- Deployed as container(s) on **Cloud Run**, written in **Python**.
- Responsibilities:
  - User authentication and identity.
  - Session lifecycle: proposal → commitments → confirmation → change/cancel.
  - Reading the latest condition data and computing/exposing session viability
    (including the minimum-headcount threshold).
  - Triggering notifications via FCM.

### Database — Firestore

- Stores users, sessions, commitments, and the condition data the decisions are
  based on.
- Chosen for responsiveness and fit with the Firebase/GCP ecosystem.
  > Open question to revisit, not block on: confirm Firestore's data model and
  > query patterns suit the session/commitment relationships. It is a reasonable
  > default; validate it against real access patterns before locking in.

### Notifications — Firebase Cloud Messaging (FCM)

- Pushes notifications to athletes (new proposals, confirmations, changes),
  parents (child committed), and coaches (conditions degraded — act now).
- The app must have notifications enabled on the device.

### Condition-check pipeline — Cloud Scheduler + Cloud Functions

The heart of the automation. Each external data source is treated as its own
**service**, run on its **own schedule** by Cloud Scheduler triggering Cloud
Functions, writing results back for the backend to use. See
`Data_needed_for_rowing_safety_decision.md` for the data itself; the key
architectural point is that **different inputs refresh at different rates**.

### Infrastructure as code — Terraform

- All of the above — Cloud Run services, Firestore, Cloud Scheduler jobs, Cloud
  Functions, FCM setup — is defined in **Terraform** and provisioned from the
  codebase.
- No manual environment setup; the stack can be stood up reproducibly.

---

## The two-tier condition model

A single global refresh rate does not fit, because the inputs have very different
useful horizons. Conditions are therefore evaluated in **two tiers**:

**Tier 1 — stable, far-ahead inputs (planning horizon).**
Tide times and sunrise/sunset are predictable well in advance. These are used to
show the coach that *a session might be possible* on a given day, far enough out
to start gathering commitments. There is no point in conditions being good if no
one is available — so we let the coach propose early on the strength of stable
data.

**Tier 2 — volatile, near-term inputs (confirmation horizon).**
Wind and rainfall forecasts are only meaningful a limited distance ahead. As a
day approaches, these are re-checked. A forecast that looked good two weeks out
may be wrong three days out — so the system continues to re-evaluate and, if
conditions start to look inappropriate, notifies the coach.

## How an automated condition change is handled

When a re-check detects deteriorating conditions for a proposed or confirmed
session, the system does **not** auto-cancel. Instead it triggers the workflow
to **notify the coach** and bring them to the existing cancel / pivot-to-land
decision (see Coach flow, step 5). The decision stays human; only the detection
and the downstream notifications are automated. No separate code path is
introduced — it reuses the flow already defined.

---

## Refresh cadence summary

| Service | Refresh rate | Reason |
| --- | --- | --- |
| Parteen / Ardnacrusha PDFs | Once daily | ESB PDFs only update daily |
| Sunrise / sunset | Daily (fetch next ~30 days) | Highly stable |
| Tide times / heights | Periodic (stable, far ahead) | Predictable; supports planning |
| Wind | Frequent; not for sessions >7 days out | Forecast inaccurate beyond ~7 days |
| Rainfall | Frequent; limited horizon | Same accuracy limits as wind |

Forecast window overall: roughly **7 days** ahead for the volatile inputs.
