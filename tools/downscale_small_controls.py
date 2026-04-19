#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TEXTURE_DIR = ROOT / "resources" / "ui" / "textures" / "wuxia"
TARGETS = {
    "button_regular.png": (341, 171),
    "button_pressed.png": (341, 171),
    "button_danger.png": (341, 171),
    "slot_frame.png": (341, 341),
}


def resize_texture(path: Path, size: tuple[int, int]) -> None:
    image = Image.open(path).convert("RGBA")
    resized = image.resize(size, Image.Resampling.LANCZOS)
    resized.save(path)
    print(f"[ok] {path.relative_to(ROOT)} {image.size} -> {resized.size}")


def main() -> None:
    for name, size in TARGETS.items():
        resize_texture(TEXTURE_DIR / name, size)


if __name__ == "__main__":
    main()
