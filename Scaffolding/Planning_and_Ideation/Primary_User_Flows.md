# Primary User Flows

All users authenticate with a simple login (email / username / password) —
nothing more is needed at this stage. Each persona then lands in an experience
tailored to their role.

---

## Shared: authentication

- Email, username, password.
- Enough to identify who is who in the system; no extra profile complexity in v1.

---

## Coach flow

### 1. View the calendar

On login, the coach sees a **calendar** they can scroll left and right. Each day
is colour-coded by conditions:

- **Green** — any type of boat could go out.
- **Amber** — conditions are not perfect but good enough; suitable for larger
  boats / more experienced crews only.
- **Red** — not rowable.

### 2. Open a day for detail

Tapping a day **flips the card** to reveal the detail behind the colour. The
coach wants to see what they are working with, not just the rating. The card
shows the metrics used to make the decision, in particular:

- **High tide time** — the key piece of information; it tells the coach *when*
  rowing would be possible that day.
- **Wind speed.**
- The other condition metrics feeding the green / amber / red call.

### 3a. Send out a proposal

If the coach is happy and available, they tap **commit / send proposal**. Every
athlete (in the relevant membership group) receives a notification: *"There's a
session on this day — can you attend?"*

### 3b. Or mark themselves unavailable

Alternatively, the coach marks a day **not available**. The card flips back and
the calendar reflects this — e.g. a lighter green, or green with a red ✕ — so a
day they can't run isn't proposed.

### 4. Track commitments

A **separate tab — "Upcoming Sessions"** — shows confirmed/proposed sessions as
an ordered **list** (not a calendar). Tapping any session shows **who has agreed
to attend**.

- Headcount vs. the minimum threshold is shown **automatically**.
- If **fewer than 4** have committed, the session is clearly marked **not yet
  possible**.

At threshold, the session is viable. Once enough athletes commit, the session is
confirmed and everyone is notified.

> *Deferred:* eventually the system could pair athletes who row well together and
> assign boats. Not in v1 — keep it to the headcount.

### 5. Change or cancel a session (before it happens)

The coach can open any upcoming session and act. There are **two** options, not
one:

- **Cancel due to weather → pivot to land training.** Athletes who committed
  still train, but on land / online instead of on the water.
- **Cancel outright.** The coach is no longer available or able to run it.

In both cases, everyone who committed is notified automatically (e.g. *"Sorry for
the inconvenience — this session has been cancelled due to conditions"*).

> This same cancel/pivot flow is what an automated condition change reuses — see
> `Architectural_Key_Components.md`. The system notifies the coach and brings
> them straight here; it does not invent a separate path.

---

## Athlete flow

### 1. View the calendar

On login, the athlete also starts on a **calendar**, mirroring the coach's
pattern. They can see days under different states, for example:

- Weather is okay but no coach has proposed a session yet.
- Weather is good **and** a coach has sent a proposal.

### 2. Get notified and respond

- The athlete receives an **in-app notification, pushed to their mobile**
  (notifications must be enabled).
- They open the list to see **new sessions proposed by the coach** that they
  haven't yet responded to.
- They **accept or decline**.

### 3. See upcoming sessions and who's going

A **separate "Upcoming Sessions" tab** (same pattern as the coach) shows the
sessions the athlete has agreed to attend. For each, they can see:

- The same detail as the coach (conditions, timing).
- **Who else has committed** — shown as **profile circles**, like the WhatsApp
  poll experience, not merely a headcount. This gives a sense of who they'll be
  training with.

---

## Parent flow (underage athletes)

### 1. Optional visibility

The parent **can** see what the athlete sees if they choose to.

### 2. Primary use — notification

The parent's main use case is simpler: they **subscribe to be notified** when
their child commits to a session, receiving something like *"Your child is
planning to attend the session on [day/time]"* — enough to plan transport without
relying on the athlete to relay it.

---

## Flow summary

| Persona | Proposes | Commits | Sees who's going | Gets notified | Can cancel/pivot |
| --- | --- | --- | --- | --- | --- |
| Coach | ✅ | — | ✅ | ✅ | ✅ |
| Athlete | — | ✅ | ✅ (profile circles) | ✅ | — |
| Parent | — | — | optional | ✅ (child committed) | — |
