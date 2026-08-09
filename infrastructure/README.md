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

Files are added as each piece of the system is built, so the infrastructure
grows alongside the code it provisions rather than being guessed at up front.

## Remote state

Terraform state lives in a GCS bucket (`farnese-atlas-tfstate`, europe-west1,
versioned) — see the `backend "gcs"` block in `main.tf`. That bucket is the one
piece that can't be Terraform-managed from the start (Terraform can't keep its
own state in a bucket that doesn't exist yet), so it is **bootstrapped once**
with the CLI:

```sh
gcloud services enable storage.googleapis.com --project farnese-atlas
gcloud storage buckets create gs://farnese-atlas-tfstate \
  --project=farnese-atlas --location=europe-west1 \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update gs://farnese-atlas-tfstate --versioning
```

Then `terraform init` picks up the backend. State is never committed (gitignored).

## What's provisioned so far

- **APIs enabled** (`main.tf`): Firestore, Secret Manager, Cloud Functions,
  Cloud Build, Cloud Run, Artifact Registry, Cloud Scheduler, Eventarc,
  Firebase, Firebase Rules.
- **Firestore** database (Native mode) in `europe-west1`.
- **Firebase** project + Android app + Firestore security rules.
- **Tide** (`secrets.tf`, `cloud_functions.tf`, `cloud_scheduler.tf`): secret
  `worldtides-api-key`, the `tide-fetcher` gen2 function, and a daily 04:00
  scheduler; writes `tide_predictions`.
- **Weather** (`weather.tf`): secret `openweather-api-key`, the `weather-fetcher`
  gen2 function, and a `weather-fetch-3h` scheduler (every 3 hours); writes
  `weather_forecasts`. *Config written and validated; **not yet applied**.*
- **Water release** (`water_release.tf`): the `water-release-fetcher` gen2
  function and a `water-release-fetch-daily` scheduler (10:00 Europe/Dublin);
  writes `water_release_status`. **No secret** — ESB's hydrometric PDFs are
  public downloads, unlike tide/weather's API sources. *Config written and
  validated; **not yet applied**.*

Secret VALUES are loaded out-of-band via `gcloud`, never in Terraform or state.
A shared `${project_id}-function-source` bucket holds the zipped function sources.
