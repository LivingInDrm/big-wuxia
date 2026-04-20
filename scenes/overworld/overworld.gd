extends Node2D

const DEFAULT_SPAWN := Vector2(520, 720)

@onready var player: CharacterBody2D = get_node("Player")
@onready var camera: Camera2D = get_node("Camera2D")
@onready var poi_name_label: Label = get_node("UILayer/PoiNameLabel")
@onready var interaction_hint_frame: Control = get_node("UILayer/InteractionHintFrame")
@onready var interaction_hint_label: Label = get_node("UILayer/InteractionHintFrame/InteractionHintLabel")

var _current_poi_id: String = ""


func _ready() -> void:
	GameState.location = "overworld"
	interaction_hint_frame.visible = false
	poi_name_label.visible = false
	_restore_player_position()
	camera.position_smoothing_enabled = true
	camera.enabled = true

	for marker in get_node("POINodes").get_children():
		if marker.has_method("refresh_visibility"):
			marker.refresh_visibility()
		if marker.has_signal("player_entered"):
			marker.player_entered.connect(_on_poi_player_entered)
		if marker.has_signal("player_exited"):
			marker.player_exited.connect(_on_poi_player_exited)


func _process(_delta: float) -> void:
	if camera != null and player != null:
		camera.global_position = player.global_position


func _unhandled_input(event: InputEvent) -> void:
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
	poi_name_label.text = poi_data.display_name
	poi_name_label.visible = true
	interaction_hint_label.text = "按 E / 点击进入 %s" % poi_data.display_name
	interaction_hint_frame.visible = true


func _on_poi_player_exited(poi_id: String) -> void:
	if _current_poi_id != poi_id:
		return
	_current_poi_id = ""
	poi_name_label.visible = false
	interaction_hint_frame.visible = false
