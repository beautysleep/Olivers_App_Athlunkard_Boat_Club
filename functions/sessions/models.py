"""The roles and states this service reads and writes. Spelled the same as
membership's role strings and the app's SessionLifecycle/Conditions enums:
these cross the wire into `sessions/{id}` and into the custom claim
membership already sets at signup.
"""

from __future__ import annotations

COACH = "coach"
ATHLETE = "athlete"

PROPOSED = "proposed"
CANCELLED_WEATHER_PIVOT = "cancelledWeatherPivot"
CANCELLED_OUTRIGHT = "cancelledOutright"

GREEN = "green"
AMBER = "amber"
RED = "red"
RATINGS = (GREEN, AMBER, RED)
