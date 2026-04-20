extends Node2D

signal interaction_available(npc: Node)
signal interaction_unavailable(npc: Node)

@export var npc_id: String = ""

@onready var sprite: Sprite2D = get_node("Sprite2D")
@onready var interaction_area: Area2D = get_node("InteractionArea")
@onready var prompt_label: Label = get_node("PromptLabel")

var npc_data: NPCData = null
var _player_inside: bool = false
var _can_interact: bool = true


func _ready() -> void:
	add_to_group("npc_node")
	npc_data = NPCRegistry.get_data(npc_id)
	if npc_data == null:
		push_warning("[NPCNode] Missing NPC data: %s" % npc_id)
		visible = false
		return

	if npc_data.overworld_texture != null:
		sprite.texture = npc_data.overworld_texture
	elif npc_data.sprite_frames != null and npc_data.sprite_frames.has_animation("idle"):
		sprite.texture = npc_data.sprite_frames.get_frame_texture("idle", 0)
	sprite.modulate = npc_data.modulate

	prompt_label.visible = false
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	interaction_area.input_event.connect(_on_input_event)
	if not DialogueSystem.dialogue_started.is_connected(_on_dialogue_started):
		DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	if not DialogueSystem.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)


func interact() -> bool:
	if not _player_inside or not _can_interact or npc_data == null:
		return false
	var dialogue_id := _resolve_dialogue_id()
	if dialogue_id.is_empty():
		return false
	var started: bool = DialogueSystem.start(dialogue_id)
	if started:
		_can_interact = false
		prompt_label.visible = false
	return started


func _resolve_dialogue_id() -> String:
	if npc_data == null:
		return ""
	for entry in npc_data.conditional_dialogues:
		if not (entry is Dictionary):
			continue
		var required_flags: Array[String] = Array(entry.get("required_flags", []), TYPE_STRING, "", null)
		var forbidden_flags: Array[String] = Array(entry.get("forbidden_flags", []), TYPE_STRING, "", null)
		if not _has_required_flags(required_flags):
			continue
		if not _has_no_forbidden_flags(forbidden_flags):
			continue
		var dialogue_id := String(entry.get("dialogue_id", ""))
		if not dialogue_id.is_empty():
			return dialogue_id
	return npc_data.default_dialogue_id


func _has_required_flags(flags: Array[String]) -> bool:
	for flag in flags:
		if not bool(GameState.get_flag(flag, false)):
			return false
	return true


func _has_no_forbidden_flags(flags: Array[String]) -> bool:
	for flag in flags:
		if bool(GameState.get_flag(flag, false)):
			return false
	return true


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_interaction_area"):
		return
	_player_inside = true
	prompt_label.visible = _can_interact
	interaction_available.emit(self)


func _on_area_exited(area: Area2D) -> void:
	if not area.is_in_group("player_interaction_area"):
		return
	_player_inside = false
	prompt_label.visible = false
	interaction_unavailable.emit(self)


func _on_dialogue_started(_dialogue_id: String) -> void:
	_can_interact = false
	prompt_label.visible = false


func _on_dialogue_ended(_dialogue_id: String) -> void:
	_can_interact = true
	prompt_label.visible = _player_inside


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			interact()
