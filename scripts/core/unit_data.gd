extends Resource
class_name UnitData

const AttributeSet = preload("res://scripts/core/attribute_set.gd")
const LootTable = preload("res://scripts/core/loot_table.gd")
## UnitData —— 单位静态数据（Resource，可在编辑器或脚本中实例化成 .tres）
##
## 来源参考：docs/design/02-architecture.md §4.1 + docs/design/01-game-design.md §8
##
## 字段分组：
##   基础识别   id / 显示名
##   属性       attributes（六层属性与移动力入口）
##   战斗       weapon_type / weapon_range
##   技能       skill_ids（S5 再用）
##   动画       sprite_frames / sprite_offset / modulate
##
## modulate 设计：S3 让徐凤年 / 李淳罡 / 敌兵共用 Warrior SpriteFrames，
## 通过不同 modulate（蓝 / 紫 / 红）区分阵营。姜泥单独用 Monk SpriteFrames。

@export_group("Identity")
@export var unit_id: String = ""
@export var unit_name: String = ""
@export var is_enemy: bool = false

@export_group("Attributes")
@export var attributes: AttributeSet

@export_group("Combat")
@export var weapon_type: WeaponTypes.Type = WeaponTypes.Type.NONE
@export var weapon_range: int = 1

@export_group("Skills")
@export var skill_ids: Array[String] = []
@export var loot_table: LootTable

@export_group("Animation")
@export var sprite_frames: SpriteFrames
@export var sprite_offset: Vector2 = Vector2(0, -32)
@export var modulate: Color = Color.WHITE


func _to_string() -> String:
	return "[UnitData id=%s name=%s attrs=%s]" % [unit_id, unit_name, attributes]
