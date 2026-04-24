"""Stage 3: repack atlas PNGs by footprint bucket.

Input:
  - SceneData (from s1)
  - sprite_index (from s2)
  - textures dir (wulinsh-assets/maps/tiles/textures/)

Output:
  - resources/maps/imported/<MAP_ID>/atlas/<bucket>_<N>.png
  - resources/maps/imported/<MAP_ID>/atlas/placeholder.png (if any spr_* with strategy=placeholder)
  - AtlasPlan with deterministic layout (sprite_name sorted)

Strategy per design §C.2: per-map atlas, buckets by footprint, max 64 cols.
Reproducibility: sprite_name sorted lex; identical input -> byte-identical PNG.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

from ..config import (
    ASSETS_TEXTURES_DIR,
    ATLAS_MAX_COLS,
    FOOTPRINT_BUCKETS,
    PLACEHOLDER_COLOR,
    PLACEHOLDER_SIZE,
    SPR_STRATEGY_SKIP,
)
from ..schema import (
    AtlasPlan,
    AtlasSource,
    AtlasTile,
    SceneData,
    SpriteInfo,
    Vec2i,
)


def _load_texture(name: str, cache: dict[str, Image.Image]) -> Image.Image | None:
    """Load and cache a texture from the assets dir."""
    if name in cache:
        return cache[name]
    p = ASSETS_TEXTURES_DIR / name
    if not p.exists():
        cache[name] = None
        return None
    img = Image.open(p).convert("RGBA")
    cache[name] = img
    return img


def collect_used_sprites(scene: SceneData,
                        sprite_index: dict[str, SpriteInfo]) -> tuple[dict[str, SpriteInfo],
                                                                      dict[str, int],
                                                                      dict[str, dict[str, int]]]:
    """Return (used sprites map, missing-by-layer counts, missing-by-layer-name detail).

    ``used`` = sprite_name -> SpriteInfo, only those present in ``sprite_index``.
    ``missing_total`` = layer_name -> count of spr_* tiles.
    ``missing_detail`` = layer_name -> {sprite_name: count}
    """
    used: dict[str, SpriteInfo] = {}
    missing_total: dict[str, int] = {}
    missing_detail: dict[str, dict[str, int]] = {}
    for layer in scene.layers:
        for tile in layer.tiles:
            name = tile.sprite_name
            if name in sprite_index:
                used[name] = sprite_index[name]
            else:
                missing_total[layer.name] = missing_total.get(layer.name, 0) + 1
                d = missing_detail.setdefault(layer.name, {})
                d[name] = d.get(name, 0) + 1
    return used, missing_total, missing_detail


def _emit_placeholder(out_dir: Path) -> Path:
    p = out_dir / "placeholder.png"
    img = Image.new("RGBA", PLACEHOLDER_SIZE, PLACEHOLDER_COLOR)
    p.parent.mkdir(parents=True, exist_ok=True)
    img.save(p, "PNG")
    return p


def repack_atlas(scene: SceneData,
                 used_sprites: dict[str, SpriteInfo],
                 missing_detail: dict[str, dict[str, int]],
                 out_dir: Path,
                 needs_placeholder: bool) -> AtlasPlan:
    """Build per-map atlas PNGs and return an AtlasPlan.

    ``needs_placeholder`` = True iff any spr_* tile will be rendered (non-SKIP layer).
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    plan = AtlasPlan()
    texture_cache: dict[str, Image.Image] = {}

    # Group sprites by bucket, sorted by name
    by_bucket: dict[str, list[SpriteInfo]] = {k: [] for k in FOOTPRINT_BUCKETS.keys()}
    for name in sorted(used_sprites.keys()):
        info = used_sprites[name]
        by_bucket.setdefault(info.footprint_bucket, []).append(info)

    def _save_source(bucket: str, idx: int,
                     tiles: list[SpriteInfo]) -> tuple[AtlasSource, list[AtlasTile]]:
        cell_w, cell_h = FOOTPRINT_BUCKETS[bucket]
        cols = min(ATLAS_MAX_COLS, max(1, len(tiles)))
        rows = (len(tiles) + cols - 1) // cols
        img = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
        layout: list[AtlasTile] = []
        for i, sp in enumerate(tiles):
            ax, ay = i % cols, i // cols
            src_tex = _load_texture(sp.texture, texture_cache)
            if src_tex is None:
                continue  # silently skip broken texture ref (rare)
            rx, ry, rw, rh = sp.rect
            crop = src_tex.crop((rx, ry, rx + rw, ry + rh))
            # Top-left align inside the cell
            img.paste(crop, (ax * cell_w, ay * cell_h), crop)
            pivot_px = (int(round(sp.pivot[0] * rw)),
                        int(round(sp.pivot[1] * rh)))
            layout.append(AtlasTile(
                sprite_name=sp.name,
                atlas_coords=Vec2i(ax, ay),
                pivot_px=pivot_px,
                source_texture=sp.texture,
                bucket=bucket,
                is_placeholder=False,
            ))
        fname = f"{bucket}_{idx}.png"
        img.save(out_dir / fname, "PNG")
        src = AtlasSource(
            file_rel=f"atlas/{fname}",
            abs_path=str((out_dir / fname).resolve()),
            tile_size=(cell_w, cell_h),
            layout=layout,
        )
        return src, layout

    source_idx = 0
    for bucket in sorted(FOOTPRINT_BUCKETS.keys()):
        sprites = by_bucket.get(bucket, [])
        if not sprites:
            continue
        # split into chunks of cols * some rows; keep it simple — one file, even
        # if huge. ATLAS_MAX_COLS caps width.
        # Chunk rows-wise so each file stays manageable.
        # We'll split into chunks of 1024 tiles to bound PNG size.
        CHUNK = ATLAS_MAX_COLS * 32  # 64 cols * 32 rows = 2048 tiles per atlas
        for start in range(0, len(sprites), CHUNK):
            chunk = sprites[start:start + CHUNK]
            src, layout = _save_source(bucket, source_idx, chunk)
            plan.sources.append(src)
            for atlas_tile in layout:
                plan.index[atlas_tile.sprite_name] = (
                    source_idx,
                    atlas_tile.atlas_coords,
                    atlas_tile.pivot_px,
                    atlas_tile.source_texture,
                )
            source_idx += 1

    # Optional placeholder source — one-cell atlas for all spr_* render strategy
    if needs_placeholder:
        _emit_placeholder(out_dir)
        # Build a 1x1 "placeholder_atlas" as its own source so Godot has a valid
        # texture source to set_cell against.
        fname = "placeholder.png"
        src = AtlasSource(
            file_rel=f"atlas/{fname}",
            abs_path=str((out_dir / fname).resolve()),
            tile_size=PLACEHOLDER_SIZE,
            layout=[AtlasTile(
                sprite_name="__placeholder__",
                atlas_coords=Vec2i(0, 0),
                pivot_px=(PLACEHOLDER_SIZE[0] // 2, PLACEHOLDER_SIZE[1] // 2),
                source_texture="placeholder.png",
                bucket="placeholder",
                is_placeholder=True,
            )],
        )
        plan.sources.append(src)
        plan.index["__placeholder__"] = (
            source_idx, Vec2i(0, 0), (PLACEHOLDER_SIZE[0] // 2, PLACEHOLDER_SIZE[1] // 2),
            "placeholder.png",
        )
        source_idx += 1

    return plan
