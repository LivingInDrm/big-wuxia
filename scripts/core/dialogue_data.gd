extends Resource
class_name DialogueData

const DialogueNode = preload("res://scripts/core/dialogue_node.gd")

@export_group("Identity")
@export var id: String = ""
@export var entry_node_id: String = "start"

@export_group("Content")
@export var nodes: Array[DialogueNode] = []
@export var meta: Dictionary = {}
