"""Stage 5: emit the per-map .tscn with 6 TileMapLayer nodes.

Node hierarchy (design §D.2):

    Node2D (root)
    ├── GroundBaseLayer      TileMapLayer, z=-10
    ├── GroundDetailLayer    TileMapLayer, z=-5
    ├── YSortRoot            Node2D, y_sort_enabled=true
    │   ├── ObstacleLayer    TileMapLayer, y_sort=true
    │   └── DecorationLayer  TileMapLayer, y_sort=true
    ├── RoofOverlayLayer     TileMapLayer, z=20
    └── DebugBlockLayer      TileMapLayer, z=50, visible=false

Each TileMapLayer node references the shared tileset (ext_resource).
``tile_map_data`` is the packed binary-in-text format Godot uses to persist
``set_cell`` calls. We emit it as a PackedByteArray.
"""
from __future__ import annotations

import struct
from pathlib import Path

from ..config import (
    GODOT_LAYER_ORDER,
    GODOT_LAYER_Z,
    LAYER_ROUTE,
    LAYER_VISIBLE_DEFAULT,
    SPR_STRATEGY_SKIP,
    YSORT_LAYERS,
    map_res_path,
)
from ..schema import SceneData, Vec2i
from ..writers import (
    SceneNode,
    TscnBuilder,
    fmt_bool,
    fmt_str,
    fmt_vec2i,
)


def _encode_tile_map_data(cells: list[tuple[int, int, int, int, int]]) -> str:
    """Encode set_cell calls into Godot's ``tile_map_data`` PackedByteArray.

    Format per Godot 4 source (scene/2d/tile_map_layer.cpp set_tile_data):
    For each cell, 12 bytes little-endian:
      int16 x, int16 y,
      uint16 source_id,
      uint16 atlas_x, uint16 atlas_y,
      uint16 alternative

    The whole array is preceded by a uint16 format version (=0).
    """
    fmt_version = 0
    buf = bytearray()
    buf += struct.pack("<H", fmt_version)
    for (x, y, src_id, ax, ay) in cells:
        buf += struct.pack("<hhHHHH", x, y, src_id, ax, ay, 0)
    # PackedByteArray literal: numbers separated by commas
    return "PackedByteArray(" + ", ".join(str(b) for b in buf) + ")"


def generate_layers(scene: SceneData,
                   tileset_res_path: str,
                   lookup: dict[str, tuple[int, tuple[int, int]]],
                   placeholder_src: int | None,
                   out_path: Path) -> dict[str, int]:
    """Build and write the .tscn. Return per-layer tile counts."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    builder = TscnBuilder()
    builder.add_ext("TileSet", tileset_res_path, "tileset_0")

    # Group tiles by Godot layer name (design §D.1)
    # cells: list of (unity_cell_x, unity_cell_y, src_id, atlas_x, atlas_y)
    by_layer: dict[str, list[tuple[int, int, int, int, int]]] = {k: [] for k in GODOT_LAYER_ORDER}
    skipped_spr_count: dict[str, int] = {}

    bounds_min = scene.bounds_min
    for layer in scene.layers:
        godot_layer = LAYER_ROUTE.get(layer.name)
        if godot_layer is None:
            # Unknown layer — drop silently; report will list it
            continue
        for tile in layer.tiles:
            is_spr = tile.sprite_name.startswith("spr_") or tile.sprite_name not in lookup
            if is_spr:
                if layer.name in SPR_STRATEGY_SKIP:
                    # Strategy 3: skip set_cell entirely
                    skipped_spr_count[layer.name] = skipped_spr_count.get(layer.name, 0) + 1
                    continue
                # Strategy 2: use placeholder
                if placeholder_src is None:
                    continue
                src_i, ax, ay = placeholder_src, 0, 0
            else:
                src_i, (ax, ay) = lookup[tile.sprite_name]
            gx = tile.cell.x - bounds_min.x
            gy = tile.cell.y - bounds_min.y
            by_layer[godot_layer].append((gx, gy, src_i, ax, ay))

    # Deterministic cell ordering — sort by (y, x)
    for k in by_layer:
        by_layer[k].sort(key=lambda c: (c[1], c[0], c[2], c[3], c[4]))
        # Deduplicate by (gx, gy) — Godot TileMapLayer is keyed by cell; last-write-wins.
        # Here we keep the FIRST occurrence (stable after sort) to stay deterministic.
        seen: set[tuple[int, int]] = set()
        dedup: list[tuple[int, int, int, int, int]] = []
        for cell in by_layer[k]:
            key = (cell[0], cell[1])
            if key in seen:
                continue
            seen.add(key)
            dedup.append(cell)
        by_layer[k] = dedup

    # Build scene
    root = SceneNode(name="BattleMap", node_type="Node2D", parent=".",
                     props=[], children=[])
    builder.set_root(root)

    ysort_root = SceneNode(name="YSortRoot", node_type="Node2D", parent=".",
                           props=[("y_sort_enabled", "true")], children=[])

    def _tile_map_node(name: str, parent_path: str) -> SceneNode:
        cells = by_layer[name]
        props: list[tuple[str, str]] = []
        props.append(("tile_set", 'ExtResource("tileset_0")'))
        props.append(("tile_map_data", _encode_tile_map_data(cells)))
        if name in YSORT_LAYERS:
            props.append(("y_sort_enabled", "true"))
        props.append(("z_index", str(GODOT_LAYER_Z[name])))
        if not LAYER_VISIBLE_DEFAULT.get(name, True):
            props.append(("visible", "false"))
        return SceneNode(name=name, node_type="TileMapLayer", parent=parent_path,
                         props=props, children=[])

    # Layer order:
    # GroundBase + GroundDetail under root
    root.children.append(_tile_map_node("GroundBaseLayer", "."))
    root.children.append(_tile_map_node("GroundDetailLayer", "."))
    # YSortRoot with Obstacle + Decoration
    root.children.append(ysort_root)
    ysort_root.children.append(_tile_map_node("ObstacleLayer", "YSortRoot"))
    ysort_root.children.append(_tile_map_node("DecorationLayer", "YSortRoot"))
    # Roof + Debug
    root.children.append(_tile_map_node("RoofOverlayLayer", "."))
    root.children.append(_tile_map_node("DebugBlockLayer", "."))

    out_path.write_text(builder.render(), encoding="utf-8")

    stats = {k: len(v) for k, v in by_layer.items()}
    stats["_skipped_spr"] = sum(skipped_spr_count.values())
    return stats
