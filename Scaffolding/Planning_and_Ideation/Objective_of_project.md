# Objective

## The objective

**Remove the manual coordination burden of organising on-water rowing sessions
from the coach, by automatically determining when conditions allow rowing and
running the proposal → commitment → confirmation → change loop on the coach's
behalf.**

If the project did nothing else, it would do this.

## The context behind it

The club:

- ~150 members
- 5 coaches and ~10 assistant coaches (who step in when others are away)
- Many parents who need to be kept informed
- Both on-water and land-based training; on-water is preferred but is
  frequently cancelled by changing conditions
- Attends many rowing events a year, with attendance heavily affected by weather

The recurring pain sits almost entirely with the coach. Today the flow looks
like this:

1. The coach repeatedly checks and re-checks whether water conditions are good
   enough to row — there is no single source that says "rowing is safe today".
2. Having found a candidate day, the coach posts a WhatsApp poll.
3. The coach chases responses to work out whether enough athletes can attend.
4. The coach separately arranges someone to drive the accompanying safety boat.
5. A weather change can invalidate all of the above at short notice, forcing the
   coach to manually unwind and re-communicate everything.

This is work that should not have to live in a person's head.

## What success looks like

The coach is **notified** when a session is possible, confirms with a single
action that they can run it (including driving the safety boat), and the system
handles the rest: notifying athletes, collecting commitments, confirming the
session once the threshold is met, and — if conditions later turn — prompting
the coach to cancel or pivot to land training, with automatic notifications to
everyone who had committed.

The mental load moves from the coach to the system.

## Why we are deliberately not doing more

This project intentionally resists scope creep. The club has other problems
worth solving, but trying to solve all of them at once is the surest way to ship
nothing. We are choosing to deliver **one useful feature** end-to-end rather
than several half-built ones.

Concretely deferred to later phases:

- **Analytics** — coaches will eventually want to see who is training, who shows
  up, and who cancels regularly (e.g. sessions per athlete over a month or a
  year). Valuable, but a phase-two concern once the core loop is trusted.
- **Crew matching / boat assignment** — eventually the system could pair athletes
  who row well together and assign them to specific boats. Out of scope for v1.

The objective is narrow on purpose. Narrowness is what makes it shippable.
