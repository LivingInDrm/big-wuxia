#!/usr/bin/env python3
from __future__ import annotations

import asyncio
import base64
import argparse
import os
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

from openai import OpenAI
from PIL import Image, ImageColor, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "tools" / "generated" / "wuxia_elements_r2"
LABEL_HEIGHT = 100
TEXT_COLOR = "#2F2A24"
STYLE_PREFIX = (
    "Style: Traditional Chinese wuxia ink-wash UI asset in the 'ancient scroll book' aesthetic. "
    "Rice paper (xuan paper) warm off-white background #F2EDE0 with subtle fiber grain. "
    "All borders are clean thin black ink outlines (2 px). Decorative angular ink ornaments at corners "
    "(like classical Chinese book binding folded corners). Flat 2D, no 3D shading, no gradients, no glow, "
    "no highlights. Restrained literati palette: paper off-white + black ink. Transparent background outside the shape. "
)
ENV_CANDIDATES = [
    ROOT / ".env",
    Path("/Users/xiaochunliu/program/sutan/tools/asset-manager/backend/.env"),
    Path("/Users/xiaochunliu/program/sutan/.env"),
]


@dataclass(frozen=True)
class AssetSpec:
    key: str
    label: str
    filename: str
    size: tuple[int, int]
    api_size: tuple[int, int] | None
    prompt: str | None
    kind: str


ASSETS = [
    AssetSpec(
        key="main_panel",
        label="主面板",
        filename="main_panel.png",
        size=(1536, 1024),
        api_size=(1536, 1024),
        prompt=(
            "Style: Traditional Chinese wuxia ink-wash UI asset in the 'ancient scroll book' aesthetic. "
            "Rice paper (xuan paper) warm off-white background #F2EDE0 with subtle fiber grain. "
            "All borders are clean thin black ink outlines (2 px). Decorative angular ink ornaments at corners "
            "(like classical Chinese book binding folded corners). Flat 2D, no 3D shading, no gradients, no glow, no highlights. "
            "Restrained literati palette: paper off-white + black ink. Transparent background outside the shape.\n\n"
            "A long horizontal rectangular UI panel centered inside the image canvas with CLEAR MARGIN on ALL FOUR SIDES "
            "(at least 8 percent of canvas on each side). The panel must have FOUR complete visible borders — top, bottom, "
            "LEFT, and right — all fully drawn and entirely within the image bounds. Do NOT bleed the panel to the image edge. "
            "All four corners have the signature ink folded-corner ornament, symmetric and identical on all 4 corners. "
            "Interior is large clean empty paper suitable for HUD content. No part of the panel frame should touch or exceed the image boundary."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="tooltip_panel",
        label="提示面板",
        filename="tooltip_panel.png",
        size=(1024, 1024),
        api_size=(1024, 1024),
        prompt=(
            STYLE_PREFIX
            + "A small square tooltip/dialog panel, compact size. Thin ink border, smaller but still identifiable folded-corner "
            "ornaments at 4 corners. Interior is clean empty paper. Used for small popups and tooltips."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="slot_frame",
        label="槽位框",
        filename="slot_frame.png",
        size=(1024, 1024),
        api_size=(1024, 1024),
        prompt=(
            STYLE_PREFIX
            + "A small square item slot frame, for inventory or avatar. Very thin ink border (1-2 px), minimal decorative ink dots "
            "at 4 corners (simpler than the full folded-corner ornament - just single ink dots). Interior is empty paper. "
            "Used as a repeated grid cell."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="button_regular",
        label="按钮-常态",
        filename="button_regular.png",
        size=(1024, 512),
        api_size=(1536, 1024),
        prompt=(
            STYLE_PREFIX
            + "A horizontal pill-shaped button background. Rice paper surface, thin ink border rectangle with slightly rounded corners, "
            "smaller folded-corner ornaments at the 4 corners. Clean flat interior ready for button text overlay. Looks calm and scholarly, not pressed."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="button_pressed",
        label="按钮-按下",
        filename="button_pressed.png",
        size=(1024, 512),
        api_size=(1536, 1024),
        prompt=(
            STYLE_PREFIX
            + "A horizontal pill-shaped button background in its 'pressed' state. Same shape as the regular button but the interior paper is slightly darker "
            "(light gray-beige wash #E0D8C4), as if an ink shadow passed over it. Border and corner ornaments are unchanged. Flat, no 3D bevel."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="button_danger",
        label="按钮-危险",
        filename="button_danger.png",
        size=(1024, 512),
        api_size=(1536, 1024),
        prompt=(
            STYLE_PREFIX
            + "A horizontal pill-shaped button background. Rice paper interior, but the thin ink border is replaced with a vermilion red "
            "(cinnabar / zhusha) ink border #8B2E2E instead of black. The corner ornaments are also drawn in vermilion red. "
            "Used for danger / confirm-to-delete actions. Flat 2D."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="bar_base",
        label="进度条底",
        filename="bar_base.png",
        size=(1536, 256),
        api_size=(1536, 1024),
        prompt=(
            STYLE_PREFIX
            + "A long thin horizontal trough bar base, like an empty ink channel. Thin ink border forming a very elongated rectangle. "
            "Interior is slightly indented light gray paper #E8DFCC giving a sense of depth. Minimal tiny ink dots at the 2 short ends "
            "(no full folded-corner ornament, too small for it). Used as progress bar background that will be overlaid with a colored fill."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="avatar_frame",
        label="头像框",
        filename="avatar_frame.png",
        size=(1024, 1024),
        api_size=(1024, 1024),
        prompt=(
            STYLE_PREFIX
            + "A square portrait frame for a character avatar. Thin ink border, moderately prominent folded-corner ornaments at all 4 corners. "
            "Interior is empty (transparent-ish) ready for a character portrait to be shown inside. Traditional Chinese wuxia scroll aesthetic."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="divider",
        label="分隔墨痕",
        filename="divider.png",
        size=(1536, 128),
        api_size=(1536, 1024),
        prompt=(
            STYLE_PREFIX
            + "A single horizontal ink brush stroke, subtle and slightly irregular, darker in the middle fading to transparent at both ends. "
            "Used as a section divider. No border, no corners, just the lone brush stroke on transparent background."
        ),
        kind="ai",
    ),
    AssetSpec(
        key="bar_fill_neutral",
        label="进度条填充-中性灰",
        filename="bar_fill_neutral.png",
        size=(1536, 256),
        api_size=None,
        prompt=None,
        kind="pil",
    ),
]


def get_client() -> OpenAI:
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        for env_path in ENV_CANDIDATES:
            if not env_path.exists():
                continue
            for line in env_path.read_text(encoding="utf-8").splitlines():
                if not line.startswith("OPENAI_API_KEY="):
                    continue
                api_key = line.split("=", 1)[1].strip().strip("'").strip('"')
                if api_key:
                    os.environ["OPENAI_API_KEY"] = api_key
                    break
            if api_key:
                break
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set in the environment.")
    return OpenAI(api_key=api_key)


def load_font(size: int) -> ImageFont.ImageFont | ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/Library/Fonts/NotoSerifCJK-Regular.ttc",
        "/Library/Fonts/Noto Serif CJK SC.ttc",
        "/System/Library/Fonts/Supplemental/Songti.ttc",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            try:
                return ImageFont.truetype(str(path), size=size)
            except Exception:
                continue
    return ImageFont.load_default()


def generate_ai_asset_blocking(client: OpenAI, spec: AssetSpec, out_path: Path) -> Path:
    response = client.images.generate(
        model="gpt-image-1",
        prompt=spec.prompt,
        size=f"{spec.api_size[0]}x{spec.api_size[1]}",
        quality="medium",
        background="transparent",
        output_format="png",
        n=1,
    )
    image_bytes = base64.b64decode(response.data[0].b64_json)
    image = Image.open(BytesIO(image_bytes)).convert("RGBA")
    if image.size != spec.size:
        image = image.resize(spec.size, Image.Resampling.LANCZOS)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(out_path)
    return out_path


def generate_neutral_fill(out_path: Path, size: tuple[int, int]) -> Path:
    width, height = size
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rgb = ImageColor.getrgb("#888888")
    for x in range(width):
        edge_factor = abs((x / max(width - 1, 1)) - 0.5) * 2.0
        alpha = int(200 - edge_factor * 24)
        draw.line((x, 0, x, height), fill=(*rgb, alpha), width=1)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(out_path)
    return out_path


def validate_png(path: Path, expected_size: tuple[int, int]) -> int:
    if not path.exists():
        raise FileNotFoundError(path)
    size_bytes = path.stat().st_size
    if size_bytes <= 0:
        raise ValueError(f"Generated file is empty: {path}")
    with Image.open(path) as image:
        image.load()
        if image.size != expected_size:
            raise ValueError(f"Unexpected size for {path}: {image.size} != {expected_size}")
    return size_bytes


def build_overview(results: list[tuple[AssetSpec, Path]], overview_path: Path) -> Path:
    preview_max_width = 1200
    spacing = 28
    margin = 36
    font = load_font(34)
    label_font = load_font(22)

    rows: list[tuple[AssetSpec, Image.Image, Image.Image]] = []
    total_height = margin
    canvas_width = preview_max_width + margin * 2

    for spec, path in results:
        image = Image.open(path).convert("RGBA")
        scale = min(preview_max_width / image.width, 1.0)
        preview_size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
        preview = image.resize(preview_size, Image.Resampling.LANCZOS)
        rows.append((spec, image, preview))
        total_height += LABEL_HEIGHT + preview.height + spacing

    canvas = Image.new("RGBA", (canvas_width, total_height), ImageColor.getrgb("#F7F1E6") + (255,))
    draw = ImageDraw.Draw(canvas)

    y = margin
    try:
        for spec, image, preview in rows:
            draw.rounded_rectangle(
                (margin // 2, y - 10, canvas_width - margin // 2, y + LABEL_HEIGHT + preview.height + 12),
                radius=18,
                fill=ImageColor.getrgb("#EEE4D1") + (255,),
                outline=ImageColor.getrgb("#C7B79E") + (255,),
                width=2,
            )
            draw.text((margin, y + 16), spec.label, fill=TEXT_COLOR, font=font)
            meta = f"{spec.filename}  {image.width}x{image.height}"
            draw.text((margin, y + 58), meta, fill="#5C5145", font=label_font)
            x = (canvas_width - preview.width) // 2
            canvas.alpha_composite(preview, (x, y + LABEL_HEIGHT))
            y += LABEL_HEIGHT + preview.height + spacing
        overview_path.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(overview_path)
        return overview_path
    finally:
        for _, image, preview in rows:
            image.close()
            preview.close()


async def run_generation() -> tuple[list[tuple[AssetSpec, Path]], Path]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    parser = argparse.ArgumentParser(description="Generate wuxia UI elements.")
    parser.add_argument(
        "--only",
        action="append",
        dest="only_keys",
        help="Generate only the specified asset key. Repeatable.",
    )
    args = parser.parse_args()
    selected_keys = set(args.only_keys or [])
    unknown_keys = sorted(selected_keys - {spec.key for spec in ASSETS})
    if unknown_keys:
        raise ValueError(f"Unknown asset keys for --only: {', '.join(unknown_keys)}")

    selected_specs = [spec for spec in ASSETS if not selected_keys or spec.key in selected_keys]
    ai_specs = [spec for spec in selected_specs if spec.kind == "ai"]
    pil_specs = [spec for spec in selected_specs if spec.kind == "pil"]
    client = get_client() if ai_specs else None
    loop = asyncio.get_running_loop()

    with ThreadPoolExecutor(max_workers=max(len(selected_specs), 4)) as executor:
        ai_tasks = [
            (spec, loop.run_in_executor(executor, generate_ai_asset_blocking, client, spec, OUT_DIR / spec.filename))
            for spec in ai_specs
        ]
        pil_tasks = [
            (spec, loop.run_in_executor(executor, generate_neutral_fill, OUT_DIR / spec.filename, spec.size))
            for spec in pil_specs
        ]

        results: list[tuple[AssetSpec, Path]] = []
        for spec, task in ai_tasks + pil_tasks:
            results.append((spec, await task))

    results.sort(key=lambda item: next(index for index, spec in enumerate(ASSETS) if spec.key == item[0].key))

    for spec, path in results:
        validate_png(path, spec.size)

    overview_results = [(spec, OUT_DIR / spec.filename) for spec in ASSETS]
    for spec, path in overview_results:
        validate_png(path, spec.size)

    overview_path = OUT_DIR / "overview.png"
    build_overview(overview_results, overview_path)
    with Image.open(overview_path) as overview:
        overview_size = overview.size
    validate_png(overview_path, overview_size)
    return results, overview_path


def main() -> None:
    results, overview_path = asyncio.run(run_generation())
    for spec, path in results:
        print(f"[ok] {spec.filename} {spec.size[0]}x{spec.size[1]} -> {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")
    print(f"[ok] overview -> {overview_path.relative_to(ROOT)} ({overview_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
