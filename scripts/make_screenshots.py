"""Turns raw device screenshots into App Store screenshots with a caption.

Usage:
  python scripts/make_screenshots.py <raw-folder> <out-folder> [--ipad] [--captions="One|Two|Three"]

Put raw screenshots in <raw-folder>, named so they sort in upload order (1.png, 2.png, ...).
Captions come from CAPTIONS below, in the same order. Output sizes (portrait):
  iPhone 6.9"  1320 x 2868   (default)
  iPad 13"     2064 x 2752   (--ipad)
Output is RGB PNG with no transparency, as App Store Connect requires.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CAPTIONS = [
    "Learn to write Myanmar letters",
    "Write it. Get stars!",
    "Hear every letter",
    "Find the letter you hear",
    "Collect stickers every day",
]
TOP = (20, 52, 196)         # icon blue, #1434C4
BOTTOM = (6, 16, 92)        # icon navy, #06105C
FONTS = [
    "C:/Windows/Fonts/segoeuib.ttf",
    "/System/Library/Fonts/SFNS.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def font(size):
    for f in FONTS:
        if Path(f).exists():
            return ImageFont.truetype(f, size)
    return ImageFont.load_default(size)


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return img


def wrap(draw, text, fnt, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        test = (cur + " " + w).strip()
        if draw.textlength(test, font=fnt) <= max_w:
            cur = test
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def compose(raw, caption, size):
    W, H = size
    canvas = gradient(W, H)
    d = ImageDraw.Draw(canvas)

    # caption
    fnt = font(int(W * 0.068))
    lines = wrap(d, caption, fnt, W * 0.86)
    line_h = int(fnt.size * 1.2)
    y = int(H * 0.055)
    for line in lines:
        tw = d.textlength(line, font=fnt)
        d.text(((W - tw) / 2, y), line, font=fnt, fill=(255, 255, 255))
        y += line_h
    top_of_shot = y + int(H * 0.03)

    # screenshot, scaled to fit the remaining area, with rounded corners and a soft shadow
    shot = raw.convert("RGB")
    max_w, max_h = int(W * 0.84), H - top_of_shot - int(H * 0.04)
    scale = min(max_w / shot.width, max_h / shot.height)
    sw, sh = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    radius = int(sw * 0.09)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=radius, fill=255)
    x = (W - sw) // 2

    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([x, top_of_shot + 24, x + sw, top_of_shot + sh + 24],
                                             radius=radius, fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas.paste(Image.new("RGB", (W, H), (2, 6, 40)), (0, 0), shadow)
    canvas.paste(shot, (x, top_of_shot), mask)
    return canvas


def main():
    captions = CAPTIONS
    for a in sys.argv[1:]:
        if a.startswith("--captions="):
            captions = a.split("=", 1)[1].split("|")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        print(__doc__)
        sys.exit(1)
    src, out = Path(args[0]), Path(args[1])
    size = (2064, 2752) if "--ipad" in sys.argv else (1320, 2868)
    for a in sys.argv[1:]:
        if a.startswith("--size="):   # e.g. --size=1206x2622
            w, h = a.split("=", 1)[1].lower().split("x")
            size = (int(w), int(h))
    out.mkdir(parents=True, exist_ok=True)
    raws = sorted(p for p in src.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp", ".heic"))
    if not raws:
        print("No screenshots found in", src)
        sys.exit(1)
    for i, p in enumerate(raws):
        caption = captions[i] if i < len(captions) else ""
        img = compose(Image.open(p), caption, size)
        dest = out / f"{i + 1:02d}-{size[0]}x{size[1]}.png"
        img.save(dest, optimize=True)
        print("wrote", dest, img.size, img.mode)


if __name__ == "__main__":
    main()
