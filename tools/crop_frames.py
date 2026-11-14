#!/usr/bin/env python3
"""El karelerini ortak sınırla kırpar, ortalar, ölçekler."""
import glob, os
from PIL import Image

SRC = os.path.expanduser("~/color-fall-puzzle/assets/hand_frames")
OUT = os.path.join(SRC, "aligned")
SIZE = 256
PAD = 6

files = sorted(glob.glob(os.path.join(SRC, "idle_*.png")) +
               glob.glob(os.path.join(SRC, "snap_*.png")) +
               glob.glob(os.path.join(SRC, "clap_*.png")))

boxes = []
for f in files:
    im = Image.open(f).convert("RGBA")
    boxes.append(im.getbbox() or (0, 0, im.width, im.height))

x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
x0 = max(0, x0 - PAD); y0 = max(0, y0 - PAD)
x1 += PAD; y1 += PAD

w, h = x1 - x0, y1 - y0
side = max(w, h)
cx = (x0 + x1) // 2
cy = (y0 + y1) // 2

os.makedirs(OUT, exist_ok=True)
for f in files:
    im = Image.open(f).convert("RGBA")
    # ortak kareyi al (kare dışına taşarsa saydam doldur)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, (side // 2 - cx, side // 2 - cy), im)
    canvas = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    canvas.save(os.path.join(OUT, os.path.basename(f)))

print("kare:", len(files), "kutu:", (x0, y0, x1, y1), "side:", side)

cols = 8
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGBA", (SIZE * cols, SIZE * rows), (16, 17, 26, 255))
for i, f in enumerate(files):
    im = Image.open(os.path.join(OUT, os.path.basename(f)))
    sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE), im)
sheet.convert("RGB").save("/tmp/opencode/ref/frames_sheet.png")
print("sheet:", sheet.size)
