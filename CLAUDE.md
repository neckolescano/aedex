# CLAUDE.md — Aedex

Instructions for AI assistants (Claude Code reads this file automatically). Humans: this is also a good summary of the project.

## The project
**Aedex** finds mosquito breeding sites in photos: a YOLO object detection model draws a box around every container that can hold rainwater, and an app pins the results on a map so barangays and clean-up groups know where to clean. A three-person student team builds it to learn machine learning and app development.

- Repo: https://github.com/neckolescano/aedex
- How every part was built and why: `BUILD-WALKTHROUGH.md`
- Quick start and credits: `README.md`

## Who you are helping
1. Run `git config user.name` and `git config user.email`, and match them against the roster below.
2. If nothing matches, ask: "Which team member are you: 1 (model), 2 (Pail-Basin data) or 3 (hotspot map app)?"
3. Read that member's task file before doing anything else, and greet them with where their task stands.

| # | Member | GitHub | Role | Task file |
|---|---|---|---|---|
| 1 | Nicho | neckolescano | Model lead | `docs/tasks/member-1-model.md` |
| 2 | (add your name) | (add your username) | Data lead: Pail-Basin | `docs/tasks/member-2-pail-basin-data.md` |
| 3 | (add your name) | (add your username) | App lead: hotspot map | `docs/tasks/member-3-hotspot-map.md` |

Members 2 and 3: fill in your row in your first pull request.

## How to work with this team
- **Build and teach.** The team wants to finish fast AND learn. You may write the code, but explain each part in plain words: what it does and why it is built that way. Add a short section for each new part to `BUILD-WALKTHROUGH.md`, ending with 2 to 4 check questions.
- **Wait for the go.** Explain the plan for a step, then start when the member says so.
- **Never commit to `main`.** Before any commit: `git checkout main`, `git pull`, `git checkout -b <task-name>`. Push the branch and ask the member to open a pull request; another member reviews it.
- **Check before claiming.** Say what you ran and what you could not run (training needs a GPU on Kaggle or Colab; the phone app needs a device or emulator).

## Facts that must not drift
- **Class order is fixed.** The position is the label number; new classes are only added at the end:
  `0 Bottle, 1 Coconut-Exocarp, 2 Drain-Inlet, 3 Tire, 4 Vase, 5 Cup, 6 Plastic-Container`, next is `7 Pail-Basin`.
- **Big files stay off GitHub:** `datasets/`, `photos/`, `models/` are in `.gitignore`. Share them through Roboflow, Kaggle or Google Drive.
- **Datasets:** VisText-Mosquito (CC BY 4.0, credit required) and grace's (Public Domain). Credits live in `README.md`; update them when a source is added.
- **Build datasets with the scripts,** never by hand: `scripts/inspect_dataset.py` to check, `scripts/merge_datasets.py` to merge (it remaps classes, drops classes, prevents leakage).
- **Recall matters most:** a missed breeding site is worse than a false alarm.
- **Privacy:** public data must not show faces, house numbers or plate numbers, and maps show rough locations for private homes.
- **The app uses the model on the phone** (decided 2026-11-26, no web demo). Model v1 is `aedex-v1.tflite` + `labels.txt`, shared through the Google Drive folder `app-model` (never committed: `*.tflite` is ignored). Its contract is `docs/model-for-app.md`: input `[1, 3, 640, 640]` channels first, confidence 0.15, class names read from `labels.txt` so model v2 is a file swap.

## Commands
```
python scripts/inspect_dataset.py <dataset.zip or folder> [--drop Larva]
python scripts/merge_datasets.py [--zip] [--overwrite]
```
Training: `notebooks/train_baseline_kaggle.ipynb` on Kaggle (or `train_baseline.ipynb` on Colab).
Phone model: `notebooks/export_tflite.ipynb` on Colab (CPU is enough).
