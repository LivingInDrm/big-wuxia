extends Node2D

signal player_entered(poi_id: String)
signal player_exited(poi_id: String)

@export var poi_id: String = ""

@onready var sprite: Sprite2D = get_node("Sprite2D")
@onready var interaction_area: Area2D = get_node("InteractionArea")

var poi_data: POIData = null
var _player_inside: bool = false
var _hovered: bool = false


func _ready() -> void:
	poi_data = POIRegistry.get_data(poi_id)
	if poi_data == null:
		push_warning("[POIMarker] Missing POI data: %s" % poi_id)
		visible = false
		return

	position = poi_data.position_on_overworld
	sprite.texture = poi_data.marker_sprite
	visible = _is_unlocked()
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	interaction_area.mouse_entered.connect(_on_mouse_entered)
	interaction_area.mouse_exited.connect(_on_mouse_exited)
	_apply_hover_visual()


func refresh_visibility() -> void:
	visible = _is_unlocked()
	if not visible:
		_player_inside = false
		_hovered = false
	_apply_hover_visual()


func is_player_inside() -> bool:
	return _player_inside and visible


func _is_unlocked() -> bool:
	if poi_data == null:
		return false
	if not poi_data.initial_visible and poi_data.unlock_flag.is_empty() and poi_data.required_flags.is_empty():
		return false
	if not poi_data.unlock_flag.is_empty() and not bool(GameState.get_flag(poi_data.unlock_flag, false)):
		return false
	for flag in poi_data.required_flags:
		if not bool(GameState.get_flag(flag, false)):
			return false
	return true


func _on_area_entered(area: Area2D) -> void:
	if not visible or not area.is_in_group("player_interaction_area"):
		return
	_player_inside = true
	player_entered.emit(poi_id)


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_interaction_area"):
		return
	_player_inside = false
	player_exited.emit(poi_id)


func _on_mouse_entered() -> void:
	_hovered = true
	_apply_hover_visual()


func _on_mouse_exited() -> void:
	_hovered = false
	_apply_hover_visual()


func _apply_hover_visual() -> void:
	if sprite == null:
		return
	sprite.scale = Vector2.ONE * (1.1 if _hovered and visible else 1.0)
	sprite.modulate = Color(1.0, 0.95, 0.78, 1.0) if _hovered and visible else Color.WHITE
