#!/usr/bin/env python3
from __future__ import annotations

import asyncio
import base64
import os
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

from openai import OpenAI
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "tools" / "generated" / "wuxia_samples_r1"
IMAGE_SIZE = "1536x1024"
LABEL_HEIGHT = 88
LABEL_BG = "#E6DDCB"
TEXT_COLOR = "#2F2A24"
ENV_CANDIDATES = [
    ROOT / ".env",
    Path("/Users/xiaochunliu/program/sutan/tools/asset-manager/backend/.env"),
    Path("/Users/xiaochunliu/program/sutan/.env"),
]


@dataclass(frozen=True)
class SampleSpec:
    key: str
    label: str
    filename: str
    prompt: str


SAMPLES = [
    SampleSpec(
        key="A",
        label="候选 A · 极简墨线留白",
        filename="panel_a_minimal.png",
        prompt=(
            "A long horizontal rectangular UI panel background for a wuxia RPG game HUD. "
            "Rice paper (xuan paper) texture in warm off-white color #F2EDE0, with subtle fiber grain. "
            "Ultra-minimal: only a single fine black ink outline along the border (2-3 px thick), "
            "with tiny ink dots at the four corners as decorative accents. Large empty interior space "
            "suitable for overlaying text and bars. Traditional Chinese literati aesthetic. "
            "No color except black ink on paper. Flat, no 3D shading, no gradients, no glow. "
            "Transparent background outside the panel."
        ),
    ),
    SampleSpec(
        key="B",
        label="候选 B · 淡墨晕染",
        filename="panel_b_wash.png",
        prompt=(
            "A long horizontal rectangular UI panel for a wuxia ink-wash game HUD. "
            "Rice paper texture warm off-white #F2EDE0. Border is soft diluted ink wash (shuimò) "
            "bleeding gently into the paper edge, irregular organic brush strokes, slightly asymmetric. "
            "Four corners have subtle light ink cloud wisps fading inward. Large empty flat interior. "
            "Chinese literati watercolor aesthetic. Muted palette: paper off-white and translucent gray-black ink only. "
            "No bright colors, no 3D shading. Transparent background outside the panel."
        ),
    ),
    SampleSpec(
        key="C",
        label="候选 C · 古籍折角",
        filename="panel_c_bookfold.png",
        prompt=(
            "A long horizontal rectangular UI panel styled like an ancient Chinese scroll book page. "
            "Rice paper warm off-white #F2EDE0 with visible fiber texture. Clean thin black ink border (2 px), "
            "with decorative folded-corner ornaments at all four corners drawn as small angular ink geometric patterns "
            "(like classical Chinese book binding). Interior is large empty flat paper. Scholarly, restrained, traditional. "
            "No color, only paper + ink. Flat 2D, no shading. Transparent background outside the panel."
        ),
    ),
    SampleSpec(
        key="D",
        label="候选 D · 朱砂点缀",
        filename="panel_d_seal.png",
        prompt=(
            "A long horizontal rectangular UI panel for a wuxia game HUD. Rice paper warm off-white #F2EDE0 background "
            "with subtle fiber grain. Thin black ink outline border. At the upper-left corner a single small vermilion red "
            "(cinnabar / 朱砂) seal stamp ornament (1.5 cm square), slightly weathered and imperfect as if pressed by hand. "
            "The rest of the panel is clean empty paper suitable for overlaying text and bars. Chinese literati calligraphy aesthetic. "
            "Flat 2D, no gradients, no glow. Muted palette: paper off-white, black ink, small accent of vermilion red. "
            "Transparent background outside the panel."
        ),
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


def generate_panel_blocking(client: OpenAI, spec: SampleSpec, out_path: Path) -> Path:
    response = client.images.generate(
        model="gpt-image-1",
        prompt=spec.prompt,
        size=IMAGE_SIZE,
        quality="medium",
        background="transparent",
        output_format="png",
        n=1,
    )
    image_bytes = base64.b64decode(response.data[0].b64_json)
    image = Image.open(BytesIO(image_bytes)).convert("RGBA")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(out_path)
    return out_path


def validate_png(path: Path) -> int:
    if not path.exists():
        raise FileNotFoundError(path)
    if path.stat().st_size <= 0:
        raise ValueError(f"Generated file is empty: {path}")
    with Image.open(path) as image:
        image.verify()
    return path.stat().st_size


def build_compare_image(sample_paths: list[tuple[SampleSpec, Path]], compare_path: Path) -> Path:
    opened = [(spec, Image.open(path).convert("RGBA")) for spec, path in sample_paths]
    try:
        width = max(image.width for _, image in opened)
        total_height = sum(image.height + LABEL_HEIGHT for _, image in opened)
        canvas = Image.new("RGBA", (width, total_height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(canvas)
        font = load_font(36)

        y = 0
        for spec, image in opened:
            draw.rectangle((0, y, width, y + LABEL_HEIGHT), fill=LABEL_BG)
            draw.text((36, y + 22), spec.label, fill=TEXT_COLOR, font=font)
            canvas.alpha_composite(image, (0, y + LABEL_HEIGHT))
            y += LABEL_HEIGHT + image.height

        compare_path.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(compare_path)
        return compare_path
    finally:
        for _, image in opened:
            image.close()


async def run_generation() -> tuple[list[tuple[SampleSpec, Path]], Path]:
    client = get_client()
    loop = asyncio.get_running_loop()
    with ThreadPoolExecutor(max_workers=4) as executor:
        tasks = []
        for spec in SAMPLES:
            out_path = OUT_DIR / spec.filename
            task = loop.run_in_executor(executor, generate_panel_blocking, client, spec, out_path)
            tasks.append((spec, task))

        results: list[tuple[SampleSpec, Path]] = []
        for spec, task in tasks:
            results.append((spec, await task))

    for _, path in results:
        validate_png(path)

    compare_path = OUT_DIR / "compare.png"
    build_compare_image(results, compare_path)
    validate_png(compare_path)
    return results, compare_path


def main() -> None:
    results, compare_path = asyncio.run(run_generation())
    for spec, path in results:
        print(f"[ok] {spec.key} -> {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")
    print(f"[ok] compare -> {compare_path.relative_to(ROOT)} ({compare_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
