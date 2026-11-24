"""
Merge several YOLO datasets into ONE dataset with OUR class list.

What it does, in order:
  1. Reads each source (zip or folder) and its data.yaml.
  2. Remaps class numbers: each source numbers its classes differently (in VisText 3 = Tire,
     in grace's 3 = Pail), so every label line is rewritten to OUR numbers.
  3. Drops classes we don't use yet (Larva, Pail) and removes images that end up with no boxes
     because of that (they would teach the model "this is nothing").
  4. Turns polygon outlines into plain boxes, so every label line has 5 numbers.
  5. Assigns train/valid/test while keeping all copies of one photo in the same split (no leakage):
       - "keep":    keep the source's own split, but move leaking photos into train.
       - "resplit": make a fresh 80/10/10 split that spreads every class across all three splits.
  6. Writes the merged dataset + data.yaml + a MERGE-REPORT.txt, and can zip it for Google Colab.

Usage (from the project folder):
  python scripts/merge_datasets.py                 # builds datasets/merged/v1
  python scripts/merge_datasets.py --zip           # also makes datasets/merged/merged-v1.zip
  python scripts/merge_datasets.py --overwrite     # rebuild if v1 already exists

To add a dataset or a class later: edit CLASSES and SOURCES below, bump VERSION, run again.
"""

import argparse
import collections
import hashlib
import posixpath
import random
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_dataset import IMAGE_EXTS, Source, original_name, parse_data_yaml, split_of  # noqa: E402

PROJECT = Path(__file__).resolve().parent.parent
VERSION = "v1"

# OUR classes. The position is the class number. NEVER reorder: add new classes at the end
# (Pail-Basin will become 7), so labels made earlier stay correct.
CLASSES = ["Bottle", "Coconut-Exocarp", "Drain-Inlet", "Tire", "Vase", "Cup", "Plastic-Container"]

# Each source: where it is, how its class names map onto ours (None = drop), how to split.
SOURCES = [
    {
        "id": "vistext",
        "path": "datasets/vistext/Breeding Place Detection.zip",
        "map": {"Bottle": "Bottle", "Coconut-Exocarp": "Coconut-Exocarp", "Drain-Inlet": "Drain-Inlet",
                "Tire": "Tire", "Vase": "Vase"},
        "split": "keep",       # its train already holds the brightness copies; valid/test are clean
    },
    {
        "id": "graces",
        "path": "datasets/graces/grace-s.v1i.yolov11.zip",
        "map": {"Container": "Plastic-Container", "Cup": "Cup", "Larva": None, "Pail": None,
                "Pot": "Vase", "Tire": "Tire"},
        "split": "resplit",    # its Pot boxes sat almost all in train; a fresh split spreads them out
    },
]

SPLIT_RATIOS = {"valid": 0.10, "test": 0.10}   # the rest goes to train
SEED = 42                                       # same seed = same split every time we rebuild


# ---------------------------------------------------------------- reading one source
def label_path_for(image_path: str) -> str:
    label = re.sub(r"/images/", "/labels/", f"/{image_path}", count=1)[1:]
    return posixpath.splitext(label)[0] + ".txt"


def to_box(parts):
    """A label line -> (class, x, y, w, h). Polygons become the smallest box around their points."""
    cls = int(float(parts[0]))
    if len(parts) == 5:
        return (cls, *map(float, parts[1:]))
    xs, ys = list(map(float, parts[1::2])), list(map(float, parts[2::2]))
    return (cls, (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, max(xs) - min(xs), max(ys) - min(ys))


def clamp_box(x, y, w, h):
    """Keep the box inside the image (0..1); a few exports have edges a hair outside."""
    x0, y0, x1, y1 = max(0.0, x - w / 2), max(0.0, y - h / 2), min(1.0, x + w / 2), min(1.0, y + h / 2)
    return (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0


def read_source(cfg, stats):
    """Returns a list of items: {src, image, split, group, boxes:[(our_cls, x, y, w, h)]}."""
    src = Source(PROJECT / cfg["path"])
    yaml = next(f for f in src.files if posixpath.basename(f).lower() in ("data.yaml", "data.yml"))
    names = parse_data_yaml(src.read_text(yaml))["names"]
    missing = set(names) - set(cfg["map"])
    if missing:
        sys.exit(f"[{cfg['id']}] classes with no mapping: {sorted(missing)}. Add them to SOURCES (None = drop).")

    # source class number -> our class number (or None)
    remap = {i: (CLASSES.index(cfg["map"][n]) if cfg["map"][n] else None) for i, n in enumerate(names)}
    s = stats[cfg["id"]]
    items = []
    labels = set(src.files)
    for img in src.files:
        if posixpath.splitext(img)[1].lower() not in IMAGE_EXTS or not split_of(img):
            continue
        s["images in source"] += 1
        lab = label_path_for(img)
        if lab not in labels:
            s["removed: no label file"] += 1
            continue
        rows = [r.split() for r in src.read_text(lab).splitlines() if r.strip()]
        boxes, dropped = [], 0
        for r in rows:
            if len(r) < 5 or (len(r) > 5 and len(r) % 2 == 0):
                s["bad label lines skipped"] += 1
                continue
            cls, x, y, w, h = to_box(r)
            ours = remap.get(cls)
            if ours is None:
                dropped += 1
                continue
            x, y, w, h = clamp_box(x, y, w, h)
            if w <= 0 or h <= 0:
                s["empty boxes skipped"] += 1
                continue
            boxes.append((ours, x, y, w, h))
        if not boxes and dropped:
            # Every box in this image was a class we dropped -> the image would say "nothing here".
            s["removed: only dropped classes (e.g. Larva, Pail)"] += 1
            continue
        if not boxes:
            s["kept: background (no boxes at all)"] += 1
        items.append({"src": src, "source": cfg["id"], "image": img, "split": split_of(img),
                      "group": f"{cfg['id']}:{original_name(img)}", "boxes": boxes})
    return items


# ---------------------------------------------------------------- splitting
def keep_split(items, stats, source_id):
    """Keep each photo's split, but if copies of one photo sit in two splits, put them all in train."""
    groups = collections.defaultdict(list)
    for it in items:
        groups[it["group"]].append(it)
    for members in groups.values():
        if len({m["split"] for m in members}) > 1:
            stats[source_id]["leaking photos moved to train"] += 1
            for m in members:
                m["split"] = "train"


def resplit(items, seed):
    """
    Fresh split by photo group, spread per class. Each group is filed under its RAREST class, then each
    class's groups are shuffled and cut 10% test / 10% valid / 80% train. So even a rare class lands in
    all three splits (unless it has fewer than ~5 photos).
    """
    groups = collections.defaultdict(list)
    for it in items:
        groups[it["group"]].append(it)
    freq = collections.Counter(b[0] for it in items for b in it["boxes"])
    by_key = collections.defaultdict(list)
    for g, members in groups.items():
        classes = {b[0] for m in members for b in m["boxes"]}
        key = min(classes, key=lambda c: freq[c]) if classes else -1
        by_key[key].append(g)
    rng = random.Random(seed)
    for key in sorted(by_key):
        gs = sorted(by_key[key])
        rng.shuffle(gs)
        n = len(gs)
        n_test = round(n * SPLIT_RATIOS["test"])
        n_valid = round(n * SPLIT_RATIOS["valid"])
        if n >= 5:  # make sure a small class still gets at least one test and one valid photo
            n_test, n_valid = max(1, n_test), max(1, n_valid)
        for i, g in enumerate(gs):
            split = "test" if i < n_test else "valid" if i < n_test + n_valid else "train"
            for m in groups[g]:
                m["split"] = split


# ---------------------------------------------------------------- writing
def write_dataset(items, out: Path):
    for split in ("train", "valid", "test"):
        (out / split / "images").mkdir(parents=True, exist_ok=True)
        (out / split / "labels").mkdir(parents=True, exist_ok=True)
    for it in items:
        # Name = source id + start of the original photo name + photo fingerprint + ".rf." + file fingerprint.
        #   - the source id stops two sources overwriting each other's files
        #   - the photo fingerprint is the same for every copy of one photo, so the inspector can still
        #     group copies and check for leakage (it treats everything before ".rf." as the photo)
        #   - the file fingerprint keeps each copy's name unique
        #   - everything stays short: Windows refuses paths longer than 260 characters
        photo_fp = hashlib.sha1(it["group"].encode()).hexdigest()[:8]
        file_fp = hashlib.sha1(it["image"].encode()).hexdigest()[:8]
        stem = f"{it['source']}__{original_name(it['image'])[:60]}_{photo_fp}.rf.{file_fp}"
        ext = posixpath.splitext(it["image"])[1].lower()
        data = it["src"].zip.read(it["image"]) if it["src"].is_zip else (it["src"].path / it["image"]).read_bytes()
        (out / it["split"] / "images" / f"{stem}{ext}").write_bytes(data)
        lines = [f"{c} {x:.6f} {y:.6f} {w:.6f} {h:.6f}" for c, x, y, w, h in it["boxes"]]
        (out / it["split"] / "labels" / f"{stem}.txt").write_text("\n".join(lines) + ("\n" if lines else ""))

    yaml = [
        "# Merged by scripts/merge_datasets.py. Paths are relative to this file's folder.",
        "train: train/images", "val: valid/images", "test: test/images", "",
        f"nc: {len(CLASSES)}", f"names: {CLASSES}", "",
        "sources:",
    ] + [f"  - {s['id']}: {s['path']}" for s in SOURCES]
    (out / "data.yaml").write_text("\n".join(yaml) + "\n")


def report(items, stats):
    lines = [f"Merged dataset {VERSION}", "", "Per source:"]
    for sid, s in stats.items():
        lines.append(f"  {sid}")
        for k, v in s.items():
            lines.append(f"    {k}: {v}")
    lines += ["", "Images per split:"]
    per_split = collections.Counter(it["split"] for it in items)
    for sp in ("train", "valid", "test"):
        lines.append(f"  {sp:<5} {per_split[sp]:6d}")
    lines += ["", "Boxes per class (train / valid / test / total):"]
    counts = collections.defaultdict(collections.Counter)
    for it in items:
        for b in it["boxes"]:
            counts[it["split"]][b[0]] += 1
    for i, name in enumerate(CLASSES):
        t, v, te = counts["train"][i], counts["valid"][i], counts["test"][i]
        lines.append(f"  {i} {name:<18} {t:6d} {v:6d} {te:6d} {t + v + te:7d}")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="Merge YOLO datasets into one with our class list.")
    ap.add_argument("--out", default=f"datasets/merged/{VERSION}", help="output folder")
    ap.add_argument("--overwrite", action="store_true", help="delete and rebuild the output folder")
    ap.add_argument("--zip", action="store_true", help="also zip the result (for uploading to Google Drive)")
    args = ap.parse_args()

    out = PROJECT / args.out
    if out.exists():
        if not args.overwrite:
            sys.exit(f"{out} already exists. Use --overwrite to rebuild it.")
        if PROJECT / "datasets" not in out.resolve().parents:
            sys.exit("Refusing to delete a folder outside datasets/.")
        shutil.rmtree(out)

    stats = collections.defaultdict(collections.Counter)
    items = []
    for cfg in SOURCES:
        print(f"Reading {cfg['id']} ...")
        got = read_source(cfg, stats)
        if cfg["split"] == "keep":
            keep_split(got, stats, cfg["id"])
        else:
            resplit(got, SEED)
        stats[cfg["id"]]["images kept"] = len(got)
        items += got

    print(f"Writing {len(items)} images to {out} ...")
    write_dataset(items, out)
    text = report(items, stats)
    (out / "MERGE-REPORT.txt").write_text(text + "\n")
    print()
    print(text)

    if args.zip:
        print("\nZipping for upload ...")
        archive = shutil.make_archive(str(out.parent / f"merged-{VERSION}"), "zip", root_dir=out)
        print(f"Zip: {archive}")


if __name__ == "__main__":
    main()
