extends Resource
class_name POIData

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""

@export_group("Overworld")
@export var position_on_overworld: Vector2 = Vector2.ZERO
@export_file("*.tscn") var scene_path: String = ""
@export var marker_sprite: Texture2D
@export var marker_label_offset: Vector2 = Vector2.ZERO
@export var required_flags: Array[String] = []
@export var initial_visible: bool = true
@export var entry_spawn_point: String = ""
@export var overworld_return_offset: Vector2 = Vector2.ZERO
