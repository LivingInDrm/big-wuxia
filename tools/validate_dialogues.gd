extends SceneTree

const DialogueAction = preload("res://scripts/core/dialogue_action.gd")
const DialogueChoice = preload("res://scripts/core/dialogue_choice.gd")
const DialogueData = preload("res://scripts/core/dialogue_data.gd")
const DialogueNode = preload("res://scripts/core/dialogue_node.gd")

const PLACEHOLDER_SPEAKERS := {
	"narrator": true,
}
const KNOWN_ACTION_TYPES := {
	"set_flag": true,
	"give_item": true,
	"give_equipment": true,
	"unlock_poi": true,
	"start_battle": true,
	"play_sfx": true,
	"end_dialogue": true,
}

var _dialogue_count: int = 0
var _node_count: int = 0
var _warning_count: int = 0
var _error_count: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dialogue_registry := root.get_node_or_null("DialogueRegistry")
	var item_registry := root.get_node_or_null("ItemRegistry")
	var npc_registry := root.get_node_or_null("NPCRegistry")
	var unit_registry := root.get_node_or_null("UnitRegistry")

	if dialogue_registry == null or item_registry == null or npc_registry == null or unit_registry == null:
		if dialogue_registry == null:
			_error("missing autoload: DialogueRegistry")
		if item_registry == null:
			_error("missing autoload: ItemRegistry")
		if npc_registry == null:
			_error("missing autoload: NPCRegistry")
		if unit_registry == null:
			_error("missing autoload: UnitRegistry")
		_finish()
		return

	dialogue_registry.reload()
	item_registry.reload()
	npc_registry.reload()
	unit_registry.reload()

	for dialogue_id in dialogue_registry.all_ids():
		var dialogue := dialogue_registry.get_data(dialogue_id) as DialogueData
		if dialogue == null:
			_error("%s: registry returned null dialogue" % dialogue_id)
			continue
		_validate_dialogue(dialogue, item_registry, npc_registry, unit_registry)

	_finish()


func _validate_dialogue(
	dialogue: DialogueData,
	item_registry: Node,
	npc_registry: Node,
	unit_registry: Node
) -> void:
	_dialogue_count += 1
	var node_lookup: Dictionary = {}

	for node in dialogue.nodes:
		if node == null:
			_warning("%s: contains null node entry" % dialogue.id)
			continue
		var node_id := String(node.node_id)
		if node_id.is_empty():
			_error("%s: contains node with empty node_id" % dialogue.id)
			continue
		if node_lookup.has(node_id):
			_error("%s.%s: duplicate node_id" % [dialogue.id, node_id])
			continue
		node_lookup[node_id] = node

	if not node_lookup.has(dialogue.entry_node_id):
		_error("%s: missing entry node '%s'" % [dialogue.id, dialogue.entry_node_id])

	for node in dialogue.nodes:
		if node == null or String(node.node_id).is_empty():
			continue
		_validate_node(dialogue, node, node_lookup, item_registry, npc_registry, unit_registry)


func _validate_node(
	dialogue: DialogueData,
	node: DialogueNode,
	node_lookup: Dictionary,
	item_registry: Node,
	npc_registry: Node,
	unit_registry: Node
) -> void:
	_node_count += 1
	var label := "%s.%s" % [dialogue.id, node.node_id]

	var speaker_id := String(node.speaker_id).strip_edges()
	if not speaker_id.is_empty() and not PLACEHOLDER_SPEAKERS.has(speaker_id):
		if not unit_registry.has(speaker_id) and not npc_registry.has(speaker_id):
			_error("%s: unknown speaker_id '%s'" % [label, speaker_id])

	if String(node.text).strip_edges().is_empty():
		_error("%s: empty text" % label)

	if not String(node.next_node_id).is_empty() and not node_lookup.has(node.next_node_id):
		_error("%s: next_node_id '%s' not found" % [label, node.next_node_id])

	_validate_flag_names(label, "required_flags", node.required_flags)
	_validate_flag_names(label, "forbidden_flags", node.forbidden_flags)
	_validate_portrait_path(label, node)
	_validate_actions(label, node.on_enter_actions, item_registry)
	_validate_actions(label, node.on_exit_actions, item_registry)

	for index in range(node.choices.size()):
		var choice := node.choices[index] as DialogueChoice
		if choice == null:
			_warning("%s.choice[%d]: null choice entry" % [label, index])
			continue
		var choice_label := "%s.choice[%d]" % [label, index]
		if String(choice.text).strip_edges().is_empty():
			_error("%s: empty choice text" % choice_label)
		if String(choice.next_node_id).is_empty():
			_warning("%s: empty next_node_id ends dialogue" % choice_label)
		elif not node_lookup.has(choice.next_node_id):
			_error("%s: next_node_id '%s' not found" % [choice_label, choice.next_node_id])
		_validate_flag_names(choice_label, "required_flags", choice.required_flags)
		_validate_flag_names(choice_label, "forbidden_flags", choice.forbidden_flags)
		_validate_actions(choice_label, choice.actions, item_registry)


func _validate_actions(label: String, actions: Array[DialogueAction], item_registry: Node) -> void:
	for index in range(actions.size()):
		var action := actions[index] as DialogueAction
		if action == null:
			_warning("%s.action[%d]: null action entry" % [label, index])
			continue
		var action_label := "%s.action[%d]" % [label, index]
		var action_type := String(action.type).strip_edges()
		if not KNOWN_ACTION_TYPES.has(action_type):
			_error("%s: unknown action type '%s'" % [action_label, action_type])
			continue

		var payload := action.payload
		match action_type:
			"start_battle":
				var level_id := String(payload.get("level_id", payload.get("level", ""))).strip_edges()
				var return_to_poi := String(payload.get("return_to_poi", "")).strip_edges()
				if level_id.is_empty():
					_error("%s: start_battle missing payload.level_id" % action_label)
				if return_to_poi.is_empty():
					_error("%s: start_battle missing payload.return_to_poi" % action_label)
			"give_item":
				var item_id := String(payload.get("id", payload.get("item_id", ""))).strip_edges()
				var count := int(payload.get("count", 0))
				if item_id.is_empty():
					_error("%s: give_item missing payload.id" % action_label)
				elif not item_registry.has(item_id):
					_error("%s: give_item unknown item id '%s'" % [action_label, item_id])
				if count <= 0:
					_error("%s: give_item payload.count must be > 0" % action_label)
			"give_equipment":
				var equipment_id := String(payload.get("id", payload.get("item_id", ""))).strip_edges()
				if equipment_id.is_empty():
					_warning("%s: give_equipment missing payload.id" % action_label)


func _validate_flag_names(label: String, field_name: String, flags: Array[String]) -> void:
	for flag in flags:
		var flag_name := String(flag).strip_edges()
		if flag_name.is_empty():
			_error("%s.%s: contains empty flag name" % [label, field_name])
			continue
		if not _is_flag_name_valid(flag_name):
			_error("%s.%s: invalid flag '%s'" % [label, field_name, flag_name])


func _is_flag_name_valid(flag_name: String) -> bool:
	var dot_index := flag_name.find(".")
	if dot_index <= 0 or dot_index >= flag_name.length() - 1:
		return false
	return flag_name.is_subsequence_ofn(flag_name) and flag_name.is_valid_filename()


func _validate_portrait_path(label: String, node: DialogueNode) -> void:
	var portrait_value = node.get("portrait_path")
	if portrait_value == null:
		return
	var portrait_path := String(portrait_value).strip_edges()
	if portrait_path.is_empty():
		return
	if not ResourceLoader.exists(portrait_path):
		_warning("%s: portrait_path missing resource '%s'" % [label, portrait_path])
		return
	var portrait := load(portrait_path)
	if portrait == null:
		_warning("%s: portrait_path failed to load '%s'" % [label, portrait_path])


func _warning(message: String) -> void:
	_warning_count += 1
	print("[WARN] %s" % message)


func _error(message: String) -> void:
	_error_count += 1
	print("[ERROR] %s" % message)


func _finish() -> void:
	print(
		"[validate_dialogues] total=%d dialogues=%d nodes=%d warnings=%d errors=%d" % [
			_dialogue_count + _node_count,
			_dialogue_count,
			_node_count,
			_warning_count,
			_error_count,
		]
	)
	print("%d errors %d warnings" % [_error_count, _warning_count])
	quit(0 if _error_count == 0 else 1)
