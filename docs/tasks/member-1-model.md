# Member 1 — Model lead (Nicho)

**Branch for the current task:** `model-v1-results`
**Goal:** train the models, judge them by their scores, and build the **final model**.

## Done so far
- Datasets chosen, licenses checked, inspected and merged into **dataset v1** (7 classes, 4,979 images): see `BUILD-WALKTHROUGH.md` Parts 1 and 2.
- Training notebooks for Colab and Kaggle (Part 3).
- First training run of **model v1** started on Kaggle (Version #2 of the notebook).

## Steps

### 1. Finish model v1
1. When the Kaggle run says **Complete**, open the version and read Steps 8 to 10: the training charts, the per-class test table, and the "what it missed" pictures.
2. Download `best.pt` from the Output panel into `models/` (it stays off GitHub; share it with the team through Google Drive).
3. On branch `model-v1-results`: add the results row to `docs/results.md`, and note which kinds of objects it missed.

### 2. Review the team's work
- Member 2's pull request `basin-dataset-v2`: check the inspection report of dataset v2 (Pail-Basin box count, no leakage, present in every split).
- Member 3's pull request `hotspot-map`: run the app and check the pins.

### 3. Build the final model (after dataset v2 is merged)
1. In the Kaggle notebook's Settings, set `MODEL` to model v1's `best.pt` (uploaded as a Kaggle dataset) instead of `yolo11n.pt`, and use `merged-v2.zip`.
2. Train on **all of dataset v2**, not only the basin photos, or the model forgets the other classes.
3. Also train once from plain `yolo11n.pt` on dataset v2, and keep whichever has the better **recall on the same test set**.
4. Record both in `docs/results.md`.

### 4. Hand the model to the app
Export the chosen model for phones (TensorFlow Lite) and work with Member 3 to connect it (Phase 3 of the hotspot map task).

## Done when
- [ ] Model v1 scores in `docs/results.md`
- [ ] Final model trained on dataset v2 and compared against the alternative
- [ ] Final model exported for the app
