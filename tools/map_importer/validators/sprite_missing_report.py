"""Sprite-missing report helper."""
from __future__ import annotations


def summarize_missing(missing_total: dict[str, int],
                      missing_detail: dict[str, dict[str, int]],
                      top_n: int = 20) -> str:
    lines: list[str] = []
    if not missing_total:
        lines.append("- no `spr_*` tiles found")
        return "\n".join(lines)
    for layer_name, total in sorted(missing_total.items()):
        lines.append(f"- **{layer_name}**: {total} missing sprite refs")
        detail = missing_detail.get(layer_name, {})
        top = sorted(detail.items(), key=lambda kv: -kv[1])[:top_n]
        for sprite_name, cnt in top:
            lines.append(f"  - `{sprite_name}` x{cnt}")
    return "\n".join(lines)


def summarize_wall_names(scene, layer_names: list[str], top_n: int = 30) -> str:
    """Aggregate unique sprite names used by the given layers."""
    counts: dict[str, int] = {}
    target = set(layer_names)
    for layer in scene.layers:
        if layer.name not in target:
            continue
        for tile in layer.tiles:
            counts[tile.sprite_name] = counts.get(tile.sprite_name, 0) + 1
    if not counts:
        return "_no tiles_"
    lines = [f"| sprite | count |", f"| --- | --- |"]
    for name, c in sorted(counts.items(), key=lambda kv: -kv[1])[:top_n]:
        lines.append(f"| `{name}` | {c} |")
    return "\n".join(lines)
