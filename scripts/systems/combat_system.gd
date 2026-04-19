extends Node
class_name CombatSystem
## CombatSystem —— 基础攻击 / 技能伤害结算

const BASE_HIT_CHANCE := 95
const _LCG_A := 1103515245
const _LCG_C := 12345
const _LCG_M := 0x7fffffff

static var _roll_state: int = 4


static func reset_roll_seed(seed: int = 4) -> void:
	_roll_state = seed


static func calc_damage(attacker_atk: int, defender_def: int) -> int:
	return max(1, attacker_atk - defender_def)


static func calculate_attack(attacker: Unit, defender: Unit, grid: GridSystem,
		skill = null) -> Dictionary:
	if attacker == null or defender == null:
		return {"hit": false, "damage": 0, "hit_chance": 0}
	if attacker.unit_data == null or defender.unit_data == null:
		return {"hit": false, "damage": 0, "hit_chance": 0}

	var terrain = grid.get_tile(defender.current_position) if grid != null else null
	var dodge_bonus: int = 0
	var def_bonus: int = 0
	if terrain != null and terrain.terrain != null:
		dodge_bonus = int(round(terrain.terrain.dodge_bonus * 100.0))
		def_bonus = int(terrain.terrain.get("def_bonus")) if terrain.terrain.get("def_bonus") != null else 0

	var hit_chance: int = clamp(BASE_HIT_CHANCE - dodge_bonus, 0, 100)
	var hit: bool = _roll_percent(hit_chance)
	var power: float = float(skill.power) if skill != null else 1.0
	var atk_power: int = int(round(attacker.unit_data.atk * power))
	var defender_def: int = defender.unit_data.def + def_bonus
	var weapon_bonus: float = WeaponTypes.counter_multiplier(
		attacker.unit_data.weapon_type, defender.unit_data.weapon_type)
	var damage: int = max(1, int(round(float(max(1, atk_power - defender_def)) * weapon_bonus))) if hit else 0
	return {
		"hit": hit,
		"damage": damage,
		"hit_chance": hit_chance,
	}


static func resolve_attack(attacker: Unit, defender: Unit, grid: GridSystem,
		skill = null) -> bool:
	var result := calculate_attack(attacker, defender, grid, skill)
	if result.hit:
		defender.take_damage(result.damage)
	return defender.current_hp <= 0


static func _roll_percent(percent: int) -> bool:
	if percent <= 0:
		return false
	if percent >= 100:
		return true
	_roll_state = int((int(_LCG_A) * _roll_state + _LCG_C) & _LCG_M)
	return (_roll_state % 100) < percent
