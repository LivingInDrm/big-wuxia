extends Node
## ItemRegistry —— 物品数据查询单例（Autoload）
##
## 职责：在启动阶段扫描 res://resources/data/items/ 下所有 ItemData .tres，
## 按 id 建立索引；业务代码只用 string id 取数据。
##
## API：
##   get_data(id)   -> ItemData 或 null
##   has(id)        -> bool
##   all_ids()      -> PackedStringArray（已排序）
##   all()          -> Array[Resource]（按 id 排序）
##   reload()       -> 重新扫描（测试/热重载用）

const ItemData = preload("res://scripts/core/item_data.gd")

const DATA_DIR := "res://resources/data/items/"

var _by_id: Dictionary = {}


func _init() -> void:
	reload()


func _ready() -> void:
	if _by_id.is_empty():
		reload()


func get_data(id: String) -> ItemData:
	return _by_id.get(id) as ItemData


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
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		return
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load("%s%s" % [DATA_DIR, file_name])
		if res == null:
			continue
		if not (res is ItemData):
			continue
		var id_value := String(res.id)
		if id_value.is_empty():
			push_warning("[ItemRegistry] 跳过无 id 的资源: %s" % file_name)
			continue
		if _by_id.has(id_value):
			push_warning("[ItemRegistry] id 重复: %s (%s)" % [id_value, file_name])
			continue
		_by_id[id_value] = res
