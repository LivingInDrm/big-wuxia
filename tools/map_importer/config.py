"""Global config constants for the map importer.

All paths resolved relative to the repo root (``PROJECT_ROOT``) so the CLI
can be invoked from anywhere.
"""
from __future__ import annotations

from pathlib import Path


# --------------------------------------------------------------------------- paths
# map_importer/ -> tools/ -> project root
PROJECT_ROOT: Path = Path(__file__).resolve().parent.parent.parent

ASSETS_MAPS_DIR: Path = PROJECT_ROOT / "wulinsh-assets" / "maps"
ASSETS_SCENES_DIR: Path = ASSETS_MAPS_DIR / "scenes"
ASSETS_TILES_DIR: Path = ASSETS_MAPS_DIR / "tiles"
ASSETS_SPRITES_JSON: Path = ASSETS_TILES_DIR / "sprites.json"
ASSETS_TEXTURES_DIR: Path = ASSETS_TILES_DIR / "textures"

OUTPUT_MAPS_ROOT: Path = PROJECT_ROOT / "resources" / "maps" / "imported"
OUTPUT_LEVELS_ROOT: Path = PROJECT_ROOT / "resources" / "data" / "levels" / "imported"
REPORT_ROOT: Path = PROJECT_ROOT / "tools" / "map_importer" / "out"
CACHE_ROOT: Path = PROJECT_ROOT / "tools" / "map_importer" / ".cache"


def map_godot_output_dir(map_id: str) -> Path:
    return OUTPUT_MAPS_ROOT / map_id


def map_res_path(p: Path) -> str:
    """Convert filesystem path to ``res://...`` relative to project root."""
    rel = p.resolve().relative_to(PROJECT_ROOT)
    return "res://" + rel.as_posix()


# --------------------------------------------------------------------------- tileset
# TileSet metadata (shared across all maps, see design §C.3)
TILESET_META = {
    "tile_shape": 1,           # TileSet.TILE_SHAPE_ISOMETRIC
    # TILE_LAYOUT_DIAMOND_DOWN = 5: rotates grid 45° so (0,0) is on top,
    # (max,0) on right, (0,max) on left, (max,max) on bottom — matches the
    # way Unity's isometric scenes are composited (see §C.3 in design doc).
    "tile_layout": 5,
    "tile_offset_axis": 0,     # TILE_OFFSET_AXIS_HORIZONTAL
    "tile_size": (66, 43),     # iso diamond bounding box (ground tile footprint)
}

# 6 custom data layers (see design §C.3 table)
CUSTOM_DATA_LAYERS = [
    ("tile_id",        4),  # TYPE_STRING
    ("source_texture", 4),
    ("layer_role",     4),
    ("walkable",       1),  # TYPE_BOOL
    ("terrain_type",   4),
    ("height_level",   2),  # TYPE_INT
]

# --------------------------------------------------------------------------- atlas
# Footprint buckets (design §C.2)
# Each bucket has a fixed cell size; sprites get padded / top-left aligned into it.
FOOTPRINT_BUCKETS = {
    "ground_66x43": (66, 43),
    "wall_66x36":   (66, 36),
    "block_62x32":  (62, 32),
    "tall_76x128":  (76, 128),
}

# Maximum columns per atlas PNG before spilling into the next file.
ATLAS_MAX_COLS = 64

# Placeholder sprite size (for spr_* strategy 2)
PLACEHOLDER_SIZE = (48, 48)
PLACEHOLDER_COLOR = (255, 105, 180, 255)  # hot pink, obvious

# --------------------------------------------------------------------------- layer routing (design §D.1)
# Source Unity layer name -> Godot layer slot
LAYER_ROUTE = {
    # ground
    "Ground0": "GroundBaseLayer",
    "Ground1": "GroundDetailLayer",
    "Ground2": "GroundDetailLayer",
    "Ground3": "GroundDetailLayer",
    "Ground4": "GroundDetailLayer",
    "Ground5": "GroundDetailLayer",
    "Ground6": "GroundDetailLayer",
    "Ground7": "GroundDetailLayer",
    "Ground8": "GroundDetailLayer",
    # obstacles
    "Wall": "ObstacleLayer",
    "WallCorner": "ObstacleLayer",   # WHITELIST can move to DecorationLayer
    "WallThing": "ObstacleLayer",
    # roof overlay
    "TopRoof": "RoofOverlayLayer",
    # decoration / prop
    "BuildingStatic": "DecorationLayer",
    # debug
    "_Block": "DebugBlockLayer",
    "_ShaftWay": "DebugBlockLayer",
}

GODOT_LAYER_ORDER = [
    "GroundBaseLayer",
    "GroundDetailLayer",
    "ObstacleLayer",
    "DecorationLayer",
    "RoofOverlayLayer",
    "DebugBlockLayer",
]

GODOT_LAYER_Z = {
    "GroundBaseLayer":   -10,
    "GroundDetailLayer": -5,
    "ObstacleLayer":     0,
    "DecorationLayer":   0,
    "RoofOverlayLayer":  20,
    "DebugBlockLayer":   50,
}

# Which layers are children of YSortRoot (design §D.2)
YSORT_LAYERS = {"ObstacleLayer", "DecorationLayer"}

# Which layers default visible
LAYER_VISIBLE_DEFAULT = {
    "GroundBaseLayer":   True,
    "GroundDetailLayer": True,
    "ObstacleLayer":     True,
    "DecorationLayer":   True,
    "RoofOverlayLayer":  True,
    "DebugBlockLayer":   False,
}

# --------------------------------------------------------------------------- layer roles (for custom_data layer_role)
LAYER_ROLE = {
    "Ground0": "ground",
    "Ground1": "ground",
    "Ground2": "ground",
    "Ground3": "ground",
    "Ground4": "ground",
    "Ground5": "ground",
    "Ground6": "ground",
    "Ground7": "ground",
    "Ground8": "ground",
    "Wall": "wall",
    "WallCorner": "wall",
    "WallThing": "wall",
    "TopRoof": "roof",
    "BuildingStatic": "deco",
    "_Block": "block",
    "_ShaftWay": "block",
}

# --------------------------------------------------------------------------- walkable extraction (design §E.1)
GROUND_LAYERS = [
    "Ground0", "Ground1", "Ground2", "Ground3",
    "Ground4", "Ground5", "Ground6", "Ground7", "Ground8",
]
BLOCK_LAYERS = ["_Block"]
WALL_LAYERS = ["Wall"]
WALLCORNER_LAYERS = ["WallCorner"]
WALLTHING_LAYERS = ["WallThing"]
SHAFTWAY_LAYERS = ["_ShaftWay"]

# Per-sprite name whitelist — only applies to WallCorner / WallThing (see design §H.2).
# Initial version: empty (conservative). Can be populated after manual review of report.md.
WALKABLE_WHITELIST: set[str] = set()

# --------------------------------------------------------------------------- spr_* strategy (design §H.1)
# Layers where spr_* is dropped (skip set_cell, keep geometry only in walkable calc)
SPR_STRATEGY_SKIP = {"TopRoof"}
# Layers where spr_* becomes a pink placeholder — used for all other layers.


# --------------------------------------------------------------------------- composite compare
COMPOSITE_BBOX_TOLERANCE_PX = 20
