# Backend (Python, FastAPI, Cloud Run)

The API that the mobile application talks to. Deployed as a container on Cloud
Run. Built with **FastAPI** — chosen over Flask because the application and the
backend must agree precisely on data shapes, and FastAPI validates requests and
responses through Pydantic at the boundary rather than by hand.

## Responsibilities

- User authentication and identity.
- Session lifecycle: proposal → commitment → confirmation → change / cancel.
- **The row / no-row decision.** This is the single place that turns stored
  condition data into a green / amber / red rating, applies the Parteen Weir and
  daylight hard overrides, and enforces the minimum-headcount threshold. The
  scheduled jobs in `../functions` only *collect* data; this backend *decides*.
- Triggering notifications through Firebase Cloud Messaging.

## Layout

```
rowing_coordinator/        The Python package
├── main.py                FastAPI application entrypoint
├── api/                   Request handlers, one file per area
│   ├── authentication.py
│   ├── sessions.py
│   ├── commitments.py
│   └── conditions.py
├── domain/                Business logic: the rating, thresholds, overrides
├── repositories/          Firestore reads and writes, isolated here
├── notifications/         Firebase Cloud Messaging sending
├── models/                Pydantic schemas (validated request / response shapes)
└── configuration.py       Settings and the tunable safety thresholds
tests/                     Unit and integration tests
```

The numeric safety thresholds are deliberately kept as configurable parameters in
`configuration.py`, to be set with the coaches — never hard-coded guesses. See
`../Scaffolding/Planning_and_Ideation/Data_needed_for_rowing_safety_decision.md`.

## Not generated yet

`pyproject.toml` and the `Dockerfile` are added when we start building the
service, so this skeleton stays empty until then.
