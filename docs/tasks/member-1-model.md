# Member 1 — Model lead (Nicho)

**Branch for the current task:** `model-v1-results`
**Goal:** train the models, judge them by their scores, and build the **final model**.

## Done so far
- Datasets chosen, licenses checked, inspected and merged into **dataset v1** (7 classes, 4,979 images): see `BUILD-WALKTHROUGH.md` Parts 1 and 2.
- Training notebooks for Colab and Kaggle (Part 3).
- **Model v1** trained on Google Colab (2026-11-25): test recall 0.735, precision 0.849, mAP50 0.799. Weak on Cup and Plastic-Container. Details in `docs/results.md`, explained in `BUILD-WALKTHROUGH.md` Part 4. The model is `models/aedex-v1-best.pt` (copy in Google Drive).

## Steps

### 1. Finish model v1 (done)
- [x] Read the charts, the per-class test table and the "what it missed" pictures.
- [x] Download `best.pt` into `models/aedex-v1-best.pt`.
- [x] Branch `model-v1-results`: results and misses recorded in `docs/results.md`.

### 2. Hand model v1 to the app (now)
The team decided to build the app with model v1 now and swap in v2 later (2026-11-26).
1. On Colab, run `notebooks/export_tflite.ipynb` (CPU is enough). Step 7 must say **PASS**.
2. Share the Drive folder `Dengue Breeding Site Scanner/app-model/` with Member 3.
3. Tell Member 3 it's ready and point them to `docs/model-for-app.md`.

### 3. Review the team's work
- Member 2's pull request `basin-dataset-v2`: check the inspection report of dataset v2 (Pail-Basin box count, no leakage, present in every split).
- Member 3's pull request `hotspot-map`: run the app and check the pins.

### 4. Build the final model (after dataset v2 is merged)
1. In the Kaggle notebook's Settings, set `MODEL` to model v1's `best.pt` (uploaded as a Kaggle dataset) instead of `yolo11n.pt`, and use `merged-v2.zip`.
2. Train on **all of dataset v2**, not only the basin photos, or the model forgets the other classes.
3. Also train once from plain `yolo11n.pt` on dataset v2, and keep whichever has the better **recall on the same test set**.
4. Record both in `docs/results.md`.

### 5. Swap the final model into the app
Run the export notebook again with `MODEL_PT` set to the final model and `VERSION = 'v2'`, share the new files, and check the app with Member 3 (see "Swapping in a new model" in `docs/model-for-app.md`).

## Done when
- [x] Model v1 scores in `docs/results.md`
- [ ] Final model trained on dataset v2 and compared against the alternative
- [ ] Model v1 exported for the app (export check says PASS) and shared with Member 3
- [ ] Final model exported for the app
