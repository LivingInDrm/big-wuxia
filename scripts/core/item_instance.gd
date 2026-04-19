extends RefCounted
class_name ItemInstance

const ItemData = preload("res://scripts/core/item_data.gd")

static var _next_instance_id: int = 1

var instance_id: int
var item_data: ItemData
var enhancement_level: int = 0


func _init(data: ItemData, enhancement: int = 0) -> void:
	item_data = data
	enhancement_level = enhancement
	instance_id = _next_instance_id
	_next_instance_id += 1
