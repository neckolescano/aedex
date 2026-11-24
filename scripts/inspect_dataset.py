"""
Inspect a YOLO-format object detection dataset (a Roboflow export zip or an unzipped folder).

Why this exists: before training on someone else's data, we look at it. This script answers:
  * Which classes are there, and in what order (the order = the class numbers in the label files)?
  * How many images and boxes per split (train / valid / test) and per class?
  * Are there problems: images without labels, empty labels, boxes outside the image, tiny boxes?
  * Were augmented copies included, and could copies of one photo leak across splits?
  * If we drop a class (e.g. Larva), how many images end up with no boxes at all?

Usage (from the project folder):
  python scripts/inspect_dataset.py "datasets/graces/grace-s.v1i.yolov11.zip" --drop Larva
  python scripts/inspect_dataset.py "datasets/vistext/Breeding Place Detection.zip" --save docs/inspect-vistext.txt

Only the Python standard library is used, so it runs anywhere Python 3 is installed.
"""

import argparse
import ast
import collections
import posixpath
import re
import sys
import zipfile
from pathlib import Path

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SPLIT_ALIASES = {"train": "train", "valid": "valid", "val": "valid", "test": "test"}

# A box is "tiny" when it covers less than this share of the image (0.0005 = 0.05%).
# At 640x640 that is about a 14x14 pixel box: too small to see from a normal phone distance.
TINY_AREA = 0.0005
# A box thinner than this (as a share of image width or height) is a "strip": usually a labeling slip.
THIN_SIDE = 0.01

# Roboflow names exported files like  photo_123_jpg.rf.<random hash>.jpg
# Everything before ".rf." is the ORIGINAL photo's name, so copies of one photo share it.
RF_SUFFIX = re.compile(r"\.rf\.[0-9a-f]+$", re.IGNORECASE)


# ---------------------------------------------------------------- reading files from a zip or a folder
class Source:
    """Lets the rest of the script read a zip and a folder the same way."""

    def __init__(self, path: Path):
        self.path = path
        self.is_zip = path.suffix.lower() == ".zip"
        if self.is_zip:
            self.zip = zipfile.ZipFile(path)
            # A zip can list the same name twice; keep each once. Use forward slashes everywhere.
            self.files = sorted({n.replace("\\", "/") for n in self.zip.namelist() if not n.endswith("/")})
        else:
            self.files = sorted(p.relative_to(path).as_posix() for p in path.rglob("*") if p.is_file())

    def read_text(self, name: str) -> str:
        if self.is_zip:
            return self.zip.read(name).decode("utf-8", "replace")
        return (self.path / name).read_text("utf-8", "replace")


# ---------------------------------------------------------------- data.yaml
def parse_data_yaml(text: str) -> dict:
    """Read the few keys we need from data.yaml without needing the PyYAML package."""
    info = {"names": None, "nc": None}
    lines = text.splitlines()
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("nc:"):
            info["nc"] = int(stripped.split(":", 1)[1].strip())
        elif stripped.startswith("names:"):
            value = stripped.split(":", 1)[1].strip()
            if value.startswith("["):  # names: ['a', 'b']
                info["names"] = list(ast.literal_eval(value))
            else:  # names given as a block list ("- a") or a map ("0: a") on the following lines
                names = []
                for nxt in lines[i + 1:]:
                    s = nxt.strip()
                    if not s or not (nxt.startswith(" ") or nxt.startswith("-")):
                        break
                    s = s[1:].strip() if s.startswith("-") else s.split(":", 1)[1].strip()
                    names.append(s.strip("'\""))
                info["names"] = names
    return info


# ---------------------------------------------------------------- the inspection
def split_of(path: str):
    """'train/images/a.jpg' -> 'train'. Returns None for files outside a split folder."""
    for part in path.split("/"):
        if part.lower() in SPLIT_ALIASES:
            return SPLIT_ALIASES[part.lower()]
    return None


def original_name(path: str) -> str:
    """'train/images/photo_1_jpg.rf.abc123.jpg' -> 'photo_1_jpg' (the photo before Roboflow's copies)."""
    stem = posixpath.splitext(posixpath.basename(path))[0]
    return RF_SUFFIX.sub("", stem)


def inspect(src: Source, drop: set) -> list:
    out = []
    say = out.append

    # 1. Config and notes -------------------------------------------------------------------
    yamls = [f for f in src.files if posixpath.basename(f).lower() in ("data.yaml", "data.yml")]
    if not yamls:
        say("No data.yaml found. This does not look like a YOLO export.")
        return out
    cfg = parse_data_yaml(src.read_text(yamls[0]))
    names = cfg["names"] or []
    say(f"Config file: {yamls[0]}")
    say(f"Classes ({len(names)}), in label-number order:")
    for idx, n in enumerate(names):
        say(f"  {idx} = {n}" + ("   <- will be dropped" if n in drop else ""))
    unknown_drop = drop - set(names)
    if unknown_drop:
        say(f"  Note: --drop names not in this dataset: {', '.join(sorted(unknown_drop))}")

    readme = [f for f in src.files if posixpath.basename(f).lower() == "readme.roboflow.txt"]
    if readme:
        # Keep only the part of the README that describes THIS export (it starts at "The dataset includes").
        text = src.read_text(readme[0])
        start = text.find("The dataset includes")
        notes = [l.strip() for l in text[start:].splitlines() if l.strip()] if start >= 0 else []
        if notes:
            say("")
            say("Export notes (from README.roboflow.txt):")
            for l in notes:
                say(f"  {l}")

    # 2. Pair every image with its label file --------------------------------------------------
    images = [f for f in src.files if posixpath.splitext(f)[1].lower() in IMAGE_EXTS and split_of(f)]
    labels = {f for f in src.files if f.endswith(".txt") and "/labels/" in f"/{f}"}

    per_split = collections.defaultdict(lambda: collections.Counter())
    boxes_per_class = collections.defaultdict(collections.Counter)     # split -> class -> boxes
    images_per_class = collections.defaultdict(collections.Counter)    # split -> class -> images
    problems = collections.defaultdict(list)                           # kind -> [file, ...]
    only_dropped = collections.Counter()                               # split -> images left with no boxes
    originals = collections.defaultdict(set)                           # original photo -> {splits}
    copies = collections.Counter()                                     # original photo -> number of files

    for img in images:
        split = split_of(img)
        per_split[split]["images"] += 1
        orig = original_name(img)
        originals[orig].add(split)
        copies[orig] += 1

        label = re.sub(r"/images/", "/labels/", f"/{img}", count=1)[1:]
        label = posixpath.splitext(label)[0] + ".txt"
        if label not in labels:
            per_split[split]["no label file"] += 1
            problems["image with no label file"].append(img)
            continue

        rows = [r.split() for r in src.read_text(label).splitlines() if r.strip()]
        if not rows:
            per_split[split]["empty label (background)"] += 1
            continue

        kept = 0
        seen_classes = set()
        for r in rows:
            if len(r) == 5:  # a normal box: class x_center y_center width height (all 0..1)
                cls = int(float(r[0]))
                x, y, w, h = map(float, r[1:])
            elif len(r) >= 7 and len(r) % 2 == 1:
                # A polygon: class x1 y1 x2 y2 ... traced around the object. YOLO training turns it
                # into the smallest box around those points, so we do the same here to count it.
                cls = int(float(r[0]))
                xs, ys = list(map(float, r[1::2])), list(map(float, r[2::2]))
                x, y = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
                w, h = max(xs) - min(xs), max(ys) - min(ys)
                per_split[split]["polygon outlines (used as boxes)"] += 1
            else:
                problems["line that is neither a box nor a polygon"].append(label)
                continue
            name = names[cls] if 0 <= cls < len(names) else f"unknown #{cls}"
            boxes_per_class[split][name] += 1
            seen_classes.add(name)
            if name not in drop:
                kept += 1
            if not (0 <= x <= 1 and 0 <= y <= 1) or x - w / 2 < -0.01 or x + w / 2 > 1.01 \
                    or y - h / 2 < -0.01 or y + h / 2 > 1.01:
                problems["box partly outside the image"].append(f"{label}  ({name})")
            if w * h < TINY_AREA:
                problems[f"tiny box (< {TINY_AREA:.2%} of the image)"].append(f"{label}  ({name})")
            elif min(w, h) < THIN_SIDE:
                problems["thin strip box (one side < 1%)"].append(f"{label}  ({name})")
        for name in seen_classes:
            images_per_class[split][name] += 1
        per_split[split]["boxes"] += len(rows)
        if drop and kept == 0:
            only_dropped[split] += 1

    # 3. Report ---------------------------------------------------------------------------------
    splits = [s for s in ("train", "valid", "test") if s in per_split]
    total_imgs = sum(per_split[s]["images"] for s in splits)
    say("")
    say(f"Images: {total_imgs}")
    for s in splits:
        c = per_split[s]
        share = c["images"] / total_imgs if total_imgs else 0
        extra = ", ".join(f"{k}: {v}" for k, v in c.items() if k not in ("images", "boxes"))
        say(f"  {s:<5} {c['images']:6d} images ({share:5.1%})   {c['boxes']:6d} boxes" + (f"   [{extra}]" if extra else ""))

    say("")
    say("Boxes per class (images containing it in brackets):")
    header = "  " + "class".ljust(18) + "".join(s.rjust(16) for s in splits) + "total".rjust(10)
    say(header)
    all_names = names + sorted({n for s in splits for n in boxes_per_class[s]} - set(names))
    grand = sum(sum(boxes_per_class[s].values()) for s in splits)
    for n in all_names:
        cells = "".join(f"{boxes_per_class[s][n]:>7} [{images_per_class[s][n]:>5}]" for s in splits)
        tot = sum(boxes_per_class[s][n] for s in splits)
        share = f"{tot / grand:6.1%}" if grand else ""
        say(f"  {n:<18}{cells}{tot:>10} {share}" + ("  (dropped)" if n in drop else ""))

    # Augmented copies and leakage
    multi = {o: n for o, n in copies.items() if n > 1}
    say("")
    say(f"Original photos: {len(copies)}   (files that are copies of the same photo: {sum(multi.values())} in {len(multi)} groups)")
    if multi:
        sizes = collections.Counter(multi.values())
        say("  Copies per photo: " + ", ".join(f"{k} files x {v} photos" for k, v in sorted(sizes.items())))
    leaked = {o: sp for o, sp in originals.items() if len(sp) > 1}
    if leaked:
        say(f"  WARNING data leakage: {len(leaked)} photos appear in more than one split, e.g.")
        for o, sp in list(leaked.items())[:5]:
            say(f"    {o}: {', '.join(sorted(sp))}")
    else:
        say("  No photo appears in more than one split (no leakage between train/valid/test).")

    if drop:
        say("")
        say(f"After dropping {', '.join(sorted(drop))}: images left with NO boxes:")
        for s in splits:
            say(f"  {s:<5} {only_dropped[s]:6d}")
        say("  These images would teach the model 'nothing here'. Relabel them or remove them.")

    say("")
    if problems:
        say("Possible problems:")
        for kind, items in problems.items():
            say(f"  {kind}: {len(items)}")
            for item in items[:3]:
                say(f"      e.g. {item}")
    else:
        say("No label problems found.")
    return out


def main():
    ap = argparse.ArgumentParser(description="Inspect a YOLO detection dataset (zip or folder).")
    ap.add_argument("dataset", help="path to the export .zip or an unzipped folder")
    ap.add_argument("--drop", default="", help="comma-separated class names you plan to drop, e.g. Larva")
    ap.add_argument("--save", help="also write the report to this text file")
    args = ap.parse_args()

    path = Path(args.dataset)
    if not path.exists():
        sys.exit(f"Not found: {path}")
    drop = {d.strip() for d in args.drop.split(",") if d.strip()}

    report = [f"Dataset: {path}", ""] + inspect(Source(path), drop)
    text = "\n".join(report)
    print(text)
    if args.save:
        Path(args.save).parent.mkdir(parents=True, exist_ok=True)
        Path(args.save).write_text(text + "\n", encoding="utf-8")
        print(f"\nSaved to {args.save}")


if __name__ == "__main__":
    main()
