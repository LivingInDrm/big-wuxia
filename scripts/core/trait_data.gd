class_name TraitData
extends RefCounted

var id: String = ""
var modifier_dict: Dictionary = {}


func _init(trait_id: String = "", modifiers: Dictionary = {}) -> void:
	id = trait_id
	modifier_dict = modifiers.duplicate(true)
