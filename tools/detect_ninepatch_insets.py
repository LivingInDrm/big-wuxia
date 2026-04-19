#!/usr/bin/env python3
from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "tools" / "generated" / "wuxia_elements_r2"
OUT_DIR = ROOT / "tools" / "generated" / "wuxia_ninepatch_v2"
LABEL_HEIGHT = 72
OVERVIEW_PADDING = 24
BACKGROUND_COLOR = "#F2EDE0"
LABEL_COLOR = "#E9DFC8"
TEXT_COLOR = "#2F2A24"
GRID_COLOR = "#C8B99A"
CURVE_COLOR = "#3E342A"
RED_LINE = ImageColor.getcolor("#FF0000AA", "RGBA")
BLUE_LINE = ImageColor.getcolor("#0066DDAA", "RGBA")
RED_SOLID = ImageColor.getcolor("#D22F27FF", "RGBA")
BLUE_SOLID = ImageColor.getcolor("#1E5FD8FF", "RGBA")
LINE_WIDTH = 4
BUFFER = 10
LOW_RUN = 5
HALF_THRESHOLD = 0.3


@dataclass(frozen=True)
class PresetInset:
    left: int
    top: int
    right: int
    bottom: int


@dataclass(frozen=True)
class AssetSpec:
    key: str
    filename: str
    preset: PresetInset


@dataclass
class EdgeDetection:
    inset: int
    main_line: int
    decoration_end: int
    threshold: int
    stable: bool
    reason: str | None
    densities: list[int]
    corner_densities: list[int]
    interior_line: int | None
    axis_start: int
    axis_end: int


@dataclass
class AssetResult:
    key: str
    size: tuple[int, int]
    insets: dict[str, int]
    main_lines: dict[str, int]
    decoration_ends: dict[str, int]
    thresholds: dict[str, int]
    stable: bool
    fallback_to_preset: bool
    warnings: list[str]
    preset: dict[str, int]
    delta_vs_preset: dict[str, int]
    slice_path: str
    density_path: str


ASSETS = (
    AssetSpec("main_panel", "main_panel.png", PresetInset(180, 140, 180, 140)),
    AssetSpec("tooltip_panel", "tooltip_panel.png", PresetInset(120, 120, 120, 120)),
    AssetSpec("slot_frame", "slot_frame.png", PresetInset(150, 150, 150, 150)),
    AssetSpec("button_regular", "button_regular.png", PresetInset(160, 88, 160, 88)),
    AssetSpec("button_pressed", "button_pressed.png", PresetInset(160, 88, 160, 88)),
    AssetSpec("button_danger", "button_danger.png", PresetInset(160, 88, 160, 88)),
    AssetSpec("bar_base", "bar_base.png", PresetInset(96, 40, 96, 40)),
    AssetSpec("avatar_frame", "avatar_frame.png", PresetInset(132, 132, 132, 132)),
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


def build_ink_mask(image: Image.Image) -> list[list[bool]]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    mask: list[list[bool]] = [[False] * width for _ in range(height)]
    for y in range(height):
        row = mask[y]
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a < 10:
                gray = 255
            else:
                gray = (r + g + b) // 3
            row[x] = gray < 100 and a > 50
    return mask


def row_sums(mask: list[list[bool]]) -> list[int]:
    return [sum(1 for px in row if px) for row in mask]


def col_sums(mask: list[list[bool]]) -> list[int]:
    height = len(mask)
    width = len(mask[0])
    sums = [0] * width
    for x in range(width):
        total = 0
        for y in range(height):
            total += 1 if mask[y][x] else 0
        sums[x] = total
    return sums


def find_first_dense(values: list[int], threshold: int) -> int | None:
    for idx, value in enumerate(values):
        if value > threshold:
            return idx
    return None


def find_low_density_transition(values: list[int], start: int, threshold: float, run_len: int = 3) -> int | None:
    for idx in range(start + 1, len(values) - run_len + 1):
        if all(values[idx + offset] < threshold for offset in range(run_len)):
            return idx
    return None


def find_low_run_end(values: list[int], start: int, threshold: int, run_len: int = LOW_RUN) -> int | None:
    run = 0
    run_start = None
    for idx in range(start, len(values)):
        if values[idx] < threshold:
            if run == 0:
                run_start = idx
            run += 1
            if run >= run_len and run_start is not None:
                return run_start - 1
        else:
            run = 0
            run_start = None
    return None


def clamp_inset(value: int, size: int) -> int:
    return max(1, min(value, (size // 2) - 1))


def detect_top(mask: list[list[bool]], width: int, height: int) -> EdgeDetection:
    rows = row_sums(mask)
    upper_rows = rows[: height // 2]
    main_threshold = int(width * 0.3)
    main_line = find_first_dense(upper_rows, main_threshold)
    if main_line is None:
        return EdgeDetection(0, 0, 0, 0, False, "no top main frame line", upper_rows, [], None, 0, len(upper_rows) - 1)

    corner_w = max(1, width // 8)
    left_corner = [sum(1 for x in range(corner_w) if mask[y][x]) for y in range(height // 2)]
    right_corner = [sum(1 for x in range(width - corner_w, width) if mask[y][x]) for y in range(height // 2)]
    corner = [max(left_corner[y], right_corner[y]) for y in range(height // 2)]
    corner_threshold = max(3, int(max(corner[main_line:main_line + max(1, corner_w)], default=0) * 0.12))
    decoration_end = find_low_run_end(corner, main_line, corner_threshold)
    interior_line = find_low_density_transition(upper_rows, main_line, upper_rows[main_line] * HALF_THRESHOLD)
    stable = True
    reason = None
    if decoration_end is None:
        stable = False
        reason = "top decoration end not found"
        decoration_end = min((height // 2) - 1, max(main_line + 1, (interior_line or main_line) + BUFFER))
    if interior_line is None:
        reason = (reason + "; no top interior transition") if reason else "no top interior transition"
    inset = clamp_inset(max(decoration_end + 1 + BUFFER, (interior_line or main_line) + BUFFER), height)
    return EdgeDetection(inset, main_line, decoration_end, corner_threshold, stable, reason, upper_rows, corner, interior_line, 0, len(upper_rows) - 1)


def detect_bottom(mask: list[list[bool]], width: int, height: int) -> EdgeDetection:
    rows = row_sums(mask)
    lower_rows = list(reversed(rows[height // 2 :]))
    main_threshold = int(width * 0.3)
    main_line_rev = find_first_dense(lower_rows, main_threshold)
    if main_line_rev is None:
        return EdgeDetection(0, height - 1, height - 1, 0, False, "no bottom main frame line", lower_rows, [], None, height // 2, height - 1)

    corner_w = max(1, width // 8)
    lower_mask_rows = list(range(height - 1, (height // 2) - 1, -1))
    left_corner = [sum(1 for x in range(corner_w) if mask[y][x]) for y in lower_mask_rows]
    right_corner = [sum(1 for x in range(width - corner_w, width) if mask[y][x]) for y in lower_mask_rows]
    corner = [max(left_corner[i], right_corner[i]) for i in range(len(lower_mask_rows))]
    corner_threshold = max(3, int(max(corner[main_line_rev:main_line_rev + max(1, corner_w)], default=0) * 0.12))
    decoration_end_rev = find_low_run_end(corner, main_line_rev, corner_threshold)
    interior_rev = find_low_density_transition(lower_rows, main_line_rev, lower_rows[main_line_rev] * HALF_THRESHOLD)
    stable = True
    reason = None
    if decoration_end_rev is None:
        stable = False
        reason = "bottom decoration end not found"
        decoration_end_rev = min(len(lower_rows) - 1, max(main_line_rev + 1, (interior_rev or main_line_rev) + BUFFER))
    if interior_rev is None:
        reason = (reason + "; no bottom interior transition") if reason else "no bottom interior transition"

    main_line = height - 1 - main_line_rev
    decoration_end = height - 1 - decoration_end_rev
    inset = clamp_inset(max(decoration_end_rev + 1 + BUFFER, (interior_rev or main_line_rev) + BUFFER), height)
    return EdgeDetection(
        inset,
        main_line,
        decoration_end,
        corner_threshold,
        stable,
        reason,
        list(reversed(lower_rows)),
        list(reversed(corner)),
        height - 1 - interior_rev if interior_rev is not None else None,
        height // 2,
        height - 1,
    )


def detect_left(mask: list[list[bool]], width: int, height: int) -> EdgeDetection:
    cols = col_sums(mask)
    left_cols = cols[: width // 2]
    main_threshold = int(height * 0.3)
    main_line = find_first_dense(left_cols, main_threshold)
    if main_line is None:
        return EdgeDetection(0, 0, 0, 0, False, "no left main frame line", left_cols, [], None, 0, len(left_cols) - 1)

    corner_h = max(1, height // 8)
    top_corner = [sum(1 for y in range(corner_h) if mask[y][x]) for x in range(width // 2)]
    bottom_corner = [sum(1 for y in range(height - corner_h, height) if mask[y][x]) for x in range(width // 2)]
    corner = [max(top_corner[x], bottom_corner[x]) for x in range(width // 2)]
    corner_threshold = max(3, int(max(corner[main_line:main_line + max(1, corner_h)], default=0) * 0.12))
    decoration_end = find_low_run_end(corner, main_line, corner_threshold)
    interior_line = find_low_density_transition(left_cols, main_line, left_cols[main_line] * HALF_THRESHOLD)
    stable = True
    reason = None
    if decoration_end is None:
        stable = False
        reason = "left decoration end not found"
        decoration_end = min((width // 2) - 1, max(main_line + 1, (interior_line or main_line) + BUFFER))
    if interior_line is None:
        reason = (reason + "; no left interior transition") if reason else "no left interior transition"
    inset = clamp_inset(max(decoration_end + 1 + BUFFER, (interior_line or main_line) + BUFFER), width)
    return EdgeDetection(inset, main_line, decoration_end, corner_threshold, stable, reason, left_cols, corner, interior_line, 0, len(left_cols) - 1)


def detect_right(mask: list[list[bool]], width: int, height: int) -> EdgeDetection:
    cols = col_sums(mask)
    right_cols = list(reversed(cols[width // 2 :]))
    main_threshold = int(height * 0.3)
    main_line_rev = find_first_dense(right_cols, main_threshold)
    if main_line_rev is None:
        return EdgeDetection(0, width - 1, width - 1, 0, False, "no right main frame line", right_cols, [], None, width // 2, width - 1)

    corner_h = max(1, height // 8)
    right_mask_cols = list(range(width - 1, (width // 2) - 1, -1))
    top_corner = [sum(1 for y in range(corner_h) if mask[y][x]) for x in right_mask_cols]
    bottom_corner = [sum(1 for y in range(height - corner_h, height) if mask[y][x]) for x in right_mask_cols]
    corner = [max(top_corner[i], bottom_corner[i]) for i in range(len(right_mask_cols))]
    corner_threshold = max(3, int(max(corner[main_line_rev:main_line_rev + max(1, corner_h)], default=0) * 0.12))
    decoration_end_rev = find_low_run_end(corner, main_line_rev, corner_threshold)
    interior_rev = find_low_density_transition(right_cols, main_line_rev, right_cols[main_line_rev] * HALF_THRESHOLD)
    stable = True
    reason = None
    if decoration_end_rev is None:
        stable = False
        reason = "right decoration end not found"
        decoration_end_rev = min(len(right_cols) - 1, max(main_line_rev + 1, (interior_rev or main_line_rev) + BUFFER))
    if interior_rev is None:
        reason = (reason + "; no right interior transition") if reason else "no right interior transition"

    main_line = width - 1 - main_line_rev
    decoration_end = width - 1 - decoration_end_rev
    inset = clamp_inset(max(decoration_end_rev + 1 + BUFFER, (interior_rev or main_line_rev) + BUFFER), width)
    return EdgeDetection(
        inset,
        main_line,
        decoration_end,
        corner_threshold,
        stable,
        reason,
        list(reversed(right_cols)),
        list(reversed(corner)),
        width - 1 - interior_rev if interior_rev is not None else None,
        width // 2,
        width - 1,
    )


def enforce_sanity(spec: AssetSpec, width: int, height: int, edges: dict[str, EdgeDetection]) -> tuple[dict[str, int], bool, list[str]]:
    insets = {
        "left": edges["left"].inset,
        "top": edges["top"].inset,
        "right": edges["right"].inset,
        "bottom": edges["bottom"].inset,
    }
    warnings: list[str] = []
    stable = all(edge.stable for edge in edges.values())

    if insets["left"] + insets["right"] >= width or insets["top"] + insets["bottom"] >= height:
        stable = False
        warnings.append("insets exceed center region")

    if not stable:
        insets = asdict(spec.preset)
        warnings.extend(edge.reason for edge in edges.values() if edge.reason)
        return insets, True, warnings

    return insets, False, warnings


def draw_label(width: int, text: str, font: ImageFont.ImageFont | ImageFont.FreeTypeFont) -> Image.Image:
    strip = Image.new("RGBA", (width, LABEL_HEIGHT), LABEL_COLOR)
    draw = ImageDraw.Draw(strip)
    draw.text((18, 18), text, font=font, fill=TEXT_COLOR)
    return strip


def draw_slice_preview(
    image: Image.Image,
    spec: AssetSpec,
    insets: dict[str, int],
    main_lines: dict[str, int],
    font: ImageFont.ImageFont | ImageFont.FreeTypeFont,
) -> Image.Image:
    width, height = image.size
    canvas = Image.new("RGBA", (width, height + LABEL_HEIGHT), BACKGROUND_COLOR)
    label = (
        f"{spec.key}  inset L{insets['left']} T{insets['top']} R{insets['right']} B{insets['bottom']}  "
        f"main xL{main_lines['left']} xR{main_lines['right']} yT{main_lines['top']} yB{main_lines['bottom']}  "
        f"size={width}x{height}"
    )
    canvas.alpha_composite(draw_label(width, label, font), (0, 0))
    canvas.alpha_composite(image, (0, LABEL_HEIGHT))

    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    x_left = insets["left"]
    x_right = width - insets["right"]
    y_top = insets["top"]
    y_bottom = height - insets["bottom"]
    draw.line([(x_left, 0), (x_left, height)], fill=RED_LINE, width=LINE_WIDTH)
    draw.line([(x_right, 0), (x_right, height)], fill=RED_LINE, width=LINE_WIDTH)
    draw.line([(0, y_top), (width, y_top)], fill=RED_LINE, width=LINE_WIDTH)
    draw.line([(0, y_bottom), (width, y_bottom)], fill=RED_LINE, width=LINE_WIDTH)
    draw.line([(main_lines["left"], 0), (main_lines["left"], height)], fill=BLUE_LINE, width=2)
    draw.line([(main_lines["right"], 0), (main_lines["right"], height)], fill=BLUE_LINE, width=2)
    draw.line([(0, main_lines["top"]), (width, main_lines["top"])], fill=BLUE_LINE, width=2)
    draw.line([(0, main_lines["bottom"]), (width, main_lines["bottom"])], fill=BLUE_LINE, width=2)
    canvas.alpha_composite(overlay, (0, LABEL_HEIGHT))
    return canvas


def draw_plot(
    title: str,
    values: list[int],
    inset_pos: int,
    main_pos: int,
    width: int,
    height: int,
    font: ImageFont.ImageFont | ImageFont.FreeTypeFont,
) -> Image.Image:
    img = Image.new("RGBA", (width, height), "#FBF7EE")
    draw = ImageDraw.Draw(img)
    margin_l = 40
    margin_r = 12
    margin_t = 22
    margin_b = 24
    plot_w = max(1, width - margin_l - margin_r)
    plot_h = max(1, height - margin_t - margin_b)
    max_value = max(max(values, default=1), 1)

    draw.rectangle([(margin_l, margin_t), (margin_l + plot_w, margin_t + plot_h)], outline=GRID_COLOR, width=1)
    for i in range(1, 4):
        y = margin_t + int(plot_h * i / 4)
        draw.line([(margin_l, y), (margin_l + plot_w, y)], fill=GRID_COLOR, width=1)
    draw.text((8, 4), title, font=font, fill=TEXT_COLOR)
    draw.text((4, margin_t - 2), str(max_value), font=font, fill=TEXT_COLOR)
    draw.text((6, margin_t + plot_h - 10), "0", font=font, fill=TEXT_COLOR)
    draw.text((margin_l, margin_t + plot_h + 4), "0", font=font, fill=TEXT_COLOR)
    draw.text((margin_l + plot_w - 18, margin_t + plot_h + 4), str(len(values) - 1), font=font, fill=TEXT_COLOR)

    if len(values) > 1:
        points = []
        for idx, value in enumerate(values):
            x = margin_l + int(idx * plot_w / (len(values) - 1))
            y = margin_t + plot_h - int((value / max_value) * plot_h)
            points.append((x, y))
        draw.line(points, fill=CURVE_COLOR, width=2)

    if values:
        inset_pos = max(0, min(inset_pos, len(values) - 1))
        main_pos = max(0, min(main_pos, len(values) - 1))
        inset_x = margin_l + int(inset_pos * plot_w / max(1, len(values) - 1))
        draw.line([(inset_x, margin_t), (inset_x, margin_t + plot_h)], fill=RED_SOLID, width=2)
        main_x = margin_l + int(main_pos * plot_w / max(1, len(values) - 1))
        main_y = margin_t + plot_h - int((values[main_pos] / max_value) * plot_h)
        draw.ellipse([(main_x - 4, main_y - 4), (main_x + 4, main_y + 4)], fill=BLUE_SOLID)
        draw.line([(main_x, margin_t), (main_x, margin_t + plot_h)], fill=BLUE_SOLID, width=1)
    return img


def draw_density_overview(
    spec: AssetSpec,
    width: int,
    height: int,
    edges: dict[str, EdgeDetection],
    font: ImageFont.ImageFont | ImageFont.FreeTypeFont,
) -> Image.Image:
    panel_w = 640
    panel_h = 220
    canvas = Image.new("RGBA", (panel_w * 2, panel_h * 2 + 48), BACKGROUND_COLOR)
    draw = ImageDraw.Draw(canvas)
    title = f"{spec.key} density  size={width}x{height}  blue=main line  red=inset"
    draw.text((16, 12), title, font=font, fill=TEXT_COLOR)

    top_plot = draw_plot("top rows", edges["top"].densities, edges["top"].inset, edges["top"].main_line, panel_w, panel_h, font)
    bottom_inset_local = (height - edges["bottom"].inset) - edges["bottom"].axis_start
    bottom_main_local = edges["bottom"].main_line - edges["bottom"].axis_start
    bottom_plot = draw_plot("bottom rows", edges["bottom"].densities, bottom_inset_local, bottom_main_local, panel_w, panel_h, font)
    left_plot = draw_plot("left cols", edges["left"].densities, edges["left"].inset, edges["left"].main_line, panel_w, panel_h, font)
    right_inset_local = (width - edges["right"].inset) - edges["right"].axis_start
    right_main_local = edges["right"].main_line - edges["right"].axis_start
    right_plot = draw_plot("right cols", edges["right"].densities, right_inset_local, right_main_local, panel_w, panel_h, font)

    canvas.alpha_composite(top_plot, (0, 48))
    canvas.alpha_composite(bottom_plot, (panel_w, 48))
    canvas.alpha_composite(left_plot, (0, 48 + panel_h))
    canvas.alpha_composite(right_plot, (panel_w, 48 + panel_h))
    return canvas


def build_overview(previews: list[tuple[AssetSpec, Image.Image]], font: ImageFont.ImageFont | ImageFont.FreeTypeFont) -> Image.Image:
    width = max(preview.width for _, preview in previews) + OVERVIEW_PADDING * 2
    height = OVERVIEW_PADDING
    blocks: list[Image.Image] = []

    for spec, preview in previews:
        header = Image.new("RGBA", (preview.width, 40), LABEL_COLOR)
        ImageDraw.Draw(header).text((14, 10), spec.key, font=font, fill=TEXT_COLOR)
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


def detect_asset(spec: AssetSpec, font: ImageFont.ImageFont | ImageFont.FreeTypeFont) -> tuple[AssetSpec, Image.Image, AssetResult]:
    source = SRC_DIR / spec.filename
    image = Image.open(source).convert("RGBA")
    width, height = image.size
    mask = build_ink_mask(image)

    edges = {
        "top": detect_top(mask, width, height),
        "bottom": detect_bottom(mask, width, height),
        "left": detect_left(mask, width, height),
        "right": detect_right(mask, width, height),
    }
    insets, fallback_to_preset, warnings = enforce_sanity(spec, width, height, edges)
    stable = not fallback_to_preset

    if fallback_to_preset:
        print(f"[warn] {spec.key} auto-detect unstable, keeping preset inset; please review density.png")

    main_lines = {
        "left": edges["left"].main_line,
        "top": edges["top"].main_line,
        "right": edges["right"].main_line,
        "bottom": edges["bottom"].main_line,
    }
    decoration_ends = {
        "left": edges["left"].decoration_end,
        "top": edges["top"].decoration_end,
        "right": edges["right"].decoration_end,
        "bottom": edges["bottom"].decoration_end,
    }
    thresholds = {
        "left": edges["left"].threshold,
        "top": edges["top"].threshold,
        "right": edges["right"].threshold,
        "bottom": edges["bottom"].threshold,
    }

    slice_preview = draw_slice_preview(image, spec, insets, main_lines, font)
    slice_path = OUT_DIR / f"{spec.key}.slice.png"
    slice_preview.save(slice_path)

    density_preview = draw_density_overview(spec, width, height, edges, load_font(16))
    density_path = OUT_DIR / f"{spec.key}.density.png"
    density_preview.save(density_path)

    result = AssetResult(
        key=spec.key,
        size=(width, height),
        insets=insets,
        main_lines=main_lines,
        decoration_ends=decoration_ends,
        thresholds=thresholds,
        stable=stable,
        fallback_to_preset=fallback_to_preset,
        warnings=warnings,
        preset=asdict(spec.preset),
        delta_vs_preset={edge: insets[edge] - getattr(spec.preset, edge) for edge in ("left", "top", "right", "bottom")},
        slice_path=str(slice_path.relative_to(ROOT)),
        density_path=str(density_path.relative_to(ROOT)),
    )
    print(
        f"[ok] {spec.key}: inset={insets} main={main_lines} "
        f"slice={slice_path.relative_to(ROOT)} density={density_path.relative_to(ROOT)}"
    )
    return spec, slice_preview, result


def save_results_json(results: list[AssetResult]) -> Path:
    payload = {
        "buffer_px": BUFFER,
        "low_run": LOW_RUN,
        "half_threshold_ratio": HALF_THRESHOLD,
        "assets": {result.key: asdict(result) for result in results},
    }
    path = OUT_DIR / "detected_insets.json"
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    return path


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    font = load_font(24)
    previews: list[tuple[AssetSpec, Image.Image]] = []
    results: list[AssetResult] = []

    with ThreadPoolExecutor(max_workers=min(4, len(ASSETS))) as executor:
        futures = [executor.submit(detect_asset, spec, font) for spec in ASSETS]
        for future in futures:
            spec, preview, result = future.result()
            previews.append((spec, preview))
            results.append(result)

    preview_order = {spec.key: index for index, spec in enumerate(ASSETS)}
    previews.sort(key=lambda item: preview_order[item[0].key])
    results.sort(key=lambda item: preview_order[item.key])

    overview = build_overview(previews, font)
    overview_path = OUT_DIR / "overview.png"
    overview.save(overview_path)
    json_path = save_results_json(results)
    print(f"[ok] overview: {overview_path.relative_to(ROOT)}")
    print(f"[ok] json: {json_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
