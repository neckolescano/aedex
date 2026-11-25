# The model for the app

How the phone app (Member 3) uses the trained model (Member 1). This is the contract between the two sides: if something here changes, both sides agree and update this file.

## Where to get it
Google Drive folder **`Dengue Breeding Site Scanner/app-model/`** (Member 1 shares it with you). It holds:

| File | What it is |
|---|---|
| `aedex-v1.tflite` | The model, TensorFlow Lite (LiteRT), full 32-bit precision, about 10 MB |
| `labels.txt` | Class names, one per line, in number order |
| `aedex-v1-info.json` | Image size, thresholds, input/output shapes, test scores |

They are made by [`notebooks/export_tflite.ipynb`](../notebooks/export_tflite.ipynb). The files stay **off GitHub** (`.gitignore` excludes `*.tflite`): copy them into the app's assets folder on your own machine, for example `app/aedex_app/assets/models/`.

## Facts the app relies on

| | Value |
|---|---|
| Classes (v1) | `0 Bottle, 1 Coconut-Exocarp, 2 Drain-Inlet, 3 Tire, 4 Vase, 5 Cup, 6 Plastic-Container` |
| Input | 1 photo, 640 × 640, RGB, values 0 to 1 (`[1, 640, 640, 3]`, float32) |
| Output | `[1, 11, 8400]`: for 8,400 candidate boxes, 4 box numbers (centre x, centre y, width, height) + 7 class scores |
| Confidence threshold | **0.15** (lower than the usual 0.25, because a missed breeding site is worse than a false alarm) |
| IoU threshold (duplicate removal) | 0.45 |
| Test scores | recall 0.735, precision 0.849, mAP50 0.799 (exact values for the .tflite are in the info file) |

The output is raw: the app (or its YOLO plugin) must keep boxes above the confidence threshold and remove overlapping duplicates (non-maximum suppression). Suggested: the Ultralytics Flutter plugin (`ultralytics_yolo` on pub.dev), which does this for YOLO `.tflite` models. Check its README for the current setup steps.

## From boxes to a scan record
Count the boxes per class name and put them in `counts`, as in the scan data contract (`docs/tasks/member-3-hotspot-map.md`):

```json
{ "counts": { "Tire": 2, "Cup": 1 } }
```

Use the class **name** from `labels.txt`, never the number, so the map and the stored scans stay correct when classes are added.

## Swapping in a new model (v1 → v2)
Dataset v2 adds **Pail-Basin as class 7**. When model v2 is ready, Member 1 runs the export notebook again and the folder gets `aedex-v2.tflite`, a new `labels.txt` (8 lines) and `aedex-v2-info.json`.

To make the swap a file change, not a code change, build the app so that:
1. **Class names come from `labels.txt`**, never a hard-coded list of 7.
2. **The number of classes comes from the label count** (the output becomes `[1, 12, 8400]` with 8 classes).
3. **The model file name is in one place** (one constant or config), so v2 is a one-line change.
4. **Pin colours and icons are looked up by class name**, with a default for unknown names, so a new class still shows up.

Old scans stay valid: their `counts` use names, and v2 keeps all the v1 names.

## Changes
- 2026-11-26: model v1 exported for the app.
