"""Data classes for the importer pipeline."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass(frozen=True)
class Vec2i:
    x: int
    y: int

    def __add__(self, other: "Vec2i") -> "Vec2i":
        return Vec2i(self.x + other.x, self.y + other.y)

    def __sub__(self, other: "Vec2i") -> "Vec2i":
        return Vec2i(self.x - other.x, self.y - other.y)

    def as_tuple(self) -> tuple[int, int]:
        return (self.x, self.y)

    @staticmethod
    def from_tuple(t) -> "Vec2i":
        return Vec2i(int(t[0]), int(t[1]))


@dataclass
class TileInstance:
    cell: Vec2i                       # Unity cell (x, y) — raw, pre-normalization
    sprite_name: str                  # "tudi8.3_C_0" or "spr_-3585..."
    texture: Optional[str]            # "tudi8.3.png" or None (for spr_*)
    sprite_rect: Optional[tuple[int, int, int, int]]  # (x, y, w, h) in texture space
    pivot: Optional[tuple[float, float]]              # (px, py) normalized


@dataclass
class LayerData:
    name: str
    sorting_order: int
    origin: Vec2i
    size: Vec2i
    tiles: list[TileInstance]


@dataclass
class SceneData:
    map_id: str
    bounds_min: Vec2i
    bounds_max: Vec2i
    pixel_size: tuple[int, int]
    layers: list[LayerData]

    @property
    def bounds_size(self) -> Vec2i:
        return Vec2i(self.bounds_max.x - self.bounds_min.x + 1,
                     self.bounds_max.y - self.bounds_min.y + 1)


@dataclass
class SpriteInfo:
    name: str
    texture: str
    rect: tuple[int, int, int, int]   # (x, y, w, h) in texture
    pivot: tuple[float, float]        # normalized 0..1
    footprint_bucket: str             # one of FOOTPRINT_BUCKETS keys


@dataclass
class AtlasTile:
    sprite_name: str                  # logical key used by s5 to lookup
    atlas_coords: Vec2i               # column/row inside the atlas PNG
    pivot_px: tuple[int, int]         # absolute pivot in pixels, relative to the cell origin
    source_texture: str               # original Unity texture filename (for custom_data)
    bucket: str                       # footprint bucket key
    is_placeholder: bool = False


@dataclass
class AtlasSource:
    file_rel: str                     # atlas/ground_66x43_0.png (posix, relative to map dir)
    abs_path: str                     # absolute path for Godot res://
    tile_size: tuple[int, int]        # cell size inside this atlas (pixels)
    layout: list[AtlasTile]


@dataclass
class AtlasPlan:
    sources: list[AtlasSource] = field(default_factory=list)
    # sprite_name -> (source_index, atlas_coords, pivot_px, source_texture)
    index: dict[str, tuple[int, Vec2i, tuple[int, int], str]] = field(default_factory=dict)


@dataclass
class WalkableData:
    walkable_cells: list[Vec2i]
    blocked_cells: list[Vec2i]
    terrain_by_cell: dict[Vec2i, str]
    shaftway_cells: list[Vec2i]
