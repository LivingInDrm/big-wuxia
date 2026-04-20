extends Node2D

const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"
const ReturnToMenuHelper = preload("res://scripts/ui/return_to_menu_helper.gd")

@export var poi_id: String = ""

@onready var player: CharacterBody2D = get_node("Player")
@onready var entry_spawn: Marker2D = get_node("EntrySpawn")
@onready var exit_area: Area2D = get_node("ExitArea")
@onready var exit_hint_frame: Control = get_node("UILayer/ExitHintFrame")
@onready var exit_hint_label: Label = get_node("UILayer/ExitHintFrame/ExitHintLabel")

var _player_near_exit: bool = false
var _current_npc: Node = null
var _pending_dialogue_id: String = ""


func _ready() -> void:
	GameState.location = "poi:%s" % poi_id
	exit_hint_frame.visible = false
	exit_hint_label.text = "按 E / 点击返回大地图"

	var resume_context: Dictionary = GameState.return_context.duplicate(true)
	if bool(resume_context.get("from_battle", false)) and String(resume_context.get("return_to_poi", "")) == poi_id:
		_restore_from_battle_context(resume_context)
	elif resume_context.get("target_poi", "") == poi_id and resume_context.has("player_position_in_poi"):
		player.global_position = resume_context["player_position_in_poi"]
	else:
		player.global_position = _resolve_entry_spawn(resume_context).global_position

	player.interactable_area_entered.connect(_on_player_interactable_entered)
	player.interactable_area_exited.connect(_on_player_interactable_exited)
	exit_area.area_entered.connect(_on_exit_area_entered)
	exit_area.area_exited.connect(_on_exit_area_exited)

	for npc in get_node("NPCNodes").get_children():
		npc.interaction_available.connect(_on_npc_interaction_available)
		npc.interaction_unavailable.connect(_on_npc_interaction_unavailable)

	if not _pending_dialogue_id.is_empty():
		call_deferred("_start_pending_dialogue")


func _unhandled_input(event: InputEvent) -> void:
	if ReturnToMenuHelper.is_open(get_tree()):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if ReturnToMenuHelper.request(get_tree()):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _current_npc != null and _current_npc.interact():
			get_viewport().set_input_as_handled()
			return
		if _player_near_exit:
			_return_to_overworld()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _player_near_exit:
			_return_to_overworld()
			get_viewport().set_input_as_handled()


func _return_to_overworld() -> void:
	GameState.return_context = {
		"from_poi": true,
		"poi_id": poi_id,
		"player_position_in_poi": player.global_position,
	}
	GameState.location = "overworld"
	SceneManager.change_scene_to_file(OVERWORLD_SCENE)


func _restore_from_battle_context(resume_context: Dictionary) -> void:
	player.global_position = _resolve_entry_spawn(resume_context).global_position
	var result := String(resume_context.get("battle_result", ""))
	if result == "victory":
		_pending_dialogue_id = String(resume_context.get("on_victory_dialogue", ""))
	elif result == "defeat":
		_pending_dialogue_id = String(resume_context.get("on_defeat_dialogue", ""))
	GameState.return_context = {}


func _resolve_entry_spawn(resume_context: Dictionary) -> Marker2D:
	var spawn_name := String(resume_context.get("entry_spawn_name", "EntrySpawn"))
	var marker := get_node_or_null(spawn_name) as Marker2D
	return marker if marker != null else entry_spawn


func _start_pending_dialogue() -> void:
	var dialogue_id := _pending_dialogue_id
	_pending_dialogue_id = ""
	if dialogue_id.is_empty():
		return
	DialogueSystem.start(dialogue_id)


func _on_exit_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_interaction_area"):
		return
	_player_near_exit = true
	exit_hint_frame.visible = true


func _on_exit_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_interaction_area"):
		return
	_player_near_exit = false
	exit_hint_frame.visible = false


func _on_npc_interaction_available(npc: Node) -> void:
	_current_npc = npc


func _on_npc_interaction_unavailable(npc: Node) -> void:
	if _current_npc == npc:
		_current_npc = null


func _on_player_interactable_entered(_area: Area2D) -> void:
	pass


func _on_player_interactable_exited(_area: Area2D) -> void:
	pass
