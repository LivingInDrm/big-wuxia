extends Node

const DialogueAction = preload("res://scripts/core/dialogue_action.gd")
const DialogueBox = preload("res://scenes/dialogue/dialogue_box.gd")
const DialogueChoice = preload("res://scripts/core/dialogue_choice.gd")
const DialogueData = preload("res://scripts/core/dialogue_data.gd")
const DialogueNode = preload("res://scripts/core/dialogue_node.gd")
const DialogueBoxScene = preload("res://scenes/dialogue/dialogue_box.tscn")
const NPCData = preload("res://scripts/core/npc_data.gd")
const ReturnToMenuHelper = preload("res://scripts/ui/return_to_menu_helper.gd")
const UnitData = preload("res://scripts/core/unit_data.gd")
const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const DEFAULT_PORTRAIT_PATH := "res://resources/ui/portraits/_default.png"

signal dialogue_started(id: String)
signal dialogue_ended(id: String)
signal node_changed(node: DialogueNode)
signal action_executed(action: DialogueAction)

var char_speed: int = 25
var instant_mode: bool = false
var current_dialogue_id: String = ""
var current_dialogue: DialogueData = null
var current_node: DialogueNode = null

var _dialogue_box: DialogueBox = null
var _node_lookup: Dictionary = {}
var _visible_choices: Array[DialogueChoice] = []
var _typing_elapsed_ms: float = 0.0
var _visible_characters: int = 0
var _text_fully_visible: bool = true
var _is_transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_unhandled_input(true)
	var settings_bootstrap := get_node_or_null("/root/SettingsBootstrap")
	if settings_bootstrap != null:
		_apply_char_speed_from_settings(settings_bootstrap.get_dialogue_char_speed())
		if not settings_bootstrap.settings_changed.is_connected(_on_settings_changed):
			settings_bootstrap.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	if current_node == null or _dialogue_box == null or _text_fully_visible:
		return

	var total_characters: int = int(_dialogue_box.get_total_character_count())
	if total_characters <= 0:
		_complete_text_reveal()
		return
	if _is_instant_mode():
		_complete_text_reveal()
		return

	_typing_elapsed_ms += delta * 1000.0
	while _typing_elapsed_ms >= float(char_speed) and _visible_characters < total_characters:
		_typing_elapsed_ms -= float(char_speed)
		_visible_characters += 1
		_dialogue_box.set_visible_characters(_visible_characters)

	if _visible_characters >= total_characters:
		_complete_text_reveal()


func _unhandled_input(event: InputEvent) -> void:
	if current_node == null or _dialogue_box == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			if not ReturnToMenuHelper.is_open(get_tree()) and ReturnToMenuHelper.request(get_tree()):
				get_viewport().set_input_as_handled()
			return
		if ReturnToMenuHelper.is_open(get_tree()):
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			if _handle_advance_input():
				get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _handle_advance_input():
			get_viewport().set_input_as_handled()


func start(dialogue_id: String) -> bool:
	var resolved_id := _resolve_dialogue_id(dialogue_id)
	if resolved_id.is_empty():
		push_warning("[DialogueSystem] Missing dialogue id: %s" % dialogue_id)
		return false

	end(false)

	current_dialogue_id = resolved_id
	current_dialogue = DialogueRegistry.get_data(resolved_id)
	if current_dialogue == null:
		push_warning("[DialogueSystem] Dialogue data not found: %s" % resolved_id)
		current_dialogue_id = ""
		return false

	_rebuild_node_lookup(current_dialogue)
	_ensure_dialogue_box()
	dialogue_started.emit(current_dialogue_id)
	_go_to_node(current_dialogue.entry_node_id, false)
	return current_node != null


func advance() -> void:
	if current_node == null or _is_transitioning:
		return
	if not _text_fully_visible:
		_reveal_text_immediately()
		return
	if not _visible_choices.is_empty():
		return

	_execute_actions(current_node.on_exit_actions)
	if current_node == null:
		return
	if current_node.next_node_id.is_empty():
		end()
		return
	_go_to_node(current_node.next_node_id, false)


func select_choice(index: int) -> void:
	if current_node == null or _is_transitioning:
		return
	if index < 0 or index >= _visible_choices.size():
		push_warning("[DialogueSystem] choice index out of bounds: %d" % index)
		return
	if not _text_fully_visible:
		_reveal_text_immediately()
		return

	var choice := _visible_choices[index]
	_execute_actions(current_node.on_exit_actions)
	if current_node == null:
		return
	_execute_actions(choice.actions)
	if current_node == null:
		return
	if choice.next_node_id.is_empty():
		end()
		return
	_go_to_node(choice.next_node_id, false)


func end(play_animation: bool = true) -> void:
	var ended_id := current_dialogue_id
	current_dialogue_id = ""
	current_dialogue = null
	current_node = null
	_node_lookup.clear()
	_visible_choices.clear()
	_typing_elapsed_ms = 0.0
	_visible_characters = 0
	_text_fully_visible = true

	if _dialogue_box != null:
		_dialogue_box.cancel_fade()
		_dialogue_box.set_choices([])
		_dialogue_box.show_continue_indicator(false)
		if play_animation and is_instance_valid(_dialogue_box):
			_dialogue_box.play_hide()
			await get_tree().create_timer(0.2).timeout
		if is_instance_valid(_dialogue_box):
			_dialogue_box.queue_free()
		_dialogue_box = null

	if not ended_id.is_empty():
		dialogue_ended.emit(ended_id)


func _ensure_dialogue_box() -> void:
	if _dialogue_box != null and is_instance_valid(_dialogue_box):
		return
	_dialogue_box = DialogueBoxScene.instantiate() as DialogueBox
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.advance_requested.connect(_on_box_advance_requested)
	_dialogue_box.choice_selected.connect(_on_box_choice_selected)
	_dialogue_box.play_show()


func _rebuild_node_lookup(dialogue: DialogueData) -> void:
	_node_lookup.clear()
	for node in dialogue.nodes:
		if node == null:
			continue
		_node_lookup[node.node_id] = node


func _go_to_node(node_id: String, allow_current_choice_fallback: bool) -> void:
	var resolved_node := _resolve_reachable_node(node_id, allow_current_choice_fallback)
	if resolved_node == null:
		end()
		return

	current_node = resolved_node
	_visible_choices = _filter_choices(current_node.choices)
	_execute_actions(current_node.on_enter_actions)
	_refresh_box_for_current_node()
	node_changed.emit(current_node)


func _resolve_reachable_node(node_id: String, allow_current_choice_fallback: bool) -> DialogueNode:
	var visited: Dictionary = {}
	var pending_id := node_id

	while not pending_id.is_empty():
		if visited.has(pending_id):
			push_warning("[DialogueSystem] dialogue loop while resolving node: %s" % pending_id)
			return null
		visited[pending_id] = true

		var candidate := _node_lookup.get(pending_id) as DialogueNode
		if candidate == null:
			push_warning("[DialogueSystem] missing node: %s" % pending_id)
			return null
		if _is_node_available(candidate):
			return candidate

		var next_from_choice := ""
		if allow_current_choice_fallback:
			var filtered := _filter_choices(candidate.choices)
			if not filtered.is_empty():
				next_from_choice = filtered[0].next_node_id
			allow_current_choice_fallback = false
		else:
			var fallback_choices := _filter_choices(candidate.choices)
			if not fallback_choices.is_empty():
				next_from_choice = fallback_choices[0].next_node_id

		pending_id = next_from_choice if not next_from_choice.is_empty() else candidate.next_node_id

	return null


func _is_node_available(node: DialogueNode) -> bool:
	return _has_required_flags(node.required_flags) and _has_no_forbidden_flags(node.forbidden_flags)


func _filter_choices(choices: Array[DialogueChoice]) -> Array[DialogueChoice]:
	var filtered: Array[DialogueChoice] = []
	for choice in choices:
		if choice == null:
			continue
		if not _has_required_flags(choice.required_flags):
			continue
		if not _has_no_forbidden_flags(choice.forbidden_flags):
			continue
		filtered.append(choice)
	return filtered


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


func _refresh_box_for_current_node() -> void:
	if _dialogue_box == null or current_node == null:
		return

	_dialogue_box.set_speaker(_resolve_speaker_name(current_node), _resolve_portrait(current_node))
	_dialogue_box.set_dialogue_text(current_node.text)
	_visible_characters = 0
	_typing_elapsed_ms = 0.0

	var total_characters: int = int(_dialogue_box.get_total_character_count())
	if total_characters <= 0 or _is_instant_mode():
		_complete_text_reveal()
	else:
		_text_fully_visible = false
		_dialogue_box.set_visible_characters(0)
		_dialogue_box.show_continue_indicator(false)
		_dialogue_box.set_choices([])


func _complete_text_reveal() -> void:
	_text_fully_visible = true
	_visible_characters = _dialogue_box.get_total_character_count()
	_dialogue_box.reveal_all_text()
	if _visible_choices.is_empty():
		_dialogue_box.set_choices([])
		_dialogue_box.show_continue_indicator(true)
	else:
		var labels: Array[String] = []
		for choice in _visible_choices:
			labels.append(choice.text)
		_dialogue_box.set_choices(labels)
		_dialogue_box.show_continue_indicator(false)


func _reveal_text_immediately() -> void:
	_typing_elapsed_ms = 0.0
	_complete_text_reveal()


func _handle_advance_input() -> bool:
	if current_node == null:
		return false
	if not _text_fully_visible:
		_reveal_text_immediately()
		return true
	if not _visible_choices.is_empty():
		return false
	advance()
	return true


func _execute_actions(actions: Array[DialogueAction]) -> void:
	for action in actions:
		if action == null:
			continue
		_execute_action(action)


func _execute_action(action: DialogueAction) -> void:
	var payload: Dictionary = action.payload
	match action.type:
		"set_flag":
			var flag_key := String(payload.get("key", payload.get("flag", "")))
			if not flag_key.is_empty():
				GameState.set_flag(flag_key, payload.get("value", true))
		"give_item":
			var item_id := String(payload.get("id", payload.get("item_id", "")))
			var count: int = max(1, int(payload.get("count", 1)))
			if not item_id.is_empty():
				GameState.inventory.add(item_id, count)
		"give_equipment":
			var equipment_id := String(payload.get("id", payload.get("item_id", "")))
			if not equipment_id.is_empty():
				GameState.inventory.add(equipment_id, 1)
		"unlock_poi":
			var unlock_flag := String(payload.get("flag", ""))
			if unlock_flag.is_empty():
				var poi_id := String(payload.get("poi_id", payload.get("id", "")))
				if not poi_id.is_empty():
					unlock_flag = "poi.%s.unlocked" % poi_id
			if not unlock_flag.is_empty():
				GameState.set_flag(unlock_flag, true)
		"start_battle":
			var level_id := String(payload.get("level_id", payload.get("level", "")))
			var return_context := {
				"level_id": level_id,
				"return_to_poi": String(payload.get("return_to_poi", "")),
				"on_victory_dialogue": String(payload.get("on_victory_dialogue", "")),
				"on_defeat_dialogue": String(payload.get("on_defeat_dialogue", "")),
				"allow_retry": bool(payload.get("allow_retry", false)),
			}
			var poi_id := String(payload.get("return_to_poi", ""))
			if not poi_id.is_empty():
				var poi_data: POIData = POIRegistry.get_data(poi_id)
				if poi_data != null:
					return_context["return_scene"] = poi_data.scene_path
					return_context["entry_spawn_name"] = poi_data.entry_spawn_point
			GameState.begin_battle_from(return_context)
			end(false)
			SceneManager.change_scene_to_file(BATTLE_SCENE_PATH)
		"play_sfx":
			print("[SFX] %s" % String(payload.get("name", payload.get("path", ""))))
		"end_dialogue":
			end()
		_:
			push_warning("[DialogueSystem] Unsupported action type: %s" % action.type)
	action_executed.emit(action)


func _resolve_dialogue_id(requested: String) -> String:
	if DialogueRegistry.has(requested):
		return requested
	var alias := ""
	var separator_index: int = requested.find("_")
	if separator_index >= 0:
		alias = "%s.%s" % [requested.substr(0, separator_index), requested.substr(separator_index + 1)]
	if DialogueRegistry.has(alias):
		return alias
	return ""


func _resolve_speaker_name(node: DialogueNode) -> String:
	if not node.speaker_name_override.is_empty():
		return node.speaker_name_override
	if node.speaker_id.is_empty():
		return ""

	var npc: NPCData = NPCRegistry.get_data(node.speaker_id)
	if npc != null and not npc.display_name.is_empty():
		return npc.display_name
	var unit: UnitData = UnitRegistry.get_data(node.speaker_id)
	if unit != null and not unit.unit_name.is_empty():
		return unit.unit_name
	return node.speaker_id


func _resolve_portrait(node: DialogueNode) -> Texture2D:
	var portrait_path := ""
	var portrait_value = node.get("portrait_path")
	if portrait_value != null:
		portrait_path = String(portrait_value)
	if portrait_path.is_empty() and not node.speaker_id.is_empty():
		portrait_path = "res://resources/ui/portraits/%s.png" % node.speaker_id
	if not portrait_path.is_empty():
		var portrait := _load_texture_from_file(portrait_path)
		if portrait != null:
			return portrait
	return _load_texture_from_file(DEFAULT_PORTRAIT_PATH)


func _on_box_advance_requested() -> void:
	if _visible_choices.is_empty():
		advance()


func _on_box_choice_selected(index: int) -> void:
	select_choice(index)


func _load_texture_from_file(path: String) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.new()
	var err := image.load(absolute_path)
	if err == OK:
		return ImageTexture.create_from_image(image)
	return null


func _apply_char_speed_from_settings(new_char_speed: int) -> void:
	char_speed = max(new_char_speed, 0)
	instant_mode = char_speed <= 0


func _is_instant_mode() -> bool:
	return instant_mode or char_speed <= 0


func _on_settings_changed(_window_size: Vector2i, _fullscreen: bool, dialogue_char_speed: int) -> void:
	_apply_char_speed_from_settings(dialogue_char_speed)
