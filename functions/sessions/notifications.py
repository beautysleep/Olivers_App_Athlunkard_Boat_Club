"""Push copy for a new proposal. Deliberately generic rather than a port of
the app's formatDayTime — a push is a nudge, not the message; the app
already has the rich detail once opened, and porting a Dart formatter to
Python for parity is unnecessary duplication and a drift risk.
"""

from __future__ import annotations

PROPOSAL_TITLE = "New session proposed"
PROPOSAL_BODY = "Tap to see details and respond."
