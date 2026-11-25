# Member 3 — App lead: hotspot map

**Branch:** `hotspot-map`
**Goal:** a Flutter app screen that shows **where breeding sites were found** on a map, so a barangay or clean-up group can see which streets need cleaning first.

## The model is ready (model v1)
The team decided to build the app with **model v1 now** and swap in model v2 later (2026-11-26). Member 1 shares a Google Drive folder `app-model/` with the phone model (`aedex-v1.tflite`) and `labels.txt`. **Read [`docs/model-for-app.md`](../model-for-app.md) first:** it explains the input, the output, the thresholds, and how to build the app so v2 is a file swap, not a code change.

The map itself only needs **scan results**: what was found, how many, where and when. Start the map with the sample data in `app/sample_scans.json`; real scans from the camera have the same shape.

## The scan data (the contract between the model and the app)
Every scan is one record:

```json
{
  "id": "scan-001",
  "time": "2026-11-20T08:15:00+08:00",
  "lat": 14.5995,
  "lng": 120.9842,
  "location_precision": "street",
  "counts": { "Tire": 2, "Cup": 3, "Vase": 1 },
  "status": "reported"
}
```

| Field | Meaning |
|---|---|
| `lat`, `lng` | Where the scan was taken |
| `location_precision` | `street` for private homes (rounded, never the exact house), `exact` for public places like a vacant lot or canal |
| `counts` | How many of each class the model found. Class names are exactly the ones in `CLAUDE.md` |
| `status` | `reported` → `assigned` → `cleaned` → `verified` (the clean-up flow from the team guide) |

If you need a new field, agree on it with Member 1 and update this file, so the model side produces it too.

## What to build, in order

### Phase 1: the map (start here)
1. A Flutter project inside `app/` (`flutter create aedex_app` inside the `app` folder).
2. A map screen. Suggested: the `flutter_map` package with OpenStreetMap tiles, which is free and needs no API key. (Google Maps also works but needs a key.)
3. Load `app/sample_scans.json` and put **one pin per scan**.
4. **Colour each pin by risk** (total containers found): 0 green, 1 to 3 yellow, 4 or more red.
5. Tap a pin: a card with the counts per class, the date and the status.

### Phase 2: camera and model (model v1)
6. Take or pick a photo and run `aedex-v1.tflite` on it (suggested: the `ultralytics_yolo` Flutter plugin). Show the boxes with class names.
7. Turn the boxes into a scan record: `counts` per class name, the phone's location (rounded to street level for private homes), the time, status `reported`. Save it and show it on the map.
8. Follow the four "swap" rules in `docs/model-for-app.md` (class names from `labels.txt`, model file name in one place).

### Phase 3: hotspots
9. A **heatmap or clustering** view: where many scans with many containers sit close together, show a hotspot.
10. Filter by **status** (for example, only "reported" sites still to clean) and by date.

## Rules
- Private homes are shown at **street level**, never the exact house. Faces and house numbers are never shown.
- No shaming: the public map shows areas, not who lives where.
- Never commit to `main`: work on `hotspot-map` and open a pull request.

## Getting started
```
git clone https://github.com/neckolescano/aedex.git
cd aedex
git checkout -b hotspot-map
```
Then open the repo with the AI and say: "I'm Member 3, let's start Phase 1." It will build each part with you and explain how it works.

## Done when (Phases 1 to 3)
- [ ] The app runs on a real Android phone or emulator
- [ ] All sample scans appear as pins, coloured by risk
- [ ] Tapping a pin shows its counts, date and status
- [ ] A photo taken in the app shows model v1's boxes and becomes a new pin
- [ ] Class names come from `labels.txt` (swapping in v2 needs no code change)
- [ ] A hotspot view and a status filter work
- [ ] `BUILD-WALKTHROUGH.md` has a section on how the app was built
- [ ] Pull request on `hotspot-map`, reviewed by another member
