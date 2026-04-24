"""Walkable sanity checks."""
from __future__ import annotations

from ..schema import SceneData, WalkableData


def walkable_sanity(scene: SceneData, walk: WalkableData) -> dict:
    """Return sanity stats + any warnings."""
    warnings: list[str] = []
    if len(walk.walkable_cells) == 0:
        warnings.append("walkable set is EMPTY")
    bounds_area = scene.bounds_size.x * scene.bounds_size.y
    ratio = len(walk.walkable_cells) / max(1, bounds_area)
    if ratio < 0.05:
        warnings.append(f"walkable ratio very low: {ratio:.2%}")
    return {
        "walkable_count": len(walk.walkable_cells),
        "blocked_count": len(walk.blocked_cells),
        "shaft_count": len(walk.shaftway_cells),
        "bounds_area": bounds_area,
        "walkable_ratio": ratio,
        "warnings": warnings,
    }
