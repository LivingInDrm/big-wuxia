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
	# S1 阶段不加载任何 Resource（S2+ 开始逐步加载实例）
	pass


func get_unit_data(unit_id: String) -> Resource:
	return units.get(unit_id)


func get_skill_data(skill_id: String) -> Resource:
	return skills.get(skill_id)


func get_tile_data(tile_id: String) -> Resource:
	return tiles.get(tile_id)


func get_level_data(level_id: String) -> Resource:
	return levels.get(level_id)
