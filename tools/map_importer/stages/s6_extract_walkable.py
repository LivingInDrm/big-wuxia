"""Stage 6: extract walkable/blocked cells per design §E.1.

walkable = union(Ground*) - _Block - Wall - (WallCorner - whitelist) - (WallThing - whitelist)
terrain_by_cell = {cell: "grass"} for each walkable cell (initial version, all grass).
shaftway_cells: from _ShaftWay layer, independent (neither walkable nor blocked).
"""
from __future__ import annotations

from ..config import (
    BLOCK_LAYERS,
    GROUND_LAYERS,
    SHAFTWAY_LAYERS,
    WALKABLE_WHITELIST,
    WALLCORNER_LAYERS,
    WALL_LAYERS,
    WALLTHING_LAYERS,
)
from ..schema import SceneData, Vec2i, WalkableData


def _cells_for_layers(scene: SceneData, names: list[str]) -> set[Vec2i]:
    names_set = set(names)
    out: set[Vec2i] = set()
    for layer in scene.layers:
        if layer.name not in names_set:
            continue
        for tile in layer.tiles:
            out.add(tile.cell)
    return out


def _cells_for_layers_minus_whitelist(scene: SceneData,
                                      names: list[str]) -> set[Vec2i]:
    names_set = set(names)
    out: set[Vec2i] = set()
    for layer in scene.layers:
        if layer.name not in names_set:
            continue
        for tile in layer.tiles:
            if tile.sprite_name in WALKABLE_WHITELIST:
                continue
            out.add(tile.cell)
    return out


def extract_walkability(scene: SceneData) -> WalkableData:
    ground = _cells_for_layers(scene, GROUND_LAYERS)
    assert len(ground) > 0, f"no ground tiles in {scene.map_id}"

    block = _cells_for_layers(scene, BLOCK_LAYERS)
    wall = _cells_for_layers(scene, WALL_LAYERS)
    wc = _cells_for_layers_minus_whitelist(scene, WALLCORNER_LAYERS)
    wt = _cells_for_layers_minus_whitelist(scene, WALLTHING_LAYERS)
    shaft = _cells_for_layers(scene, SHAFTWAY_LAYERS)

    walkable = ground - block - wall - wc - wt
    blocked = block | wall | wc | wt

    # Normalize to bounds (convert Unity cells to non-negative Godot cells)
    # Note: we keep Unity-space cells; the s7 step normalizes when writing .tres.
    # That way s5 (layers) and s7 (level_data) share the same render_origin math.

    def _sort(cells: set[Vec2i]) -> list[Vec2i]:
        return sorted(cells, key=lambda v: (v.y, v.x))

    walkable_list = _sort(walkable)
    terrain = {c: "grass" for c in walkable_list}
    return WalkableData(
        walkable_cells=walkable_list,
        blocked_cells=_sort(blocked),
        terrain_by_cell=terrain,
        shaftway_cells=_sort(shaft),
    )
