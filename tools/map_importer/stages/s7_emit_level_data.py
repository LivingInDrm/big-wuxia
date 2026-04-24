"""Stage 7: emit resources/data/levels/<MAP_ID>.tres (LevelData)."""
from __future__ import annotations

from pathlib import Path

from ..config import map_res_path
from ..schema import SceneData, Vec2i, WalkableData
from ..writers import (
    TresBuilder,
    fmt_packed_vector2_array,
    fmt_str,
    fmt_vec2i,
    fmt_vec2i_dict_of_strings,
)


def emit_level_data(scene: SceneData,
                   walk: WalkableData,
                   map_scene_abs_path: Path,
                   out_path: Path,
                   level_name: str | None = None) -> None:
    """Write <MAP_ID>.tres with walkable + map_scene reference.

    Cells are written in Godot-space (non-negative): cell - bounds_min.
    render_origin captures the shift for debug/lookup.
    """
    bounds_min = scene.bounds_min
    map_id = scene.map_id

    def _norm(v: Vec2i) -> tuple[int, int]:
        return (v.x - bounds_min.x, v.y - bounds_min.y)

    walkable_normed = [_norm(c) for c in walk.walkable_cells]
    blocked_normed = [_norm(c) for c in walk.blocked_cells]
    terrain_normed: dict[tuple[int, int], str] = {}
    for c, t in walk.terrain_by_cell.items():
        terrain_normed[_norm(c)] = t

    # sort for reproducibility
    walkable_normed.sort(key=lambda p: (p[1], p[0]))
    blocked_normed.sort(key=lambda p: (p[1], p[0]))

    builder = TresBuilder("Resource", script_class="LevelData")
    script_path = "res://scripts/core/level_data.gd"
    builder.add_ext("Script", script_path, "1_script")
    scene_res = map_res_path(map_scene_abs_path)
    builder.add_ext("PackedScene", scene_res, "2_mapscene")

    builder.set_prop("script", 'ExtResource("1_script")')
    builder.set_prop("level_id", fmt_str(map_id.lower()))
    builder.set_prop("level_name", fmt_str(level_name or map_id))
    builder.set_prop("map_id", fmt_str(map_id))
    builder.set_prop("map_layout", "PackedVector2Array()")  # derived at runtime
    builder.set_prop("walkable_cells", fmt_packed_vector2_array(walkable_normed))
    builder.set_prop("blocked_cells", fmt_packed_vector2_array(blocked_normed))
    builder.set_prop("terrain_by_cell", fmt_vec2i_dict_of_strings(terrain_normed))
    builder.set_prop("map_scene", 'ExtResource("2_mapscene")')
    builder.set_prop("render_origin", fmt_vec2i(bounds_min.x, bounds_min.y))
    builder.set_prop("player_units", "Array[Dictionary]([])")
    builder.set_prop("enemy_units", "Array[Dictionary]([])")
    builder.set_prop("victory_condition", fmt_str("kill_all"))
    builder.set_prop("rewards", "Array[Dictionary]([])")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(builder.render(), encoding="utf-8")
