class_name StatusEffect
extends RefCounted

var source: String = ""
var modifier_dict: Dictionary = {}
var remaining_turns: int = 0


func _init(effect_source: String = "", modifiers: Dictionary = {}, turns: int = 0) -> void:
	source = effect_source
	modifier_dict = modifiers.duplicate(true)
	remaining_turns = turns
