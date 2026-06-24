# Rowing Session Coordinator

A mobile app that takes the manual, repetitive work of organising on-water rowing
sessions off the coach's plate — automatically checking whether conditions are
safe to row, proposing viable sessions, collecting commitments, and notifying
everyone when a session is confirmed, changed, or cancelled.

This repository contains the **planning and specification documents** for the
project. No code yet — these are the agreed foundations to build against.

---

## The problem in one sentence

A coach currently spends real effort, repeatedly, checking water/weather
conditions, then chasing people on WhatsApp to find out who can row and who can
drive the safety boat — and all of it can be undone by a last-minute weather
change. We want to automate that loop.

## What we are building (and only this)

A deliberately small first release that solves **one** pain well:

1. The system checks conditions automatically and surfaces which upcoming days
   could support a session (green / amber / red).
2. The coach confirms a day and sends out a proposal.
3. Athletes are notified and commit (accept / decline).
4. Once enough athletes commit, the session is confirmed and everyone is told.
5. If conditions later deteriorate, the coach is prompted to either pivot to
   land training or cancel — and committed athletes are notified automatically.

That is the whole scope of v1. See `Objective_of_project.md` for why we are
holding the line here.

## Explicitly out of scope for v1

These are real and valuable, but deliberately deferred so we can ship something
useful rather than something sprawling and unfinished:

- Statistics / analytics (sessions per athlete, attendance trends, who cancels
  regularly).
- Automatic boat assignment and crew matching.
- Event (regatta) attendance management.
- Any other club workflow not directly tied to the core booking loop.

## Tech stack at a glance

| Concern | Choice |
| --- | --- |
| Mobile app (iOS + Android) | Flutter |
| Backend services | Cloud Run (Python) |
| Database | Firestore |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Scheduled condition checks | Cloud Scheduler → Cloud Functions |
| Infrastructure | Terraform (everything provisioned from code) |
| Cloud | Google Cloud Platform (GCP) |

Full detail in `Architectural_Key_Components.md`.

## How these documents fit together

| Document | Purpose |
| --- | --- |
| `README.md` | This file — orientation and scope. |
| `Objective_of_project.md` | The single objective and the discipline behind it. |
| `Key_Results_of_project.md` | Measurable outcomes that tell us v1 worked. |
| `Primary_Personas.md` | Who we are building for, and what they need. |
| `Primary_User_Flows.md` | Step-by-step flows for coach, athlete, parent. |
| `Architectural_Key_Components.md` | The technical shape and how pieces connect. |
| `Data_needed_for_rowing_safety_decision.md` | The metrics, sources, thresholds and refresh logic behind the row/no-row call. |

## Guiding principle

Ship one genuinely useful feature, get it into real hands, learn from how it is
actually used, then build the next thing on solid ground. Scope discipline is a
feature, not a limitation.
