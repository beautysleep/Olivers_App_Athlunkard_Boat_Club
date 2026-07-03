# Tide service

Fetches predicted high/low tides for **Limerick Dock** (Athlunkard Boat Club) and
feeds the `tide time` and `tide height` metrics of the row / no-row decision.

## Source & calibration

Data comes from **WorldTides.info** (v3 `extremes` endpoint). WorldTides resolves
the club coordinates to the nearest station — **~Tarbert**, in the outer Shannon
estuary — so we apply the coach's empirical offsets to reach Limerick Dock:

| Offset | Value (tunable) | Meaning |
| --- | --- | --- |
| Time | **+1 h 07 min** | Limerick high tide lags Tarbert (tide propagates up-estuary) |
| Height (high water) | **+0.85 m** | Limerick Dock high water is ~0.80–0.90 m higher than Tarbert |
| Height (low water) | 0.0 (uncalibrated) | Not yet measured — flagged, not guessed |

These live in `calibration.py` as parameters. They are field estimates to be
**refined with the coaches / the OPW "Limerick Dock" gauge**, not final values.

> Tide output is **advisory** (WorldTides terms forbid navigation/safety-critical
> use). The coach decides; upstream water-release is a separate hard override.

## Files

- `models.py` — `TideExtreme` (pure, no deps).
- `calibration.py` — `parse_extremes()` + `apply_limerick_calibration()` (pure).
- `worldtides_client.py` — thin HTTP call (`requests`).
- `main.py` — `fetch_limerick_tides()` + CLI.

## Run

```sh
export WORLDTIDES_API_KEY=...        # secret — never commit; GCP Secret Manager in prod
python main.py 7                     # 7 days of extremes as JSON
```

## Test (offline, no key/network)

```sh
python tests/test_tide.py
```
