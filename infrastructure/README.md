# Infrastructure (Terraform)

Everything in Google Cloud Platform is provisioned from code here. The guiding
constraint for the whole project: **no manual clicking in the GCP console** — the
environment must be reproducible from this repository.

## Planned layout

Kept deliberately **flat to begin with** — one file per concern, no modules and no
per-environment folders. Those patterns are worth adopting once there is a second
environment to justify them; introducing them now would be structure ahead of
need.

```
main.tf                 Provider and project wiring
variables.tf            Input variables
outputs.tf              Useful outputs (service URLs, etc.)
cloud_run.tf            The backend service
firestore.tf           The database
cloud_scheduler.tf      Schedules for the condition-collection jobs
cloud_functions.tf      The condition-collection jobs
firebase_messaging.tf   Push-notification setup
```

## Not written yet

No `.tf` files exist yet. They are added as each piece of the system is built, so
the infrastructure grows alongside the code it provisions rather than being
guessed at in full up front.
