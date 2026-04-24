extends Resource
class_name LevelData

@export_group("Identity")
@export var level_id: String = ""
@export var level_name: String = ""

@export_group("Map")
## Legacy list of walkable cells. Kept for backward compatibility with
## level_01 / level_02. New-style imported maps use walkable_cells instead.
@export var map_layout: PackedVector2Array = PackedVector2Array()
## Unique map identifier such as "Map_10020". Empty for legacy levels.
@export var map_id: String = ""
## Non-negative (Godot-space) walkable cells from the offline importer.
@export var walkable_cells: PackedVector2Array = PackedVector2Array()
## Non-negative (Godot-space) blocked cells (walls / WallCorner / WallThing / _Block).
@export var blocked_cells: PackedVector2Array = PackedVector2Array()
## Per-cell terrain string. Keyed by Vector2i, values like "grass" / "water".
@export var terrain_by_cell: Dictionary = {}
## Pre-built battle map .tscn (from the offline importer). When null the
## battle controller falls back to the legacy map_layout path.
@export var map_scene: PackedScene = null
## Offset applied by the importer when normalizing Unity cells to Godot-space
## (cell = unity_cell - render_origin). Useful for debugging only.
@export var render_origin: Vector2i = Vector2i.ZERO

@export_group("Units")
@export var player_units: Array[Dictionary] = []
@export var enemy_units: Array[Dictionary] = []

@export_group("Objectives")
@export var victory_condition: String = "kill_all"
@export var boss_id: String = ""

@export_group("Rewards")
@export var rewards: Array[Dictionary] = []


## Derive a usable walkable set when only the legacy map_layout is provided.
## Returns the same PackedVector2Array for new-style levels, or a copy of
## map_layout for legacy ones.
func ensure_map_layout() -> PackedVector2Array:
	if walkable_cells.size() > 0:
		return walkable_cells
	return map_layout
