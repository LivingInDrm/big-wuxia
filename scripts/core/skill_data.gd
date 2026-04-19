extends Resource
class_name SkillData

enum RangeType {
	SINGLE = 0,
	LINE = 1,
	CROSS = 2,
	AOE = 3,
}

enum EffectType {
	DAMAGE = 0,
	HEAL = 1,
	BUFF = 2,
}

@export_group("Identity")
@export var skill_id: String = ""
@export var skill_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Cooldown")
@export_range(0, 9) var cooldown: int = 0
@export_range(-1, 9) var max_uses: int = -1

@export_group("Range")
@export var range_type: RangeType = RangeType.SINGLE
@export_range(0, 9) var range_value: int = 1

@export_group("Effect")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var power: float = 1.0
@export var animation_key: String = "skill"

var current_cd: int = 0
var remaining_uses: int = -1


func init_runtime_state() -> void:
	current_cd = 0
	remaining_uses = max_uses


func duplicate_runtime() -> SkillData:
	var out := duplicate(true) as SkillData
	out.init_runtime_state()
	return out


func is_available() -> bool:
	if current_cd > 0:
		return false
	if remaining_uses == 0:
		return false
	return true


func spend_use() -> void:
	current_cd = cooldown
	if remaining_uses > 0:
		remaining_uses -= 1
