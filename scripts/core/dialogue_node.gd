extends Resource
class_name DialogueNode

const DialogueAction = preload("res://scripts/core/dialogue_action.gd")
const DialogueChoice = preload("res://scripts/core/dialogue_choice.gd")

@export var node_id: String = ""
@export var speaker_id: String = ""
@export var speaker_name_override: String = ""
@export_multiline var text: String = ""
@export var choices: Array[DialogueChoice] = []
@export var next_node_id: String = ""
@export var on_enter_actions: Array[DialogueAction] = []
@export var on_exit_actions: Array[DialogueAction] = []
@export var required_flags: Array[String] = []
@export var forbidden_flags: Array[String] = []
