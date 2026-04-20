extends Node2D

const DEFAULT_SPAWN := Vector2(520, 720)
const POI_NAME_SHOW_DISTANCE := 150.0
const POI_NAME_FADE_DURATION := 0.2
const ReturnToMenuHelper = preload("res://scripts/ui/return_to_menu_helper.gd")

@onready var player: CharacterBody2D = get_node("Player")
@onready var camera: Camera2D = get_node("Camera2D")
@onready var poi_name_label: Label = get_node("UILayer/PoiNameLabel")
@onready var interaction_hint_frame: Control = get_node("UILayer/InteractionHintFrame")
@onready var interaction_hint_label: Label = get_node("UILayer/InteractionHintFrame/InteractionHintLabel")

var _current_poi_id: String = ""
var _poi_markers: Array[Node] = []


func _ready() -> void:
	GameState.location = "overworld"
	interaction_hint_frame.visible = false
	poi_name_label.visible = false
	poi_name_label.modulate.a = 0.0
	_restore_player_position()
	camera.position_smoothing_enabled = true
	camera.enabled = true

	_poi_markers.clear()
	for marker in get_node("POINodes").get_children():
		_poi_markers.append(marker)
		if marker.has_method("refresh_visibility"):
			marker.refresh_visibility()
		if marker.has_signal("player_entered"):
			marker.player_entered.connect(_on_poi_player_entered)
		if marker.has_signal("player_exited"):
			marker.player_exited.connect(_on_poi_player_exited)


func _process(delta: float) -> void:
	if camera != null and player != null:
		camera.global_position = player.global_position
	_update_poi_name_label(delta)


func _unhandled_input(event: InputEvent) -> void:
	if ReturnToMenuHelper.is_open(get_tree()):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if ReturnToMenuHelper.request(get_tree()):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _try_enter_current_poi():
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _current_poi_id != "":
			if _try_enter_current_poi():
				get_viewport().set_input_as_handled()


func _restore_player_position() -> void:
	var return_context: Dictionary = GameState.return_context.duplicate(true)
	var target_position: Vector2 = GameState.overworld_player_position if GameState.overworld_player_position != Vector2.ZERO else DEFAULT_SPAWN

	if bool(return_context.get("from_poi", false)):
		var poi_id: String = String(return_context.get("poi_id", ""))
		var poi_data: POIData = POIRegistry.get_data(poi_id)
		if poi_data != null:
			target_position = poi_data.position_on_overworld + poi_data.overworld_return_offset
		GameState.return_context = {}

	player.global_position = target_position


func _try_enter_current_poi() -> bool:
	if _current_poi_id.is_empty():
		return false
	var poi_data: POIData = POIRegistry.get_data(_current_poi_id)
	if poi_data == null or poi_data.scene_path.is_empty():
		return false
	GameState.overworld_player_position = player.global_position
	GameState.location = "poi:%s" % _current_poi_id
	SceneManager.change_scene_to_file(poi_data.scene_path)
	return true


func _on_poi_player_entered(poi_id: String) -> void:
	var poi_data: POIData = POIRegistry.get_data(poi_id)
	if poi_data == null:
		return
	_current_poi_id = poi_id
	interaction_hint_label.text = "按 E / 点击进入 %s" % poi_data.display_name
	interaction_hint_frame.visible = true


func _on_poi_player_exited(poi_id: String) -> void:
	if _current_poi_id != poi_id:
		return
	_current_poi_id = ""
	interaction_hint_frame.visible = false


func _update_poi_name_label(delta: float) -> void:
	if player == null:
		return

	var nearest_name := ""
	var nearest_distance := INF
	for marker in _poi_markers:
		if marker == null or not is_instance_valid(marker) or not marker.visible:
			continue
		var distance := player.global_position.distance_to(marker.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			var poi_id = marker.get("poi_id")
			var poi_data: POIData = POIRegistry.get_data(String(poi_id))
			if poi_data != null:
				nearest_name = poi_data.display_name

	var should_show := nearest_distance < POI_NAME_SHOW_DISTANCE and not nearest_name.is_empty()
	if should_show:
		poi_name_label.text = nearest_name

	var fade_step := delta / POI_NAME_FADE_DURATION
	poi_name_label.modulate.a = move_toward(poi_name_label.modulate.a, 1.0 if should_show else 0.0, fade_step)
	poi_name_label.visible = should_show or poi_name_label.modulate.a > 0.01
