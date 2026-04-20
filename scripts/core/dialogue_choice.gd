extends Resource
class_name DialogueChoice

const DialogueAction = preload("res://scripts/core/dialogue_action.gd")

@export_multiline var text: String = ""
@export var next_node_id: String = ""
@export var required_flags: Array[String] = []
@export var forbidden_flags: Array[String] = []
@export var actions: Array[DialogueAction] = []
