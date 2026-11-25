# Build walkthrough

How each part of the Dengue Breeding Site Scanner was built, why it was built that way, and what we learned. Read a section, run the command yourself, then answer the check questions at the end.

---

## Part 1: Inspecting the datasets (2026-11-24)

**File:** [`scripts/inspect_dataset.py`](scripts/inspect_dataset.py)
**Reports:** [`docs/inspect-vistext.txt`](docs/inspect-vistext.txt), [`docs/inspect-graces.txt`](docs/inspect-graces.txt)

### Why we inspect before training
A model learns whatever the labels say, mistakes included. Looking at the data first is cheaper than training a bad model and wondering why it fails.

### How a YOLO dataset is laid out
Both zips use the same layout:

```
data.yaml            the class list and where each split is
train/images/        photos the model learns from
train/labels/        one .txt per photo, same name
valid/images, valid/labels   checked during training
test/images,  test/labels    the final exam, never trained on
```

Each line in a label `.txt` is one object:

```
3 0.349 0.581 0.535 0.445
^   ^     ^     ^     ^
|   x     y     width height    (centre of the box and its size, as shares of the image: 0 to 1)
class number
```

The **class number** points into the `names` list in `data.yaml`, counting from 0. In VisText, `3` means Tire. In grace's, `3` means Pail. **The same number means different things in different datasets**, so we must remap numbers when we merge them.

### How the script works
1. **Reads a zip or a folder the same way** (the `Source` class), so we never need to unzip 400 MB just to look.
2. **Reads `data.yaml`** to get the class names in number order.
3. **Reads the Roboflow README** for how the export was made (resizing, augmentation).
4. **Pairs every image with its label file** and counts boxes per class and per split.
5. **Flags problems:** images without a label file, boxes outside the image, tiny boxes (< 0.05% of the image, about 14×14 px at 640×640), thin strips.
6. **Finds copies of the same photo.** Roboflow names files `photo_jpg.rf.<hash>.jpg`. Everything before `.rf.` is the original photo, so files sharing it are copies. If copies sit in different splits, that is **data leakage**: the "exam" contains photos the model studied.
7. **`--drop Larva`** shows how many images would have no boxes left if we remove a class.
8. It also understands **polygons** (`class x1 y1 x2 y2 ...`), which YOLO converts into boxes.

Run it yourself:

```
python scripts/inspect_dataset.py "datasets/vistext/Breeding Place Detection.zip"
python scripts/inspect_dataset.py "datasets/graces/grace-s.v1i.yolov11.zip" --drop Larva
```

### What we found: VisText-Mosquito

| Finding | Number | What it means |
|---|---|---|
| Files | 4,425 | Not 1,828: Roboflow made extra copies |
| Original photos | 1,846 | Close to the paper's 1,828 |
| Copies | 3 per photo (1,263 photos), mostly in train | Brightness changed by −24% to +24%: built-in lighting variety, good for shade |
| Classes | 0 Bottle, 1 Coconut-Exocarp, 2 Drain-Inlet, 3 Tire, 4 Vase | Fairly balanced: 14% to 27% each |
| Polygon outlines | 161 | Fine: used as boxes |
| Empty labels | 38 | Fine: real "nothing here" examples |
| **Leakage** | **6 photos in more than one split** | Must fix when we merge |
| Tiny boxes | 78 (Vase, Bottle) | Look at a few; delete if not visible |
| Image size | 640×640, stretched | Some photos look squashed; the model learns that too |

### What we found: grace's

| Finding | Number | What it means |
|---|---|---|
| Images | 1,681, no copies, no leakage | Clean structure |
| Classes | 0 Container, 1 Cup, 2 Larva, 3 Pail, 4 Pot, 5 Tire | Different numbers than VisText |
| Larva | 4,578 boxes (87%) | This dataset was built to find larvae, not containers |
| **After dropping Larva** | **1,091 images with no boxes** | Most of them are basins with water and no container box. Training on them would teach "a basin is nothing". Remove them, or relabel them with a Pail-Basin box |
| Pail | 36 boxes | Too few on its own |
| Pot | 170 of 176 in train | Only 6 left to test on: we cannot measure Pot well. Re-splitting fixes this |
| Tiny boxes | 266, almost all Larva | Gone once Larva is dropped |

### Decisions (2026-11-24)
1. **Final class list for the first model: 7 classes, in this order (the order sets the label numbers):**

   | # | Class | From VisText | From grace's |
   |---|---|---|---|
   | 0 | Bottle | Bottle | – |
   | 1 | Coconut-Exocarp | Coconut-Exocarp | – |
   | 2 | Drain-Inlet | Drain-Inlet | – |
   | 3 | Tire | Tire | Tire |
   | 4 | Vase | Vase | Pot (checked: flower pots) |
   | 5 | Cup | – | Cup |
   | 6 | Plastic-Container | – | Container (checked: ice cream tubs, clear food boxes) |

2. **Pail-Basin is postponed.** Only 36 Pail boxes exist so far, too few to learn from. grace's Pail and Larva are dropped, and images left with no boxes after that are removed (otherwise they teach "this is nothing").
3. **Adding Pail-Basin later:** it gets the next free number (7), so the numbers above never change, and we retrain. Good sources: the two bucket datasets, our own photos, and relabeling some of grace's 1,091 larva-only basin images.

### Next step (when the team says go)
A **merge script** that builds one combined dataset: remaps class numbers, drops Larva, removes images left with no boxes, keeps all copies of a photo in the same split (fixing leakage), and writes one `data.yaml` with our final class list.

### Check questions
1. In grace's, what does the label line `3 0.5 0.5 0.2 0.3` mean? What would the same line mean in VisText?
2. Why are 4,425 files from 1,846 photos not a problem for training, but copies of one photo in both train and test are?
3. Why would keeping the 1,091 larva-only images (with Larva removed) make the model worse at finding basins?
4. Pot has 170 boxes in train but only 6 in valid and test. What goes wrong when we try to measure how good the model is at Pot?

---

## Part 2: Merging the datasets (2026-11-24)

**File:** [`scripts/merge_datasets.py`](scripts/merge_datasets.py)
**Output:** `datasets/merged/v1/` (folders + `data.yaml` + `MERGE-REPORT.txt`) and `datasets/merged/merged-v1.zip` (about 1.1 GB, for Google Drive)
**Check:** [`docs/inspect-merged-v1.txt`](docs/inspect-merged-v1.txt)

### What the script does
1. **Reads each source** (straight from the zip) and its `data.yaml`.
2. **Remaps class numbers.** A table per source says which of its classes becomes which of ours, or `None` to drop it. Example: grace's `4` (Pot) becomes our `4` (Vase); grace's `5` (Tire) becomes our `3` (Tire). If a source has a class missing from its table, the script stops instead of guessing.
3. **Drops Larva and Pail,** and removes every image left with no boxes because of that: 1,127 of grace's images (all its larva-only and pail-only photos).
4. **Keeps true background images** (photos that never had a box, 39 of them): those teach "nothing here" correctly.
5. **Turns polygons into boxes** and clamps boxes that poke a hair outside the image.
6. **Splits without leakage:**
   - VisText keeps its own split, but its 6 leaking photos move all their copies into train.
   - grace's gets a fresh split: each photo is filed under its rarest class, then every class is cut 80/10/10. That is why Cup and Plastic-Container now have 11–12 boxes in valid and in test, instead of almost none.
   - A fixed **seed (42)** makes the shuffle the same every time, so rebuilding gives the same split.
7. **Writes short, safe file names:** `source__photo-name_<photo-fp>.rf.<file-fp>.jpg`.

### Two bugs we hit, and what they teach
- **Path too long.** Some VisText names are over 150 characters, and Windows refuses paths longer than 260. Fix: keep the first 60 characters plus a short fingerprint (a hash), so names stay unique and short.
- **A check that could not see.** After that fix, the inspector reported "0 copies" and "no leakage". That sounded good, but it was blind: the new names hid which files were copies of one photo. We changed the name so every copy shares a photo fingerprint before `.rf.`. Now the inspector finds the 1,300 copy groups and confirms no leakage for real. Lesson: **when a check passes, ask whether it could have failed.**

### The merged dataset v1

| # | Class | Train | Valid | Test | Total |
|---|---|---|---|---|---|
| 0 | Bottle | 1,196 | 98 | 50 | 1,344 |
| 1 | Coconut-Exocarp | 1,939 | 171 | 101 | 2,211 |
| 2 | Drain-Inlet | 1,165 | 135 | 53 | 1,353 |
| 3 | Tire | 1,835 | 144 | 140 | 2,119 |
| 4 | Vase | 2,351 | 212 | 116 | 2,679 |
| 5 | Cup | 87 | 11 | 11 | 109 |
| 6 | Plastic-Container | 94 | 12 | 12 | 118 |

4,979 images from 2,400 original photos: 4,321 train, 423 valid, 235 test. Cup and Plastic-Container have about 20 times fewer boxes than the others, so expect the first model to be weakest on them.

Still open: 92 tiny boxes (mostly VisText Vase and Bottle). They are kept for now; we will look at a few after the first training run.

### Rebuild it yourself
```
python scripts/merge_datasets.py --overwrite --zip
python scripts/inspect_dataset.py datasets/merged/v1
```
To add a dataset or Pail-Basin later: add the class at the END of `CLASSES`, add the source to `SOURCES`, change `VERSION` to `v2`, run again.

### Check questions
1. grace's label line `4 0.5 0.5 0.2 0.3` becomes what line in the merged dataset? Why?
2. Why did we remove the larva-only images, but keep the 39 images that never had a box?
3. Why must all copies of one photo be in the same split?
4. The first leakage check passed but was wrong. How did we notice?

---

## Part 3: The training notebook (2026-11-24)

**File:** [`notebooks/train_baseline.ipynb`](notebooks/train_baseline.ipynb), opened in Google Colab.
The notebook explains itself cell by cell. This part explains the **design choices** behind it.

### Why a notebook in Google Colab
- Training needs a **GPU**. Colab lends one (a Tesla T4) for free, so nobody's laptop matters.
- A notebook mixes **explanations, code and pictures**, so we can see the data and the results right next to the code that made them.

### Why it is built this way

| Choice | Why |
|---|---|
| One **Settings** cell (Step 3) | Everything you might change sits in one place: model size, epochs, batch size. You never edit code deep inside the notebook |
| **Dataset from Drive, copied to local disk** before unzipping (Step 4) | Colab's disk is wiped when a session ends, so the dataset must live in Drive. But reading thousands of small files from Drive is slow, so we copy one zip and unzip locally |
| **Results saved to Drive** (`project=RUNS_DIR`) | If Colab disconnects mid-training, every finished epoch is safe. The "resume" cell continues from `last.pt` |
| **Look at the data first** (Step 6) | A model copies its labels. Six random photos with their boxes drawn catch big mistakes before an hour of training |
| **`yolo11n.pt`, the smallest YOLO** | Fast to train on a free GPU and small enough to run on a phone later. A bigger model is an easy experiment for later: change one word in Settings |
| **Transfer learning** | The model already learned edges, shapes and textures from the COCO dataset (80 everyday classes). We only teach it our 7 classes, so thousands of photos are enough instead of millions |
| `patience=15` | If the validation score hasn't improved for 15 epochs, training stops early: more epochs would only waste time or start memorising |
| `seed=42` | Same settings give the same result, so two runs can be compared fairly |
| **Test split only at the end** (Step 9) | The test photos are the exam. They are never used for training or for choosing settings, so the score is honest |
| **Recall first** | A missed breeding site is worse than a false alarm, so the notebook asks us to judge recall before precision |
| **"What it missed" pictures** (Step 10) | Scores say how much it misses; pictures say *what* it misses. That tells the team which photos to take next |

### Words you will see in the output
- **Epoch:** one pass over every training photo.
- **Loss:** how wrong the model's guesses were. It should go **down**.
- **Overfitting:** training loss keeps falling but validation loss rises: the model memorises instead of learning.
- **Precision / Recall / mAP50:** see the table in Step 9 of the notebook.
- **`best.pt` / `last.pt`:** the model from the best-scoring epoch, and from the most recent one.
- **Confusion matrix:** a grid of "real class" against "what the model said". Off-diagonal numbers are mix-ups; the background column is objects it missed entirely.

### What was checked before handing it over
- Every code cell is valid Python.
- Steps 4 and 6 were run on our real merged dataset: the split counts match (4,321 / 423 / 235) and the labels draw correctly on the photos.
- **Not yet run:** the training and testing cells (Steps 7 to 10), which need Colab's GPU. Our first real run is the test.

### Check questions
1. Why do we copy the zip from Drive to Colab's local disk instead of using it straight from Drive?
2. What would you change in the Settings cell if training crashes with "CUDA out of memory"?
3. Your training loss is still falling, but validation loss has been rising for 10 epochs. What is happening, and what does `patience` do about it?
4. Why do we look at the test score only once, at the very end?

### Kaggle version (added 2026-11-24)
Colab could not give us a free GPU, so there is a second notebook for Kaggle: [`notebooks/train_baseline_kaggle.ipynb`](notebooks/train_baseline_kaggle.ipynb). Steps 5 to 10 are identical; only the parts that touch storage changed.

| | Colab | Kaggle |
|---|---|---|
| Where the dataset lives | Google Drive, mounted at `/content/drive/MyDrive/...` | A Kaggle Dataset, shown read-only under `/kaggle/input/...` |
| How the notebook finds it | Exact path in Settings | Searches for `data.yaml` (Kaggle unzips uploads), falls back to the zip |
| Working copy | Unzipped to `/content/dataset` | Copied to `/tmp/dataset`: the input folder is read-only, and YOLO writes small cache files |
| Where results are kept | Google Drive | `/kaggle/working/` (the only folder Kaggle keeps) |
| Running in the background | Not on the free plan: keep the tab open | **Save Version → Save & Run All**: runs up to 12 hours with the tab closed |
| GPU choice | T4 | T4 x2 or P100; we use one GPU (`device=0`) because multi-GPU training often breaks inside notebooks |

Checked: every code cell is valid Python, and the find-and-copy step was tested on a stand-in for Kaggle's input folder made from our merged dataset (it found `data.yaml` and copied 4,321 / 423 / 235 images). Training itself runs only on Kaggle.

## Part 4: Reading the results of model v1 (2026-11-25)

**Files:** [`docs/results.md`](docs/results.md) (all the numbers), `models/aedex-v1-best.pt` (the model, not on GitHub).
Model v1 trained for 50 epochs on Google Colab's T4 in 1.2 hours. This part explains how to read what the notebook printed, so anyone can judge the next model the same way.

### Where it trained
Kaggle sat in a queue for 11 hours. Colab gave us a T4 after several tries in the evening, then disconnected once while idle. What worked: reconnect, then **Runtime → Run all** right away, and keep the tab open and the laptop awake. Free GPUs are easiest to get at off-peak hours.

### The scores, in plain words
- **Recall 0.735:** out of every 100 real containers in the test photos, the model found about 74.
- **Precision 0.849:** out of every 100 boxes the model drew, about 85 were right.
- **mAP50 0.799:** one number combining both, across every confidence level. Use it to compare two models; use recall to decide if a model is good enough for us.

Per class, five are strong (Coconut-Exocarp 0.99, Drain-Inlet 0.93, Bottle 0.86, Vase 0.85, Tire 0.84 recall) and two are weak (Cup 0.44, Plastic-Container 0.25).

### Why two classes are weak
The model saw about 90 training boxes of each, against 1,200 to 2,400 for the others. A model learns what it sees often. This is a **data problem**, not a model problem: more training, or a bigger model, would not fix it. More examples will. Also, with only 11 or 12 of them in the test set, one miss changes the score by 9%, so these two numbers are rough.

Cup's precision is 1.00 with recall 0.44: when it says "cup" it is always right, but it misses most cups. High precision with low recall means the model is **too careful**.

### How to read the charts
- **Loss lines** (train and val) should go down. Ours did, all the way. If val loss had turned back up while train loss kept falling, that would be **overfitting**.
- **The sudden drop at epoch 40** is not a bug: for the last 10 epochs YOLO stops "mosaic" (pasting 4 photos into one), so the photos get easier.
- **Recall levelled off around epoch 25**, while mAP kept creeping up. Extra epochs mostly made the boxes tighter. To find *more* objects, we need more and more varied photos.

### How to read the confusion matrix
Read it **by column**: each column is what the object really is, and each row is what the model said.
- The diagonal is correct answers. The **bottom row (background)** is objects the model missed completely.
- The **right column (background)** is false alarms: the model drew a box where nothing was labeled. Ours mostly says "Vase" on round shapes.
- Off-diagonal cells are mix-ups: 18% of cups were called Plastic-Container. They look alike.

### Things in the log worth knowing
- `Remapped 3/7 cls head rows from pretrained weights by class name`: the starting model learned COCO, which already has bottle, vase and cup. YOLO gave those three classes a head start. That is transfer learning at work.
- Validation and test gave almost the same scores (recall 0.717 and 0.735), so the test split was a fair exam, not an easy one by luck.
- `best.pt` is 5.5 MB and takes about 7 ms per photo on the GPU: small and fast enough for a phone.

### What the misses tell us
The "what it missed" pictures showed tires piled behind other tires, moss-covered tires, and small faraway objects. For our use, that is acceptable: if the app finds 3 of 7 tires, the clean-up team still goes there and finds all 7. A spot with **zero** detections is the real danger, and that happened mostly with the two weak classes.

### Decisions
1. Dataset v2 must add Cup and Plastic-Container boxes, not only Pail-Basin (already in Member 2's labeling table).
2. Our own Philippine photos go into the test set: these scores come from photos like the training ones, so real-world scores will likely be lower.
3. The app will use a lower confidence threshold (about 0.15) to favour recall.
4. The final model will try 75 to 100 epochs.

### What was checked
- The numbers in `docs/results.md` were copied from the notebook output (Steps 7 and 9).
- `best.pt` was downloaded from Drive, checked (5,495,514 bytes, same as Colab reported; valid file header), and stored as `models/aedex-v1-best.pt`, which git ignores.
- **Not yet done:** running the model on our own photos. That needs Ultralytics installed on a laptop or a Colab session.

### Check questions
1. A class has precision 1.00 and recall 0.40. In one sentence, how does the model behave on that class, and why is that bad for Aedex?
2. In the confusion matrix, where do you look to find objects the model missed completely? Where for false alarms?
3. Recall stopped improving at epoch 25, but mAP kept rising until epoch 50. What do the extra epochs improve, and what would improve recall instead?
4. Why do we trust the test score more because the validation score was almost the same?

## Part 5: Getting the model onto the phone (2026-11-26)

**Files:** [`notebooks/export_tflite.ipynb`](notebooks/export_tflite.ipynb) (the converter, runs on Colab), [`docs/model-for-app.md`](docs/model-for-app.md) (the contract with the app).
**Decision (2026-11-26):** no web demo. The app is built now with model v1, and model v2 is swapped in when it's ready, so the team sees the whole thing working early.

### Why convert at all
`best.pt` is a PyTorch file: it needs Python and PyTorch, which phones don't have. **TensorFlow Lite** is a format made for phones: small, fast, and Flutter has plugins that run it. Converting doesn't retrain anything. It rewrites the same learned numbers in a format the phone understands.

### Why it is built this way

| Choice | Why |
|---|---|
| **CPU runtime, no GPU** | Converting and checking are light work. No waiting for a free GPU |
| **Full 32-bit precision** (`quantize=None`) | Nothing is lost in the conversion. The file is about 10 MB, fine for a phone. An 8-bit version (`'w8a32'`) would be about 4 times smaller but can lose a little accuracy; we try it only if the app turns out slow |
| **Score both files on the test set** (Step 7) | A conversion can break a model silently, for example by mixing up colour order. If the `.tflite` scores like the `.pt` (within 0.02), the conversion is safe. We check instead of trusting |
| **Only the `test/` folder is unzipped** | The check needs 235 photos, not 4,979, so it skips most of the 1 GB zip |
| **Look at 3 photos** (Step 8) | Numbers can hide nonsense; our eyes catch it |
| **`labels.txt` beside the model** | The model only outputs class *numbers*. The app turns them into names with this file, so model v2's new class needs no code change |
| **Confidence 0.15 for the app** | Lower than YOLO's usual 0.25: more containers found, a few more false alarms. Recall matters most |
| **Version in the file names** (`aedex-v1.tflite`) | v1 and v2 files can never be confused |
| **Files go to Drive, not GitHub** | Model files are big binary files that change with every version; `.gitignore` keeps `*.tflite` out |

### A bug we hit: the tool changed under us
The first run failed at Step 5. Colab installs the newest Ultralytics each time, and version 8.4.218 had renamed the format `tflite` to `litert` (Google renamed TensorFlow Lite to LiteRT) and replaced `half=True` (16-bit) with `quantize`, which offers no 16-bit option. The error message itself listed the allowed values, so the fix was to read it and pick `quantize=None` (32-bit). Lesson: read the whole error, the answer is often in it. And when exact results matter, pin the version (`pip install ultralytics==8.4.218`).

### What the real run showed (2026-11-26)
- The export took 37 seconds and made a 10.7 MB file.
- **Step 7 said CHECK, but the model is fine.** mAP50 went from 0.800 to 0.815 and mAP50-95 from 0.583 to 0.588, while precision rose 0.06 and recall fell 0.03. Precision and recall are read at one point on a curve, where they balance best; a tiny numeric change slides that point, trading one for the other. mAP covers the whole curve, so it is the fair comparison. The first pass rule (all three within 0.02) was too strict, and the notebook now judges by mAP. Lesson: decide *which* number answers your question before you set a pass rule.
- **The input is channels first**, `[1, 3, 640, 640]`, not the `[1, 640, 640, 3]` phones often use. The new LiteRT tool keeps PyTorch's layout. A wrong layout gives no error, just nonsense, so `docs/model-for-app.md` warns Member 3 to test it first.
- In Step 8, a cup was found at confidence 0.20: YOLO's usual 0.25 cutoff would have hidden it, the app's 0.15 shows it.

### What comes out of the model
For one photo, the model gives **8,400 candidate boxes**, each with 4 box numbers and a score for every class (4 + 7 = 11 numbers). Almost all candidates have low scores. The app keeps those above 0.15 and removes duplicates that overlap too much (**non-maximum suppression**, NMS). What's left are the boxes you see, and counting them per class name gives the scan's `counts`.

### How swapping v1 for v2 works
v2 adds Pail-Basin as class 7, so the output grows from 11 to 12 numbers per candidate. If the app reads class names and their number from `labels.txt`, and keeps the model file name in one place, the swap is: run the export notebook with v2, copy two files into the app. `docs/model-for-app.md` lists the four rules the app follows.

### What was checked
- The notebook was generated by a script, and every code cell is valid Python.
- Step 7's "take only the test folder" code was run on our real `merged-v1.zip`: it extracted 235 photos and 235 label files.
- **Run on Colab on 2026-11-26:** all steps worked after the LiteRT fix; results below.

### Check questions
1. Why can't the phone app use `best.pt` directly?
2. What would 8-bit quantization (`'w8a32'`) gain and risk, and how would the notebook tell us if it hurt the model?
3. The model outputs the number 3 for a detection. How does the app know it's a tire, and why is that done with a file instead of code?
4. What two things must the app do with the 8,400 candidate boxes before it can count containers?

## Part 6: The hotspot map app, Phase 1 (2026-11-26)

**Folder:** `app/aedex_app/` (Flutter). **Branch:** `hotspot-map`. **Task file:** [`docs/tasks/member-3-hotspot-map.md`](docs/tasks/member-3-hotspot-map.md).
The app opens on a map of the scans. Each scan is one round pin showing how many containers were found, coloured by risk. Tapping a pin opens a card with the count for each class, the date, the location type and the clean-up status.

### Run it
```
cd app/aedex_app
flutter pub get
flutter run            # phone or emulator
flutter run -d chrome  # quick check in a browser, no phone needed
flutter test
```

### How the code is split, and why
| File | Job |
|---|---|
| `lib/models/scan.dart` | The **scan record** from the task file, as a Dart class. `Scan.fromJson` turns one JSON record into a `Scan`. `riskFor` holds the colour rule: 0 is clear, 1 to 3 is some, 4 or more is high. |
| `lib/data/scan_repository.dart` | **Where scans come from.** Today it reads `assets/sample_scans.json`. In Phase 2 the model's results come in here instead, and nothing else changes. |
| `lib/theme.dart` | All colours in one place, including the three risk colours and the readable text colour on each. |
| `lib/widgets/scan_pin.dart` | One pin: a circle with the total inside. |
| `lib/widgets/scan_card.dart` | The card for one scan: count bars per class, date, and the 4 clean-up steps. |
| `lib/screens/map_screen.dart` | Puts it together: loads the scans, draws the map and pins, and remembers which pin is selected. |

Keeping data, rules and drawing apart means each piece can be tested alone, and the map does not care whether scans come from a file or from the model.

### The map
- **flutter_map with OpenStreetMap tiles:** free, no API key. OSM requires credit on the map, so the bottom corner shows "OpenStreetMap contributors". Their free tile server is for light use; a public release would need a tile provider.
- **Layers stack like transparent sheets:** tiles at the bottom, then soft circles, then pins, then the credit line.
- **Street-level scans** (private homes) get a soft 60 m circle around the pin. It says "somewhere around here", so nobody can point at one house. Exact spots (public places) get no circle.
- **The camera fits all scans** when the map opens (`CameraFit.coordinates`), with extra space at the bottom for the card.
- **Tapping empty map** closes the card.

### State, in one sentence
The screen remembers one thing, the selected scan (`_selected`). Tapping a pin sets it, and `setState` makes Flutter redraw the screen: that pin gets a dark ring and its card slides in.

### Data notes
- `assets/sample_scans.json` is a copy of `app/sample_scans.json`, because Flutter can only bundle files inside the app folder. A test fails if the two copies ever differ.
- Times are stored with their time zone (`+08:00`) and shown in the phone's own time, so a phone in Manila shows the time the scan was taken.

### What was checked
- `flutter analyze`: no issues.
- `flutter test`: 8 tests pass. They cover the risk rule, loading all 10 sample scans, counts and status, the empty scan, class names, the two copies of the data matching, the card's content, and tapping a pin.
- **In a browser** (web build, phone-sized window): all 10 pins appear with the right colours and counts, street-level circles show, and tapping Scan 006 opened its card (Bottle 6, Drain Inlet 2, Cup 2, Nov 19 3:30 PM, Exact spot, Reported).
- **Not yet checked:** a real Android phone or emulator.

### Check questions
1. Why does the colour rule live in `scan.dart` and not inside the pin widget?
2. In Phase 2 the scans will come from the model instead of a file. Which file changes, and which files stay the same?
3. Why do street-level scans get a circle, and why 60 m instead of a pin-sized circle?
4. What does `setState` do when you tap a pin?
