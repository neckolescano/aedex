# Aedex

**AI that finds mosquito breeding sites.** *Aedes* (the dengue mosquito) + *index*.

Point a phone at a yard or street, and Aedex draws a box around every container that can hold rainwater (tires, bottles, flower pots, coconut shells, drain inlets, cups and plastic containers) and counts them, so households, barangay health workers and clean-up groups know what to clean up before dengue season.

New to the project? Read [BUILD-WALKTHROUGH.md](BUILD-WALKTHROUGH.md): it explains how every part was built and why.

**Team tasks:** [Member 1, model](docs/tasks/member-1-model.md) · [Member 2, Pail-Basin data](docs/tasks/member-2-pail-basin-data.md) · [Member 3, hotspot map](docs/tasks/member-3-hotspot-map.md). Working with an AI assistant? It reads [CLAUDE.md](CLAUDE.md) first, so just tell it which member you are.

## Where the project is

| Step | What | Status |
|---|---|---|
| 1 | Data: starter dataset chosen, license checked | Done |
| 2 | Inspect and merge the datasets | Done: `datasets/merged/v1` (7 classes, 4,979 images); our own photos still being collected |
| 3 | Train a first model | Notebooks built for Colab and Kaggle; first run in progress on Kaggle |
| 4 | Improve: find misses, add photos, retrain | After step 3 |
| 5 | Web demo: upload a photo, see boxes and counts | Not built yet |
| 6 | Flutter app with a map | Later |

## Folder layout

```
aedex/
  README.md             this file
  BUILD-WALKTHROUGH.md  how each part was built and why (read this to learn it)
  scripts/              inspect_dataset.py, merge_datasets.py
  notebooks/            training notebooks (Colab and Kaggle versions)
  docs/                 inspection reports and the training results log
  datasets/             dataset zips and the merged dataset (not on GitHub: too large)
  photos/               our own raw photos (not on GitHub; they go to Roboflow)
  models/               trained model files such as best.pt (not on GitHub)
  app/                  Flutter app (later)
```

## Quick start

Datasets are not stored on GitHub. Ask the team for the two source zips, or download them (see Credits).

1. Put them in place:
   - `datasets/vistext/Breeding Place Detection.zip`
   - `datasets/graces/grace-s.v1i.yolov11.zip`
2. Look inside one: `python scripts/inspect_dataset.py "datasets/graces/grace-s.v1i.yolov11.zip" --drop Larva`
3. Build the merged dataset: `python scripts/merge_datasets.py --zip`
4. Train: upload `datasets/merged/merged-v1.zip` and run `notebooks/train_baseline_kaggle.ipynb` on Kaggle (or `train_baseline.ipynb` on Google Colab). Each notebook explains itself step by step.
5. Download the `best.pt` it saves into `models/`, and add the scores to `docs/results.md`.

The scripts need only Python 3; the notebooks install everything else themselves.

## Photo naming

`<your initials>_<YYYYMMDD>_<number>.jpg`, for example `NL_20261123_001.jpg`.

## Credits

Training data:
- **VisText-Mosquito** by Islam et al. (CVPR Workshops 2026), used under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), from [Mendeley Data](https://data.mendeley.com/datasets/rtsfh7jh7p).
- **grace's** by ROVER on [Roboflow Universe](https://universe.roboflow.com/rover-0qmve/grace-s), Public Domain.

Changes we made: merged both into one 7-class dataset, renamed classes (Pot → Vase, Container → Plastic-Container), removed the Larva and Pail labels and the images left without boxes, converted polygon labels to boxes, and re-split the data to avoid leakage. Our own photos from the Philippines will be added in later versions.

```bibtex
@InProceedings{Islam_2026_CVPR,
    author    = {Islam, Md. Adnanul and Sayeedi, Md. Faiyaz Abdullah and Shuvo, Md. Asaduzzaman and Bappy, Shahanur Rahman and Rahman, Muhammad Ziaur and Islam, Md Asiful and Shatabda, Swakkhar},
    title     = {VisText-Mosquito: A Unified Multimodal Dataset for Visual Detection, Segmentation, and Textual Explanation on Mosquito Breeding Sites},
    booktitle = {Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR) Workshops},
    month     = {June},
    year      = {2026},
    pages     = {9165-9173}
}
```

This tool flags possible breeding sites from photos. It does not replace an inspection by health workers.
