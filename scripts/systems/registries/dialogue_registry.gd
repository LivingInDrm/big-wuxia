extends Node

const DialogueData = preload("res://scripts/core/dialogue_data.gd")

const DATA_DIR := "res://resources/data/dialogues/"

var _by_id: Dictionary = {}


func _init() -> void:
	reload()


func _ready() -> void:
	if _by_id.is_empty():
		reload()


func get_data(id: String) -> DialogueData:
	return _by_id.get(id) as DialogueData


func has(id: String) -> bool:
	return _by_id.has(id)


func all_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for key in _by_id.keys():
		ids.append(String(key))
	ids.sort()
	return ids


func all() -> Array[Resource]:
	var out: Array[Resource] = []
	for id in all_ids():
		out.append(_by_id[id])
	return out


func reload() -> void:
	_by_id.clear()
	_scan_dir(DATA_DIR)


func _scan_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for dir_name in dir.get_directories():
		_scan_dir("%s%s/" % [path, dir_name])
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load("%s%s" % [path, file_name])
		if not (res is DialogueData):
			continue
		var id_value := String(res.id)
		if id_value.is_empty():
			push_warning("[DialogueRegistry] 跳过无 id 的资源: %s%s" % [path, file_name])
			continue
		if _by_id.has(id_value):
			push_warning("[DialogueRegistry] id 重复: %s (%s%s)" % [id_value, path, file_name])
			continue
		_by_id[id_value] = res
