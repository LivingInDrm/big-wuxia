extends Node
class_name CombatSystem
## CombatSystem —— 基础攻击 / 技能伤害结算

const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")

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
		return {"hit": false, "crit": false, "damage": 0, "hit_chance": 0, "result": "miss"}
	if attacker.unit_data == null or defender.unit_data == null:
		return {"hit": false, "crit": false, "damage": 0, "hit_chance": 0, "result": "miss"}

	var terrain = grid.get_tile(defender.current_position) if grid != null else null
	var terrain_dodge_bonus := 0
	var terrain_def_bonus := 0
	if terrain != null and terrain.terrain != null:
		terrain_dodge_bonus = int(round(terrain.terrain.dodge_bonus * 100.0))
		terrain_def_bonus = int(terrain.terrain.get("def_bonus")) if terrain.terrain.get("def_bonus") != null else 0

	var atk_total: int = int(AttributeResolver.get_attack(attacker)["total"])
	var def_total: int = int(AttributeResolver.get_defense(defender)["total"]) + terrain_def_bonus
	var weapon_bonus: float = WeaponTypes.counter_multiplier(
		attacker.unit_data.weapon_type, defender.unit_data.weapon_type)

	if skill != null:
		var power: float = float(skill.power)
		var atk_power: int = int(round(atk_total * power))
		var damage: int = max(1, int(round(float(max(1, atk_power - def_total)) * weapon_bonus)))
		return {
			"hit": true,
			"crit": false,
			"damage": damage,
			"hit_chance": 100,
			"hit_roll": -1,
			"crit_roll": -1,
			"result": "hit",
		}

	var hit_total: int = int(AttributeResolver.get_hit(attacker)["total"])
	var dodge_total: int = int(AttributeResolver.get_dodge(defender, terrain_dodge_bonus)["total"])
	var hit_chance: int = clamp(hit_total - dodge_total, 5, 95)
	var hit_roll: int = _lcg_next() % 100
	if hit_roll >= hit_chance:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"hit_chance": hit_chance,
			"hit_roll": hit_roll,
			"crit_roll": -1,
			"result": "miss",
		}

	var crit_total: int = int(AttributeResolver.get_crit(attacker)["total"])
	var crit_roll: int = _lcg_next() % 100
	var is_crit: bool = crit_roll < crit_total
	var crit_multiplier: float = 1.5 if is_crit else 1.0
	var damage: int = max(1, int(round(float(atk_total - def_total) * crit_multiplier) * weapon_bonus))
	return {
		"hit": true,
		"crit": is_crit,
		"damage": damage,
		"hit_chance": hit_chance,
		"hit_roll": hit_roll,
		"crit_roll": crit_roll,
		"result": "crit" if is_crit else "hit",
	}


static func resolve_attack(attacker: Unit, defender: Unit, grid: GridSystem,
		skill = null) -> Dictionary:
	var result := calculate_attack(attacker, defender, grid, skill)
	if result.hit:
		defender.take_damage(result.damage)
	else:
		var parent := defender.get_parent() if defender.get_parent() != null else defender
		VFX.spawn_damage_number(parent, defender.global_position + Vector2(0, -40), "MISS", false)
	return result


static func _lcg_next() -> int:
	_roll_state = int((int(_LCG_A) * _roll_state + _LCG_C) & _LCG_M)
	return _roll_state
