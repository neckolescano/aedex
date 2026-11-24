# Member 3 — App lead: hotspot map

**Branch:** `hotspot-map`
**Goal:** a Flutter app screen that shows **where breeding sites were found** on a map, so a barangay or clean-up group can see which streets need cleaning first.

## You don't need the AI model to start
The map only needs **scan results**: what was found, how many, where and when. Until the model is ready, use the sample data in `app/sample_scans.json`. Later, the real model produces the same kind of data and plugs in without changing the map.

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

### Phase 2: hotspots
6. A **heatmap or clustering** view: where many scans with many containers sit close together, show a hotspot.
7. Filter by **status** (for example, only "reported" sites still to clean) and by date.

### Phase 3: connect the model (later, with Member 1)
8. Take or pick a photo, run the trained model (exported for phones as TensorFlow Lite), and turn its detections into a scan record with the phone's location.

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

## Done when (Phase 1 and 2)
- [ ] The app runs on a real Android phone or emulator
- [ ] All sample scans appear as pins, coloured by risk
- [ ] Tapping a pin shows its counts, date and status
- [ ] A hotspot view and a status filter work
- [ ] `BUILD-WALKTHROUGH.md` has a section on how the app was built
- [ ] Pull request on `hotspot-map`, reviewed by another member
