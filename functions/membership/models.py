"""The three roles, spelled the same here as in the app's UserRole enum: these
strings cross the wire into `users/{uid}` and into the custom claim that
Firestore rules read.
"""

from __future__ import annotations

COACH = "coach"
ATHLETE = "athlete"
PARENT = "parent"

ROLES = (COACH, ATHLETE, PARENT)
