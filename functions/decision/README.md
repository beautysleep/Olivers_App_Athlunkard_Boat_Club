# Decision engine

Turns the stored tide, weather and water-release data into the row/no-row call
the app shows, and writes one `day_ratings` document per upcoming day.

Unlike the other three services this one has no external source: its inputs are
the collections the fetchers already write. No API key, no egress.

## What it decides

Hard overrides first, each settling the whole day:

- **Water release.** A confirmed Parteen Weir discharge forces red. Wording ESB
  has never been observed to use is *unparsed*, which holds the day back from
  green but does not force red — one rewording upstream should not turn every
  day red, and the card links the coach to the PDF.
- **Daylight and depth.** A day whose high waters never hold a rowable depth in
  daylight is red.
- **Cumulative rain** over the 24/48/72h bands.

Then, per rowable high tide:

- The **rowable window** is derived from the tide curve, not a fixed span. A
  half-cosine between the neighbouring lows — the curve behind the rule of
  twelfths — gives the times the water crosses `MINIMUM_ROWABLE_HEIGHT_METRES`,
  so a bigger tide holds the depth for longer. Each limb is measured against its
  own low, so an uneven pair gives an asymmetric window.
- Within it, the longest unbroken stretch of at least 1.5h where wind and rain
  both stay under threshold. A crew cannot land mid-session because the wind got
  up, so a stretch counts only if it holds throughout.
- Meeting the all-boats limits is green; only the big-boat limits, amber.

A day's two high tides are rated **separately** — they are separately
committable — and the day's own rating is the best of them.

## Beyond the hourly horizon

OpenWeather gives hourly detail for about 48h, which today covers 3 of the 10
calendar days. Past that, the day's single figure is spread flat across the
window and the reasons say so: *"Approximated from the whole-day forecast. This
sharpens closer to the time, once hourly detail reaches this day."* Real hours
always win where they reach, and partial coverage is topped up rather than
discarded — the series loses hours off the front as the fetcher refreshes.

Today is measured against the clock: an elapsed tide says so, and one underway
is clipped to the time that is left.

## Thresholds

All provisional, all in `models.py`, none confirmed with the coaches. See
`Data_needed_for_rowing_safety_decision.md`. `MINIMUM_ROWABLE_HEIGHT_METRES` and
the wind/rain limits are the ones to settle first.

## Running it

```
export GOOGLE_CLOUD_PROJECT=farnese-atlas
python functions/decision/main.py          # prints the ratings, writes nothing
```

Tests:

```
cd functions/decision
PYTHONPATH=. python -m pytest -q                       # offline

export RUN_LIVE_CANARY=1                               # reads real Firestore
PYTHONPATH=. python -m unittest discover -s tests -p "test_live_canary.py"
```

The canary needs `google-cloud-firestore` and application default credentials.
It asserts the *stored* shapes the engine reads, so it is the test that notices
when a fetcher changes its schema: canary red with the units green means an
upstream change, not a bug in here.
