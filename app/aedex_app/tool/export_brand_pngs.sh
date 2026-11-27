#!/usr/bin/env bash
# Makes the PNG launcher icons (Android 7.x only; newer phones use the
# adaptive vector icon) from assets/brand/patak-submark.svg.
#
# How: the installed Chrome (headless) draws one big 512 px icon, then
# Python's Pillow crops it and shrinks it to each Android size. Shrinking
# one big drawing gives cleaner small icons than drawing each size.
#
# Run from app/aedex_app in Git Bash:  bash tool/export_brand_pngs.sh
# Needs: Chrome, Python 3 with Pillow (pip install pillow).
set -euo pipefail

CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
APP="$(cd "$(dirname "$0")/.." && pwd)"
RES="$APP/android/app/src/main/res"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$APP/assets/brand/patak-submark.svg" "$WORK/submark.svg"
# A 512 px cobalt rounded square with the submark in the middle, in the
# top-left corner of a bigger window (Chrome lays out tiny windows wider
# than asked, so the window is roomy and the icon is cropped out after).
cat > "$WORK/icon.html" <<'HTML'
<!doctype html><style>
html,body{margin:0;background:transparent;overflow:hidden}
.icon{position:absolute;left:0;top:0;width:512px;height:512px}
.tile{position:absolute;inset:20px;border-radius:108px;background:#1F3FBF;
  display:flex;align-items:center;justify-content:center}
.tile img{width:70%;height:70%}
</style><div class="icon"><div class="tile"><img src="submark.svg"></div></div>
HTML

win() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --default-background-color=00000000 \
  --window-size=800,800 --screenshot="$(win "$WORK/big.png")" \
  "file:///$(win "$WORK/icon.html")" >/dev/null 2>&1

# density folder : size in pixels (48 dp at each density)
python - "$(win "$WORK/big.png")" "$(win "$RES")" <<'PY'
import sys
from PIL import Image
big, res = sys.argv[1], sys.argv[2]
icon = Image.open(big).convert("RGBA").crop((0, 0, 512, 512))
for folder, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                   ("xxhdpi", 144), ("xxxhdpi", 192)]:
    icon.resize((px, px), Image.LANCZOS).save(
        f"{res}/mipmap-{folder}/ic_launcher.png")
    print(f"mipmap-{folder}/ic_launcher.png  {px}x{px}")
PY
