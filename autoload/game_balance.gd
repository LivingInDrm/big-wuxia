extends Node
## GameBalance — 游戏数值配置加载器（Autoload）
##
## 职责：加载并缓存 UnitData / SkillData / TileData / LevelData 资源，提供统一查询接口。
## 依赖：resources/data/ 下的 .tres 文件（S2~S6 逐步填充）。
## 参考：docs/design/02-architecture.md §3.2
##
## S1 说明：Resource 类在 S1 阶段尚未创建，此处只保留空字典与接口占位，
## 避免在 Autoload 启动阶段 load() 不存在的文件导致 push_error。
## S2 起会随 Resource 的逐步落地打开 _load_all_resources() 的加载项。

var units: Dictionary = {}
var skills: Dictionary = {}
var tiles: Dictionary = {}
var levels: Dictionary = {}


func _ready() -> void:
	_load_all_resources()


func _load_all_resources() -> void:
	_load_dir("res://resources/data/units", units, "unit_id")
	_load_dir("res://resources/data/skills", skills, "skill_id")
	_load_dir("res://resources/data/tiles", tiles, "tile_id")


func get_unit_data(unit_id: String) -> Resource:
	return units.get(unit_id)


func get_skill_data(skill_id: String) -> Resource:
	return skills.get(skill_id)


func get_tile_data(tile_id: String) -> Resource:
	return tiles.get(tile_id)


func get_level_data(level_id: String) -> Resource:
	return levels.get(level_id)


func _load_dir(dir_path: String, target: Dictionary, id_prop: String) -> void:
	target.clear()
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load("%s/%s" % [dir_path, file_name])
		if res == null:
			continue
		var id_value = res.get(id_prop)
		if id_value == null or String(id_value) == "":
			continue
		target[String(id_value)] = res
