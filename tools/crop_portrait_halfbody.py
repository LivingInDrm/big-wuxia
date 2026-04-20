#!/usr/bin/env python3

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parent.parent
FULL_DIR = PROJECT_ROOT / "resources" / "ui" / "portraits" / "full"
HALF_DIR = PROJECT_ROOT / "resources" / "ui" / "portraits" / "half"
PREVIEW_PATH = Path("/tmp/portrait_preview.png")
OUTPUT_SIZE = 512
UPPER_BODY_RATIO = 0.45


@dataclass(frozen=True)
class CropConfig:
    x_offset_ratio: float = 0.0
    top_offset_ratio: float = 0.0


# Per-character offsets let us keep the crop ratio fixed while nudging
# framing when props or asymmetrical poses would otherwise pull center.
CONFIGS: dict[str, CropConfig] = {
    "xu_fengnian": CropConfig(),
    "jiang_ni": CropConfig(),
    "li_chungang": CropConfig(),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Crop transparent full-body portraits into 512x512 half-body portraits."
    )
    parser.add_argument(
        "--only",
        help="Only process one portrait by basename, without the .png extension.",
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Generate /tmp/portrait_preview.png with the output portraits stitched horizontally.",
    )
    return parser.parse_args()


def clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(value, upper))


def square_crop_bounds(
    image_size: tuple[int, int],
    bbox: tuple[int, int, int, int],
    config: CropConfig,
) -> tuple[int, int, int, int]:
    image_width, image_height = image_size
    left, top, right, bottom = bbox
    bbox_width = right - left
    bbox_height = bottom - top
    crop_size = max(1.0, bbox_height * UPPER_BODY_RATIO)
    crop_top = top + bbox_height * config.top_offset_ratio
    max_top = max(0.0, image_height - crop_size)
    crop_top = clamp(crop_top, 0.0, max_top)

    center_x = left + (bbox_width / 2.0) + (bbox_width * config.x_offset_ratio)
    half_size = crop_size / 2.0
    crop_left = center_x - half_size
    max_left = max(0.0, image_width - crop_size)
    crop_left = clamp(crop_left, 0.0, max_left)

    crop_right = crop_left + crop_size
    crop_bottom = crop_top + crop_size
    return (
        int(round(crop_left)),
        int(round(crop_top)),
        int(round(crop_right)),
        int(round(crop_bottom)),
    )


def crop_halfbody(source_path: Path, output_path: Path, config: CropConfig) -> Image.Image:
    image = Image.open(source_path).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"{source_path} has no non-transparent pixels")

    crop_box = square_crop_bounds(image.size, bbox, config)
    cropped = image.crop(crop_box)
    resized = cropped.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    resized.save(output_path)
    return resized


def collect_sources(only_name: str | None) -> list[Path]:
    if only_name:
        source_path = FULL_DIR / f"{only_name}.png"
        if not source_path.exists():
            raise FileNotFoundError(f"Portrait not found: {source_path}")
        return [source_path]
    return sorted(FULL_DIR.glob("*.png"))


def build_preview(images: Iterable[Image.Image]) -> None:
    rendered = list(images)
    if not rendered:
        return

    canvas = Image.new("RGBA", (OUTPUT_SIZE * len(rendered), OUTPUT_SIZE), (0, 0, 0, 0))
    for index, image in enumerate(rendered):
        canvas.alpha_composite(image, (index * OUTPUT_SIZE, 0))
    canvas.save(PREVIEW_PATH)


def main() -> int:
    args = parse_args()
    sources = collect_sources(args.only)
    rendered: list[Image.Image] = []

    for source_path in sources:
        portrait_name = source_path.stem
        config = CONFIGS.get(portrait_name, CropConfig())
        output_path = HALF_DIR / source_path.name
        rendered.append(crop_halfbody(source_path, output_path, config))
        print(f"{source_path.name} -> {output_path}")

    if args.preview:
        build_preview(rendered)
        print(f"preview -> {PREVIEW_PATH}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
