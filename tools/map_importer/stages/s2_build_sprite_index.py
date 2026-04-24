"""Stage 2: build a global sprite index.

Reads ``wulinsh-assets/maps/tiles/sprites.json`` and returns a dict keyed by
sprite *name* (not GUID). Sprites missing from this index become spr_* in
the scene layers (dangling GUID references in the original Unity data).
"""
from __future__ import annotations

import json
from pathlib import Path

from ..config import FOOTPRINT_BUCKETS
from ..schema import SpriteInfo


def _pick_bucket(w: int, h: int) -> str:
    """Return the smallest footprint bucket that can contain the sprite.

    Buckets are ordered small -> large to prefer tight packing.
    ``tall_76x128`` acts as the fallback for any oversized sprite.
    """
    # fixed priority: try specific matches first, then fall through
    if w <= 62 and h <= 32:
        return "block_62x32"
    if w <= 66 and h <= 36:
        return "wall_66x36"
    if w <= 66 and h <= 43:
        return "ground_66x43"
    return "tall_76x128"


def build_sprite_index(sprites_json: Path) -> dict[str, SpriteInfo]:
    if not sprites_json.exists():
        raise FileNotFoundError(f"sprites.json not found: {sprites_json}")
    raw = json.loads(sprites_json.read_text(encoding="utf-8"))

    index: dict[str, SpriteInfo] = {}
    for _guid, info in raw.items():
        name = info.get("name")
        if not name:
            continue
        x = int(info.get("x", 0))
        y = int(info.get("y", 0))
        w = int(info.get("w", 0))
        h = int(info.get("h", 0))
        tex = str(info.get("texture", ""))
        pivot_x = float(info.get("pivot_x", 0.5))
        pivot_y = float(info.get("pivot_y", 0.5))
        bucket = _pick_bucket(w, h)
        index[name] = SpriteInfo(
            name=name,
            texture=tex,
            rect=(x, y, w, h),
            pivot=(pivot_x, pivot_y),
            footprint_bucket=bucket,
        )
    return index
