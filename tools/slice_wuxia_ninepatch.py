#!/usr/bin/env python3
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "tools" / "generated" / "wuxia_elements_r2"
OUT_DIR = ROOT / "tools" / "generated" / "wuxia_ninepatch_preview"
LABEL_HEIGHT = 64
OVERVIEW_PADDING = 24
BACKGROUND_COLOR = "#F2EDE0"
LABEL_COLOR = "#E9DFC8"
TEXT_COLOR = "#2F2A24"
LINE_COLOR = ImageColor.getcolor("#FF000088", "RGBA")
LINE_WIDTH = 4


@dataclass(frozen=True)
class AssetSpec:
    key: str
    filename: str
    left: int
    top: int
    right: int
    bottom: int


ASSETS = (
    AssetSpec("main_panel", "main_panel.png", 180, 140, 180, 140),
    AssetSpec("tooltip_panel", "tooltip_panel.png", 120, 120, 120, 120),
    AssetSpec("slot_frame", "slot_frame.png", 150, 150, 150, 150),
    AssetSpec("button_regular", "button_regular.png", 160, 88, 160, 88),
    AssetSpec("button_pressed", "button_pressed.png", 160, 88, 160, 88),
    AssetSpec("button_danger", "button_danger.png", 160, 88, 160, 88),
    AssetSpec("bar_base", "bar_base.png", 96, 40, 96, 40),
    AssetSpec("avatar_frame", "avatar_frame.png", 132, 132, 132, 132),
)


def load_font(size: int) -> ImageFont.ImageFont | ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Menlo.ttc",
        "/System/Library/Fonts/SFNSMono.ttf",
        "/Library/Fonts/Arial Unicode.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if not path.exists():
            continue
        try:
            return ImageFont.truetype(str(path), size=size)
        except Exception:
            continue
    return ImageFont.load_default()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Image has no visible pixels")
    return bbox


def validate_insets(image: Image.Image, spec: AssetSpec) -> None:
    width, height = image.size
    if spec.left <= 0 or spec.top <= 0 or spec.right <= 0 or spec.bottom <= 0:
        raise ValueError(f"{spec.key}: inset values must be positive")
    if spec.left + spec.right >= width:
        raise ValueError(f"{spec.key}: horizontal insets exceed width {width}")
    if spec.top + spec.bottom >= height:
        raise ValueError(f"{spec.key}: vertical insets exceed height {height}")


def draw_label(width: int, text: str, font: ImageFont.ImageFont | ImageFont.FreeTypeFont) -> Image.Image:
    strip = Image.new("RGBA", (width, LABEL_HEIGHT), LABEL_COLOR)
    draw = ImageDraw.Draw(strip)
    draw.text((18, 16), text, font=font, fill=TEXT_COLOR)
    return strip


def draw_slice_preview(image: Image.Image, spec: AssetSpec, font: ImageFont.ImageFont | ImageFont.FreeTypeFont) -> Image.Image:
    width, height = image.size
    validate_insets(image, spec)

    canvas = Image.new("RGBA", (width, height + LABEL_HEIGHT), BACKGROUND_COLOR)
    label = (
        f"{spec.key}  left={spec.left} top={spec.top} right={spec.right} bottom={spec.bottom}  "
        f"size={width}x{height}"
    )
    canvas.alpha_composite(draw_label(width, label, font), (0, 0))
    canvas.alpha_composite(image, (0, LABEL_HEIGHT))

    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    x_left = spec.left
    x_right = width - spec.right
    y_top = spec.top
    y_bottom = height - spec.bottom
    draw.line([(x_left, 0), (x_left, height)], fill=LINE_COLOR, width=LINE_WIDTH)
    draw.line([(x_right, 0), (x_right, height)], fill=LINE_COLOR, width=LINE_WIDTH)
    draw.line([(0, y_top), (width, y_top)], fill=LINE_COLOR, width=LINE_WIDTH)
    draw.line([(0, y_bottom), (width, y_bottom)], fill=LINE_COLOR, width=LINE_WIDTH)
    canvas.alpha_composite(overlay, (0, LABEL_HEIGHT))
    return canvas


def build_overview(previews: list[tuple[AssetSpec, Image.Image]], font: ImageFont.ImageFont | ImageFont.FreeTypeFont) -> Image.Image:
    width = max(preview.width for _, preview in previews) + OVERVIEW_PADDING * 2
    height = OVERVIEW_PADDING
    blocks: list[Image.Image] = []

    for spec, preview in previews:
        summary = (
            f"{spec.key}: left={spec.left} top={spec.top} right={spec.right} bottom={spec.bottom}  "
            f"canvas={preview.width}x{preview.height}"
        )
        header = Image.new("RGBA", (preview.width, 44), LABEL_COLOR)
        ImageDraw.Draw(header).text((14, 10), summary, font=font, fill=TEXT_COLOR)
        block = Image.new("RGBA", (preview.width, header.height + preview.height), BACKGROUND_COLOR)
        block.alpha_composite(header, (0, 0))
        block.alpha_composite(preview, (0, header.height))
        blocks.append(block)
        height += block.height + OVERVIEW_PADDING

    overview = Image.new("RGBA", (width, height), BACKGROUND_COLOR)
    y = OVERVIEW_PADDING
    for block in blocks:
        x = (width - block.width) // 2
        overview.alpha_composite(block, (x, y))
        y += block.height + OVERVIEW_PADDING
    return overview


def save_insets_json(specs: tuple[AssetSpec, ...]) -> Path:
    data = {
        spec.key: {
            "left": spec.left,
            "top": spec.top,
            "right": spec.right,
            "bottom": spec.bottom,
        }
        for spec in specs
    }
    path = OUT_DIR / "proposed_insets.json"
    path.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    return path


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    font = load_font(24)
    previews: list[tuple[AssetSpec, Image.Image]] = []

    for spec in ASSETS:
        source = SRC_DIR / spec.filename
        image = Image.open(source).convert("RGBA")
        bbox = alpha_bbox(image)
        preview = draw_slice_preview(image, spec, font)
        output = OUT_DIR / f"{spec.key}.slice.png"
        preview.save(output)
        previews.append((spec, preview))
        print(f"[ok] {spec.key}: source={source.name} bbox={bbox} preview={output.relative_to(ROOT)}")

    overview = build_overview(previews, font)
    overview_path = OUT_DIR / "overview.png"
    overview.save(overview_path)
    json_path = save_insets_json(ASSETS)
    print(f"[ok] overview: {overview_path.relative_to(ROOT)}")
    print(f"[ok] insets: {json_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
