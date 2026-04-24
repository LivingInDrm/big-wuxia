"""Stage 1: parse Unity scene JSON into SceneData."""
from __future__ import annotations

import json
from pathlib import Path

from ..schema import LayerData, SceneData, TileInstance, Vec2i


def parse_scene(map_dir: Path) -> SceneData:
    scene_json = map_dir / "scene.json"
    if not scene_json.exists():
        raise FileNotFoundError(f"scene.json not found: {scene_json}")
    scene = json.loads(scene_json.read_text(encoding="utf-8"))

    map_id: str = scene["map_id"]
    b = scene["bounds"]
    bounds_min = Vec2i(int(b["min_x"]), int(b["min_y"]))
    bounds_max = Vec2i(int(b["max_x"]), int(b["max_y"]))
    ps = scene["pixel_size"]
    pixel_size = (int(ps["width"]), int(ps["height"]))

    layers: list[LayerData] = []
    for layer_meta in scene["layers"]:
        layer_path = map_dir / "layers" / layer_meta["file"]
        ld = json.loads(layer_path.read_text(encoding="utf-8"))
        tiles: list[TileInstance] = []
        for t in ld["tiles"]:
            cell = Vec2i(int(t["x"]), int(t["y"]))
            rect = t.get("sprite_rect")
            rect_tuple = None
            if rect is not None:
                rect_tuple = (int(rect["x"]), int(rect["y"]),
                              int(rect["w"]), int(rect["h"]))
            pivot = None
            if "pivot_x" in t and "pivot_y" in t:
                pivot = (float(t["pivot_x"]), float(t["pivot_y"]))
            texture = t.get("texture")
            tiles.append(TileInstance(
                cell=cell,
                sprite_name=str(t["sprite_name"]),
                texture=texture,
                sprite_rect=rect_tuple,
                pivot=pivot,
            ))
        o = layer_meta.get("origin") or ld.get("origin") or {"x": 0, "y": 0}
        sz = layer_meta.get("size") or ld.get("size") or {"x": 0, "y": 0}
        layers.append(LayerData(
            name=layer_meta["name"],
            sorting_order=int(layer_meta.get("sorting_order", 0)),
            origin=Vec2i(int(o["x"]), int(o["y"])),
            size=Vec2i(int(sz["x"]), int(sz["y"])),
            tiles=tiles,
        ))

    return SceneData(
        map_id=map_id,
        bounds_min=bounds_min,
        bounds_max=bounds_max,
        pixel_size=pixel_size,
        layers=layers,
    )
