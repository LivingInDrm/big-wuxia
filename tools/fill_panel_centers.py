#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TEXTURE_DIR = ROOT / "resources" / "ui" / "textures" / "wuxia"
PAPER_WHITE = (242, 237, 224, 255)
TARGETS = ("main_panel.png", "tooltip_panel.png")


def fill_transparent_pixels(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    filled = 0

    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] < 128:
                pixels[x, y] = PAPER_WHITE
                filled += 1

    image.save(path)
    print(f"[ok] {path.relative_to(ROOT)} filled={filled}")


def main() -> None:
    for name in TARGETS:
        fill_transparent_pixels(TEXTURE_DIR / name)


if __name__ == "__main__":
    main()
