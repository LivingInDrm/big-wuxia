"""Stage 4: emit the per-map .tres TileSet.

Structure (design §C.3 + §C.4):
  - one TileSetAtlasSource per AtlasSource from the plan
  - 6 custom_data_layers
  - tile_shape = 1 (iso) / tile_layout = 0 (stacked) / tile_size = (66, 36)

Format ref: Godot 4.6 saved .tres for iso TileSet.
"""
from __future__ import annotations

from pathlib import Path

from ..config import (
    CUSTOM_DATA_LAYERS,
    LAYER_ROLE,
    SPR_STRATEGY_SKIP,
    TILESET_META,
    WALKABLE_WHITELIST,
    map_res_path,
)
from ..schema import AtlasPlan, SceneData
from ..writers import (
    SubResource,
    TresBuilder,
    fmt_bool,
    fmt_str,
    fmt_vec2i,
)


def _layer_role_for_sprite(scene: SceneData, sprite_name: str) -> tuple[str, str, bool]:
    """Return (layer_role, terrain_type, walkable_hint) for the FIRST layer
    that references sprite_name. This is a heuristic for custom_data tagging;
    the authoritative walkable data lives in LevelData.walkable_cells.
    """
    for layer in scene.layers:
        for tile in layer.tiles:
            if tile.sprite_name == sprite_name:
                role = LAYER_ROLE.get(layer.name, "deco")
                if role == "ground":
                    return (role, "grass", True)
                if role == "wall":
                    # WallCorner / WallThing may be walkable via whitelist
                    return (role, "wall", sprite_name in WALKABLE_WHITELIST)
                if role == "roof":
                    return (role, "roof", False)
                if role == "block":
                    return (role, "block", False)
                return (role, "deco", False)
    return ("deco", "deco", False)


def generate_tileset(scene: SceneData,
                    plan: AtlasPlan,
                    out_path: Path) -> dict[str, tuple[int, tuple[int, int]]]:
    """Write the .tres and return a mapping sprite_name -> (source_index, atlas_coords).

    We keep the return simple; s5 consumes it to decide set_cell arguments.
    """
    out_path.parent.mkdir(parents=True, exist_ok=True)
    builder = TresBuilder("TileSet")

    # Ext resources: one Texture2D per atlas source
    ext_ids: list[str] = []
    for i, src in enumerate(plan.sources):
        rid = f"atlas_{i}"
        # The .tres will sit in the map dir; Godot expects res:// path.
        res_path = map_res_path(Path(src.abs_path))
        builder.add_ext("Texture2D", res_path, rid)
        ext_ids.append(rid)

    # Sub resources: one TileSetAtlasSource per atlas source
    for i, src in enumerate(plan.sources):
        src_rid = f"src_{i}"
        props: list[tuple[str, str]] = []
        props.append(("texture", f'ExtResource("{ext_ids[i]}")'))
        props.append(("texture_region_size", fmt_vec2i(*src.tile_size)))
        # Emit each tile: `0:0/0 = 0` style (create)
        # Then: `0:0/0/custom_data_<n> = value` style (data)
        # Stable sort by (atlas_coords.y, atlas_coords.x, sprite_name)
        sorted_layout = sorted(
            src.layout,
            key=lambda t: (t.atlas_coords.y, t.atlas_coords.x, t.sprite_name),
        )
        for t in sorted_layout:
            k = f"{t.atlas_coords.x}:{t.atlas_coords.y}/0"
            props.append((k, "0"))
            # texture_origin (pivot correction) — TileData uses pixel offset from cell origin
            # We feed (pivot_px.x - cell_w/2, pivot_px.y - cell_h/2) so Y-sort uses bottom
            cell_w, cell_h = src.tile_size
            ox = t.pivot_px[0] - cell_w // 2
            oy = t.pivot_px[1] - cell_h // 2
            props.append((f"{k}/texture_origin", fmt_vec2i(ox, oy)))
            # custom_data_0 .. custom_data_5
            if t.is_placeholder:
                role, terrain, walkable_hint = ("missing", "deco", False)
                tile_id = "__placeholder__"
                tex_name = "placeholder.png"
            else:
                role, terrain, walkable_hint = _layer_role_for_sprite(scene, t.sprite_name)
                tile_id = t.sprite_name
                tex_name = t.source_texture
            props.append((f"{k}/custom_data_0", fmt_str(tile_id)))
            props.append((f"{k}/custom_data_1", fmt_str(tex_name)))
            props.append((f"{k}/custom_data_2", fmt_str(role)))
            props.append((f"{k}/custom_data_3", fmt_bool(walkable_hint)))
            props.append((f"{k}/custom_data_4", fmt_str(terrain)))
            props.append((f"{k}/custom_data_5", "0"))
            # y_sort_origin (for ysort-enabled layers)
            # Use bottom-of-sprite = cell_h - pivot_y_px; but since texture_origin
            # already shifts, we'll use half-h as a stable default.
            y_origin = (cell_h // 2) - t.pivot_px[1]
            props.append((f"{k}/y_sort_origin", str(y_origin)))
        builder.add_sub(SubResource(rid=src_rid, rtype="TileSetAtlasSource", props=props))

    # [resource] body
    builder.set_prop("tile_shape", str(TILESET_META["tile_shape"]))
    builder.set_prop("tile_layout", str(TILESET_META["tile_layout"]))
    builder.set_prop("tile_offset_axis", str(TILESET_META["tile_offset_axis"]))
    builder.set_prop("tile_size", fmt_vec2i(*TILESET_META["tile_size"]))

    for i, (cname, ctype) in enumerate(CUSTOM_DATA_LAYERS):
        builder.set_prop(f"custom_data_layer_{i}/name", fmt_str(cname))
        builder.set_prop(f"custom_data_layer_{i}/type", str(ctype))

    for i in range(len(plan.sources)):
        builder.set_prop(f"sources/{i}", f'SubResource("src_{i}")')

    out_path.write_text(builder.render(), encoding="utf-8")

    # Return lookup for s5
    lookup: dict[str, tuple[int, tuple[int, int]]] = {}
    for name, (src_i, coords, _pivot, _tex) in plan.index.items():
        lookup[name] = (src_i, (coords.x, coords.y))
    return lookup
