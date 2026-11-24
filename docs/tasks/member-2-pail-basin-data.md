# Member 2 — Data lead: Pail-Basin

**Branch:** `basin-dataset-v2`
**Goal:** build **dataset v2** = dataset v1 + a new class, **Pail-Basin** (class 7), with enough good examples that the model can learn it.

## Why this matters
Pails, buckets and basins are some of the most common breeding sites in Philippine yards, but our first model can't see them: the only data we had was 36 boxes, far too few. You are fixing that. The final model (built by Member 1) is trained on the dataset you produce.

## Where the data comes from

| Source | What | Use it for |
|---|---|---|
| **grace's** (forked in our Roboflow workspace) | 1,091 photos of basins and containers with water, where only the mosquito larvae were labeled, never the container | **Main source:** add a box around each container |
| **Your own photos** | 50 to 100 photos of real pails and basins around homes | Mostly the **test set**: they show how the model does in our yards |
| ~~Bucket Detection (pioneer)~~ | Robotics photos: buckets and cones on a sports field | **Not used:** wrong kind of scene, mostly cone labels |

## Steps

### 1. Get set up
- Accept the invitations to the GitHub repo and the Roboflow workspace (ask Member 1).
- Clone the repo and start your branch:
  ```
  git clone https://github.com/neckolescano/aedex.git
  cd aedex
  git checkout -b basin-dataset-v2
  ```
- Read `BUILD-WALKTHROUGH.md` Parts 1 and 2 (how we inspect and merge datasets).

### 2. Relabel grace's basin photos in Roboflow
1. Open the **grace's** project in our workspace.
2. **Classes & Tags → Add** a class named exactly `Pail-Basin`.
3. Filter the images by class **Larva**: these are the photos to relabel.
4. Open each photo and draw **one box around each whole container**:

   | You see | Class |
   |---|---|
   | Pail, bucket or basin | `Pail-Basin` |
   | Plastic cup | `Cup` |
   | Ice cream tub, clear plastic food box | `Plastic-Container` |
   | Flower pot | `Pot` (it becomes Vase in our dataset) |
   | Tire | `Tire` |

5. **Leave the Larva boxes alone.** The merge script drops them automatically.
6. Work in batches. About 5 to 10 seconds per photo. **First target: 300 photos.**

### 3. Take your own photos
Follow the photo rules in the team guide: different pails and basins, different places, sun and shade, morning and afternoon, empty and full, close and far. No faces, house numbers or plate numbers. Name them `<initials>_<YYYYMMDD>_<number>.jpg`. Upload and label them in Roboflow too.

### 4. Export and check
1. In Roboflow: **Versions → Create New Version**, no augmentation → **Download → YOLOv11 → zip**.
2. Save it as `datasets/graces/grace-s-v2-yolov11.zip` (not committed: `datasets/` stays off GitHub).
3. Check it:
   ```
   python scripts/inspect_dataset.py "datasets/graces/grace-s-v2-yolov11.zip" --drop Larva
   ```
   Write down the Pail-Basin box count and how many images are still left with no boxes.

### 5. Build dataset v2 (with the AI, build-and-teach)
Ask the AI to update `scripts/merge_datasets.py` for v2 and explain it:
- add `Pail-Basin` at the **end** of `CLASSES` (it becomes number 7; never reorder),
- map grace's `Pail` and `Pail-Basin` to `Pail-Basin`,
- point the grace's source at your new export and set `VERSION = "v2"`.

Then run it and check the result:
```
python scripts/merge_datasets.py --zip
python scripts/inspect_dataset.py datasets/merged/v2
```

### 6. Test training run
Upload `merged-v2.zip` to Kaggle and run the training notebook (only change the dataset). Record the scores in `docs/results.md`, especially **Pail-Basin recall**.

### 7. Hand over
Push your branch and open a pull request. Member 1 reviews it and then trains the final model on dataset v2, starting from model v1.

## Labeling rules
- The box touches the edges of the **whole** container, rim included.
- Label **every** container in the photo, even partly hidden ones you can clearly recognise.
- Too small or blurry to recognise: leave it.
- Not sure what it is: skip it and ask the team.

## Done when
- [ ] At least 300 Pail-Basin boxes, from many different containers
- [ ] Dataset v2 inspected: no leakage, Pail-Basin present in train, valid and test
- [ ] Test training run done, scores in `docs/results.md`
- [ ] `BUILD-WALKTHROUGH.md` has a section on what you did and learned
- [ ] Pull request on `basin-dataset-v2`, reviewed by Member 1
