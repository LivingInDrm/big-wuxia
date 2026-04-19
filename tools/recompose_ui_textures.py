#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Tuple

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "resources" / "ui" / "textures" / "recomposed"


GridPos = Tuple[int, int]
BBox = Tuple[int, int, int, int]


@dataclass(frozen=True)
class RecomposeJob:
	name: str
	source: Path
	output: Path
	size: Tuple[int, int]
	margin: int
	mode: str = "islands_3x3"
	interior_trim: int = 0


def _alpha_components(image: Image.Image) -> list[BBox]:
	rgba = image.convert("RGBA")
	alpha = rgba.getchannel("A")
	width, height = rgba.size
	pixels = alpha.load()
	seen = [[False for _ in range(height)] for _ in range(width)]
	components: list[BBox] = []

	for x in range(width):
		for y in range(height):
			if seen[x][y] or pixels[x, y] == 0:
				continue

			queue = [(x, y)]
			seen[x][y] = True
			min_x = max_x = x
			min_y = max_y = y

			while queue:
				cx, cy = queue.pop()
				min_x = min(min_x, cx)
				min_y = min(min_y, cy)
				max_x = max(max_x, cx)
				max_y = max(max_y, cy)
				for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
					if 0 <= nx < width and 0 <= ny < height and not seen[nx][ny] and pixels[nx, ny] != 0:
						seen[nx][ny] = True
						queue.append((nx, ny))

			components.append((min_x, min_y, max_x + 1, max_y + 1))

	return components


def _map_components_to_grid(components: Iterable[BBox]) -> Dict[GridPos, BBox]:
	component_list = list(components)
	if len(component_list) != 9:
		raise ValueError("Expected exactly 9 connected alpha islands, got %s" % len(component_list))

	center_xs = {bbox: (bbox[0] + bbox[2]) / 2.0 for bbox in component_list}
	center_ys = {bbox: (bbox[1] + bbox[3]) / 2.0 for bbox in component_list}
	x_order = sorted(component_list, key=lambda bbox: center_xs[bbox])
	y_order = sorted(component_list, key=lambda bbox: center_ys[bbox])

	col_lookup: Dict[BBox, int] = {}
	row_lookup: Dict[BBox, int] = {}
	for index, bbox in enumerate(x_order):
		col_lookup[bbox] = index // 3
	for index, bbox in enumerate(y_order):
		row_lookup[bbox] = index // 3

	grid: Dict[GridPos, BBox] = {}
	for bbox in component_list:
		key = (row_lookup[bbox], col_lookup[bbox])
		if key in grid:
			raise ValueError("Multiple islands mapped to grid cell %s" % (key,))
		grid[key] = bbox

	return grid


def _alpha_crop(image: Image.Image) -> Image.Image:
	alpha_bbox = image.getchannel("A").getbbox()
	if alpha_bbox is None:
		raise ValueError("Image has no non-transparent pixels")
	return image.crop(alpha_bbox)


def _paste_resized(base: Image.Image, tile: Image.Image, box: BBox) -> None:
	width = box[2] - box[0]
	height = box[3] - box[1]
	resized = tile.resize((width, height), Image.Resampling.LANCZOS)
	base.alpha_composite(resized, (box[0], box[1]))


def _trim_interior_edges(tile: Image.Image, pos: GridPos, trim: int) -> Image.Image:
	if trim <= 0:
		return tile

	width, height = tile.size
	left = trim if pos[1] > 0 else 0
	top = trim if pos[0] > 0 else 0
	right = trim if pos[1] < 2 else 0
	bottom = trim if pos[0] < 2 else 0
	if left + right >= width or top + bottom >= height:
		raise ValueError("Interior trim %s is too large for tile %s at %s" % (trim, tile.size, pos))
	return tile.crop((left, top, width - right, height - bottom))


def _recompose_islands(image: Image.Image, size: Tuple[int, int], margin: int, interior_trim: int = 0) -> Image.Image:
	width, height = size
	grid = _map_components_to_grid(_alpha_components(image))
	crops: Dict[GridPos, Image.Image] = {}
	for pos, bbox in grid.items():
		tile = _alpha_crop(image.crop(bbox).convert("RGBA"))
		tile = _trim_interior_edges(tile, pos, interior_trim)
		crops[pos] = _alpha_crop(tile)
	center_w = width - margin * 2
	center_h = height - margin * 2
	if center_w <= 0 or center_h <= 0:
		raise ValueError("Invalid target size %s for margin %s" % (size, margin))

	canvas = Image.new("RGBA", size, (0, 0, 0, 0))
	boxes: Dict[GridPos, BBox] = {
		(0, 0): (0, 0, margin, margin),
		(0, 1): (margin, 0, margin + center_w, margin),
		(0, 2): (margin + center_w, 0, width, margin),
		(1, 0): (0, margin, margin, margin + center_h),
		(1, 1): (margin, margin, margin + center_w, margin + center_h),
		(1, 2): (margin + center_w, margin, width, margin + center_h),
		(2, 0): (0, margin + center_h, margin, height),
		(2, 1): (margin, margin + center_h, margin + center_w, height),
		(2, 2): (margin + center_w, margin + center_h, width, height),
	}

	for pos in ((1, 1),):
		_paste_resized(canvas, crops[pos], boxes[pos])
	for pos in ((0, 1), (1, 0), (1, 2), (2, 1)):
		_paste_resized(canvas, crops[pos], boxes[pos])
	for pos in ((0, 0), (0, 2), (2, 0), (2, 2)):
		_paste_resized(canvas, crops[pos], boxes[pos])

	return canvas


def _resize_continuous(image: Image.Image, size: Tuple[int, int]) -> Image.Image:
	cropped = _alpha_crop(image.convert("RGBA"))
	return cropped.resize(size, Image.Resampling.LANCZOS)


def _recompose_horizontal_islands(image: Image.Image, size: Tuple[int, int]) -> Image.Image:
	components = sorted(_alpha_components(image), key=lambda bbox: bbox[0])
	if len(components) != 3:
		raise ValueError("Expected exactly 3 connected alpha islands, got %s" % len(components))

	width, height = size
	source_w, source_h = image.size
	if source_h != height:
		raise ValueError("horizontal_3slice requires matching source/target height, got %s -> %s" % (image.size, size))

	left_tile = image.crop((0, 0, components[0][2], source_h)).convert("RGBA")
	center_tile = image.crop((components[1][0], 0, components[1][2], source_h)).convert("RGBA")
	right_tile = image.crop((components[2][0], 0, source_w, source_h)).convert("RGBA")

	left_w = left_tile.size[0]
	right_w = right_tile.size[0]
	center_w = width - left_w - right_w
	if center_w <= 0:
		raise ValueError("Invalid target size %s for horizontal_3slice widths %s/%s" % (size, left_w, right_w))

	canvas = Image.new("RGBA", size, (0, 0, 0, 0))
	canvas.alpha_composite(left_tile, (0, 0))
	_paste_resized(canvas, center_tile, (left_w, 0, left_w + center_w, height))
	canvas.alpha_composite(right_tile, (width - right_w, 0))
	return canvas


def _run_job(job: RecomposeJob) -> None:
	image = Image.open(job.source).convert("RGBA")
	if job.mode == "islands_3x3":
		output = _recompose_islands(image, job.size, job.margin, job.interior_trim)
	elif job.mode == "horizontal_3slice":
		output = _recompose_horizontal_islands(image, job.size)
	elif job.mode == "continuous":
		output = _resize_continuous(image, job.size)
	else:
		raise ValueError("Unsupported mode %s" % job.mode)

	job.output.parent.mkdir(parents=True, exist_ok=True)
	output.save(job.output)
	print(f"[ok] {job.name}: {job.source.name} -> {job.output.relative_to(ROOT)} {output.size}")


def main() -> None:
	jobs = [
		RecomposeJob(
			name="button_blue_regular",
			source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigBlueButton_Regular.png",
			output=OUT_DIR / "button_blue_regular.png",
			size=(128, 128),
			margin=32,
		),
		RecomposeJob(
			name="button_blue_pressed",
			source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigBlueButton_Pressed.png",
			output=OUT_DIR / "button_blue_pressed.png",
			size=(128, 128),
			margin=32,
		),
		RecomposeJob(
			name="button_red_regular",
			source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigRedButton_Regular.png",
			output=OUT_DIR / "button_red_regular.png",
			size=(128, 128),
			margin=32,
		),
		RecomposeJob(
			name="button_red_pressed",
			source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigRedButton_Pressed.png",
			output=OUT_DIR / "button_red_pressed.png",
			size=(128, 128),
			margin=32,
		),
		RecomposeJob(
			name="paper_regular",
			source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png",
			output=OUT_DIR / "paper_regular.png",
			size=(128, 128),
			margin=32,
			interior_trim=8,
		),
		RecomposeJob(
			name="paper_special",
			source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/SpecialPaper.png",
			output=OUT_DIR / "paper_special.png",
			size=(128, 128),
			margin=32,
		),
		RecomposeJob(
			name="slot_frame",
			source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table/WoodTable_Slots.png",
			output=OUT_DIR / "slot_frame.png",
			size=(96, 96),
			margin=24,
			mode="continuous",
		),
			RecomposeJob(
				name="bigbar_base",
				source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/BigBar_Base.png",
				output=OUT_DIR / "bigbar_base.png",
				size=(320, 64),
				margin=0,
				mode="horizontal_3slice",
			),
			RecomposeJob(
				name="wood_table_background",
				source=ROOT / "Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table/WoodTable.png",
				output=OUT_DIR / "wood_table_background.png",
			size=(192, 192),
			margin=48,
		),
	]

	for job in jobs:
		_run_job(job)


if __name__ == "__main__":
	main()
