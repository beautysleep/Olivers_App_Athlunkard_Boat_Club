# Key Results

These are the measurable outcomes that tell us the first release achieved its
objective. They are framed as results (what changes in the world), not features
(what we build). Each should be observable once the app is in real use.

## KR1 — The coach stops manually checking conditions

The coach no longer has to actively check or re-check weather/water conditions
to decide whether a session is possible. Instead, candidate days are surfaced to
them automatically.

- *Signal:* Coaches report they no longer open weather/tide/dam sources manually
  before proposing a session.
- *Target:* Zero manual condition-checking required to identify a candidate day.

## KR2 — Proposing a session is a single action

Once a candidate day exists and the coach is available, sending a proposal to all
athletes takes one deliberate action, not a sequence of manual messages.

- *Signal:* Time from "I want to run a session that day" to "all athletes
  notified" is seconds.
- *Target:* One tap to send a proposal; no copy-pasting into WhatsApp.

## KR3 — Commitment is collected and counted automatically

Athlete responses (accept / decline) are gathered in-app, and the coach can see
at a glance whether a session is viable against the minimum threshold.

- *Signal:* The coach never tallies responses by hand.
- *Target:* Headcount vs. the minimum (4) is shown automatically; a session is
  flagged "not yet possible" below threshold and "viable" at or above it.

## KR4 — Safety-boat coverage is part of confirmation

A session cannot be confirmed without a coach having committed to run it
(including the safety-boat responsibility).

- *Signal:* No confirmed session ever lacks an accountable coach.
- *Target:* 100% of confirmed sessions have an explicit coach commitment.

## KR5 — Condition changes no longer require manual unwinding

When conditions deteriorate after a proposal or confirmation, the system detects
it and prompts the coach to act (cancel or pivot to land training), and notifies
all committed athletes automatically.

- *Signal:* Coaches do not manually message people to unwind a cancelled session.
- *Target:* Every weather-driven change triggers an automatic notification to all
  committed athletes; the coach only makes the decision, not the announcements.

## KR6 — Parents get visibility without chasing

Parents of underage athletes are automatically informed when their child has
committed to a session, so they can plan transport.

- *Signal:* Parents stop relying on the athlete to relay session details.
- *Target:* Subscribed parents receive a notification when their child commits to
  a session.

## KR7 — The whole thing runs without manual operation

The condition checks, notifications, and confirmations run on their own
schedule without anyone operating them.

- *Signal:* No human kicks off the daily/periodic checks.
- *Target:* All condition-check services run automatically on schedule; the app
  functions with zero manual backend intervention.

---

### A note on what we are *not* measuring yet

Attendance analytics, reliability scoring of individual athletes, and crew-fit
metrics are explicitly out of scope for v1 (see `Objective_of_project.md`). We
are not setting key results for them now — doing so would pull effort away from
the core loop.
