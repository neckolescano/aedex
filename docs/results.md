# Training results

Add one row after every training run. Recall matters most: a missed breeding site is worse than a false alarm.
All scores are on the **test** split (Step 9 of the notebook), never on train or valid.

| Date | Who | Data used | Model | Epochs | Precision | Recall | mAP@50 | Notes |
|---|---|---|---|---|---|---|---|---|
| 2026-11-25 | Nicho | merged v1 (7 classes, 4,979 images) | yolo11n | 50 | 0.849 | 0.735 | 0.799 | First baseline, Colab T4, 1.2 h. File: `models/aedex-v1-best.pt` |

Reference: the VisText-Mosquito paper reports mAP@50 of 0.929 for YOLOv9s on its own (Bangladesh, daylight) test set.

## Model v1 (baseline-v1), 2026-11-25

**Run:** `yolo11n.pt`, 50 epochs, image size 640, batch 16, seed 42, Google Colab Tesla T4. All 50 epochs ran (early stopping never triggered). `best.pt` is 5.5 MB.
**Copy of the model:** Google Drive `Dengue Breeding Site Scanner/runs/baseline-v1/weights/best.pt` (ask Nicho for access).

### Per class, test split (235 images, 483 boxes)

| Class | Test boxes | Precision | Recall | mAP@50 | mAP@50-95 |
|---|---|---|---|---|---|
| Bottle | 50 | 0.860 | 0.857 | 0.870 | 0.609 |
| Coconut-Exocarp | 101 | 0.924 | **0.990** | 0.989 | 0.782 |
| Drain-Inlet | 53 | 0.891 | **0.925** | 0.971 | 0.619 |
| Tire | 140 | 0.787 | 0.836 | 0.898 | 0.777 |
| Vase | 116 | 0.856 | 0.853 | 0.879 | 0.726 |
| Cup | 11 | 1.000 | *0.437* | 0.630 | 0.316 |
| Plastic-Container | 12 | 0.628 | *0.250* | 0.357 | 0.253 |
| **All** | **483** | **0.849** | **0.735** | **0.799** | **0.583** |

The validation split gave almost the same overall numbers (precision 0.869, recall 0.717, mAP@50 0.796), so the test score is not luck from an easy split.

### What it does well
- Coconut shells, drain inlets, bottles, flower pots and tires: recall 0.84 to 0.99.

### What it misses
- **Cup and Plastic-Container:** recall 0.44 and 0.25. They had only about 90 training boxes each, against 1,200 to 2,400 for the other classes. The test set has only 11 and 12 of them, so these two numbers are rough (one miss = about 9%).
- **Mix-ups (confusion matrix, valid split):** 18% of cups were called Plastic-Container and 9% Vase. 17% of plastic containers and 11% of pots were missed completely.
- **False alarms:** the most common one is "Vase" on things that are not labeled objects (round shapes, planters).
- **From the "what it missed" pictures:** tires piled behind other tires, moss-covered tires, and small objects far from the camera (distant tires, a far drain inlet).

### Phone version (TensorFlow Lite), 2026-11-26
Exported with `notebooks/export_tflite.ipynb` (LiteRT format, full 32-bit, 10.7 MB, input `[1, 3, 640, 640]`), scored on the same test split:

| | `.pt` (CPU) | `.tflite` | diff |
|---|---|---|---|
| Precision | 0.846 | 0.906 | +0.060 |
| Recall | 0.739 | 0.713 | −0.026 |
| mAP@50 | 0.800 | 0.815 | +0.015 |
| mAP@50-95 | 0.583 | 0.588 | +0.005 |

mAP is the same or slightly better, so the conversion kept the model's quality. Precision and recall moved in opposite directions because they are read at one point on the curve, which shifts with tiny numeric changes. (The `.pt` scores differ slightly from the GPU test above because this run used a CPU.)

### What to do about it
1. **More Cup and Plastic-Container boxes:** Member 2's relabeling of grace's photos (dataset v2) includes both classes, not only Pail-Basin.
2. **Our own photos from Philippine yards in the test set.** These test photos come from the same sources as the training data, so real-world scores will likely be lower.
3. **In the app, use a lower confidence threshold** (for example 0.15 instead of 0.25): more containers found, a few more false alarms. That is the trade we want.
4. **For the final model, try more epochs** (75 to 100): mAP was still creeping up at epoch 50, though recall had levelled off around epoch 25.
