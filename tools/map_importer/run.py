"""CLI entry point for the map importer.

Usage:
    python3 tools/map_importer/run.py --map Map_10020 [--validate] [--force]
"""
from __future__ import annotations

import argparse
import json
import sys
import traceback
from pathlib import Path

# Allow running as: python3 tools/map_importer/run.py --map Map_XXXX
# Ensure package parent on sys.path so `import tools.map_importer...` works.
_THIS = Path(__file__).resolve()
_PROJECT = _THIS.parent.parent.parent
if str(_PROJECT) not in sys.path:
    sys.path.insert(0, str(_PROJECT))

from tools.map_importer.config import (  # noqa: E402
    ASSETS_SCENES_DIR,
    ASSETS_SPRITES_JSON,
    OUTPUT_LEVELS_ROOT,
    OUTPUT_MAPS_ROOT,
    REPORT_ROOT,
    SPR_STRATEGY_SKIP,
    map_godot_output_dir,
    map_res_path,
)
from tools.map_importer.stages.s1_parse_scene import parse_scene  # noqa: E402
from tools.map_importer.stages.s2_build_sprite_index import build_sprite_index  # noqa: E402
from tools.map_importer.stages.s3_repack_atlas import (  # noqa: E402
    collect_used_sprites,
    repack_atlas,
)
from tools.map_importer.stages.s4_generate_tileset import generate_tileset  # noqa: E402
from tools.map_importer.stages.s5_generate_layers import generate_layers  # noqa: E402
from tools.map_importer.stages.s6_extract_walkable import extract_walkability  # noqa: E402
from tools.map_importer.stages.s7_emit_level_data import emit_level_data  # noqa: E402
from tools.map_importer.validators.composite_compare import (  # noqa: E402
    compare_bbox,
    render_composite_preview,
)
from tools.map_importer.validators.sprite_missing_report import (  # noqa: E402
    summarize_missing,
    summarize_wall_names,
)
from tools.map_importer.validators.walkable_sanity import walkable_sanity  # noqa: E402


def _needs_placeholder(scene) -> bool:
    """True iff any spr_* tile lives on a non-SKIP layer."""
    for layer in scene.layers:
        if layer.name in SPR_STRATEGY_SKIP:
            continue
        for tile in layer.tiles:
            if tile.sprite_name.startswith("spr_"):
                return True
    return False


def _count_spr_per_layer(scene) -> dict[str, int]:
    out: dict[str, int] = {}
    for layer in scene.layers:
        c = sum(1 for t in layer.tiles if t.sprite_name.startswith("spr_"))
        if c:
            out[layer.name] = c
    return out


def run(map_id: str, *, validate: bool, force: bool) -> int:
    map_dir = ASSETS_SCENES_DIR / map_id
    if not map_dir.exists():
        print(f"[error] map dir not found: {map_dir}", file=sys.stderr)
        return 2

    out_godot_dir = map_godot_output_dir(map_id)
    out_atlas_dir = out_godot_dir / "atlas"
    tileset_path = out_godot_dir / f"{map_id}_tileset.tres"
    scene_path = out_godot_dir / f"{map_id}_battle_map.tscn"
    manifest_path = out_godot_dir / "manifest.json"
    level_path = OUTPUT_LEVELS_ROOT / f"{map_id}.tres"
    report_dir = REPORT_ROOT / map_id
    report_path = report_dir / "report.md"

    print(f"[s1] parsing {map_id}...")
    scene = parse_scene(map_dir)
    print(f"  bounds={scene.bounds_min.as_tuple()}..{scene.bounds_max.as_tuple()} "
          f"size={scene.bounds_size.as_tuple()} layers={len(scene.layers)}")

    print("[s2] building sprite index...")
    sprite_index = build_sprite_index(ASSETS_SPRITES_JSON)
    print(f"  {len(sprite_index)} sprites loaded")

    used, missing_total, missing_detail = collect_used_sprites(scene, sprite_index)
    print(f"  used={len(used)} unique sprites; spr_* layers={list(missing_total.keys())}")

    needs_ph = _needs_placeholder(scene)
    print(f"[s3] repacking atlas -> {out_atlas_dir} (placeholder={needs_ph})")
    plan = repack_atlas(scene, used, missing_detail, out_atlas_dir, needs_ph)
    print(f"  {len(plan.sources)} atlas source(s)")

    print(f"[s4] generating tileset -> {tileset_path}")
    lookup = generate_tileset(scene, plan, tileset_path)

    placeholder_src = None
    if "__placeholder__" in plan.index:
        placeholder_src = plan.index["__placeholder__"][0]

    print(f"[s5] generating layers -> {scene_path}")
    layer_stats = generate_layers(
        scene=scene,
        tileset_res_path=map_res_path(tileset_path),
        lookup=lookup,
        placeholder_src=placeholder_src,
        out_path=scene_path,
    )
    print(f"  cells per layer: {layer_stats}")

    print("[s6] extracting walkable...")
    walk = extract_walkability(scene)
    sanity = walkable_sanity(scene, walk)
    print(f"  walkable={sanity['walkable_count']} blocked={sanity['blocked_count']} "
          f"ratio={sanity['walkable_ratio']:.2%}")
    for w in sanity["warnings"]:
        print(f"  [warn] {w}")

    print(f"[s7] emitting level data -> {level_path}")
    emit_level_data(
        scene=scene,
        walk=walk,
        map_scene_abs_path=scene_path,
        out_path=level_path,
        level_name=map_id,
    )

    # manifest
    manifest = {
        "map_id": map_id,
        "bounds_min": scene.bounds_min.as_tuple(),
        "bounds_max": scene.bounds_max.as_tuple(),
        "bounds_size": scene.bounds_size.as_tuple(),
        "pixel_size": list(scene.pixel_size),
        "atlas_sources": [s.file_rel for s in plan.sources],
        "unique_sprites_used": len(used),
        "spr_per_layer": _count_spr_per_layer(scene),
        "layer_cell_counts": layer_stats,
        "walkable_count": sanity["walkable_count"],
        "blocked_count": sanity["blocked_count"],
        "walkable_ratio": sanity["walkable_ratio"],
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True),
                             encoding="utf-8")

    # report.md
    report_dir.mkdir(parents=True, exist_ok=True)
    report_lines = [
        f"# {map_id} import report",
        "",
        f"- bounds: {scene.bounds_min.as_tuple()} .. {scene.bounds_max.as_tuple()} "
        f"(size {scene.bounds_size.as_tuple()})",
        f"- pixel size: {scene.pixel_size}",
        f"- layers: {len(scene.layers)} parsed, routed to {len([k for k,v in layer_stats.items() if k != '_skipped_spr' and v>0])} Godot layers",
        f"- unique sprites used: {len(used)} / index total {len(sprite_index)}",
        f"- atlas sources: {len(plan.sources)}",
        "",
        "## cells per Godot layer",
        "",
    ]
    for k in sorted(layer_stats.keys()):
        report_lines.append(f"- `{k}`: {layer_stats[k]}")
    report_lines.append("")

    report_lines.append("## walkability")
    report_lines.append("")
    report_lines.append(f"- walkable cells: {sanity['walkable_count']}")
    report_lines.append(f"- blocked cells:  {sanity['blocked_count']}")
    report_lines.append(f"- walkable ratio (over bounds): {sanity['walkable_ratio']:.2%}")
    if sanity["warnings"]:
        report_lines.append("")
        report_lines.append("### warnings")
        for w in sanity["warnings"]:
            report_lines.append(f"- {w}")
    report_lines.append("")

    report_lines.append("## spr_* (missing GUID refs)")
    report_lines.append("")
    report_lines.append(summarize_missing(missing_total, missing_detail))
    report_lines.append("")

    report_lines.append("## WallCorner sprites (aggregate)")
    report_lines.append("")
    report_lines.append(summarize_wall_names(scene, ["WallCorner"]))
    report_lines.append("")

    report_lines.append("## WallThing sprites (aggregate)")
    report_lines.append("")
    report_lines.append(summarize_wall_names(scene, ["WallThing"]))
    report_lines.append("")

    if validate:
        print("[validate] rendering composite preview...")
        preview_path = report_dir / "preview.png"
        render_composite_preview(scene, sprite_index, preview_path)
        unity_comp = map_dir / "composite.png"
        bbox = compare_bbox(preview_path, unity_comp)
        print(f"  preview size={bbox['preview_size']} unity={bbox['unity_size']} "
              f"Δw={bbox['delta_w']} Δh={bbox['delta_h']} pass={bbox['pass']}")
        report_lines.append("## composite bbox compare")
        report_lines.append("")
        report_lines.append(f"- preview size: {bbox['preview_size']}")
        report_lines.append(f"- unity composite size: {bbox['unity_size']}")
        report_lines.append(f"- preview bbox: {bbox['preview_bbox']}")
        report_lines.append(f"- unity bbox: {bbox['unity_bbox']}")
        report_lines.append(f"- Δw={bbox['delta_w']} Δh={bbox['delta_h']} "
                            f"(tolerance {bbox['tolerance_px']}px) "
                            f"→ **{'PASS' if bbox['pass'] else 'FAIL'}**")
        report_lines.append("")

    report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    print(f"[done] report: {report_path}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Wuxia map importer (Unity → Godot 4)")
    ap.add_argument("--map", required=True, help="Map ID, e.g. Map_10020")
    ap.add_argument("--validate", action="store_true", help="Run composite bbox compare")
    ap.add_argument("--force", action="store_true", help="Ignore cache")
    args = ap.parse_args()
    try:
        return run(args.map, validate=args.validate, force=args.force)
    except Exception as e:
        print(f"[fatal] {type(e).__name__}: {e}", file=sys.stderr)
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
