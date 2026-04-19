extends SceneTree
## test_combat_roll —— v2 P1 step-1-5 命中/暴击 roll 单测
##
## 用法：godot --headless --path . --script tests/test_combat_roll.gd

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")
const AttributeSet = preload("res://scripts/core/attribute_set.gd")
const UnitData = preload("res://scripts/core/unit_data.gd")
const WeaponTypes = preload("res://scripts/core/weapon_types.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_combat_roll] ==== BEGIN ====")

	await _test_first_attack_determinism()
	await _test_hit_chance_clamp_high()
	await _test_hit_chance_clamp_low()
	await _test_crit_trigger_determinism()

	_finish()


func _test_first_attack_determinism() -> void:
	var ctx := await _spawn_units(load("res://resources/data/units/xu_fengnian.tres"),
		load("res://resources/data/units/enemy_soldier.tres"))
	CombatSystem.reset_roll_seed(4)

	var result: Dictionary = CombatSystem.calculate_attack(ctx.attacker, ctx.defender, ctx.grid)
	_assert(result.hit, "T1a seed=4 首次攻击命中")
	_assert(not result.crit, "T1b seed=4 首次攻击不暴击")
	_assert(result.result == "hit", "T1c result=hit (实际=%s)" % String(result.result))
	_assert(int(result.hit_chance) == 79, "T1d 徐凤年→敌兵 hit_chance=79 (实际=%d)" % int(result.hit_chance))
	_assert(int(result.hit_roll) == 29, "T1e 首次 hit_roll=29 (实际=%d)" % int(result.hit_roll))
	_assert(int(result.crit_roll) == 78, "T1f 首次 crit_roll=78 (实际=%d)" % int(result.crit_roll))
	_assert(int(result.damage) == 26, "T1g 首次伤害=26 (实际=%d)" % int(result.damage))

	_cleanup_ctx(ctx)
	await process_frame


func _test_hit_chance_clamp_high() -> void:
	var attacker_data := _make_unit_data(10, 20, 40, WeaponTypes.Type.FIST, 0)
	var defender_data := _make_unit_data(1, 1, 0, WeaponTypes.Type.FIST, 0)
	var ctx := await _spawn_units(attacker_data, defender_data)
	CombatSystem.reset_roll_seed(4)

	var result: Dictionary = CombatSystem.calculate_attack(ctx.attacker, ctx.defender, ctx.grid)
	_assert(int(result.hit_chance) == 95, "T2a hit_chance 高位 clamp 到 95")
	_assert(result.hit, "T2b 95% 命中下首发命中")

	_cleanup_ctx(ctx)
	await process_frame


func _test_hit_chance_clamp_low() -> void:
	var attacker_data := _make_unit_data(1, 0, 0, WeaponTypes.Type.FIST, 0)
	var defender_data := _make_unit_data(1, 1, 100, WeaponTypes.Type.FIST, 0)
	var ctx := await _spawn_units(attacker_data, defender_data)
	CombatSystem.reset_roll_seed(4)

	var result: Dictionary = CombatSystem.calculate_attack(ctx.attacker, ctx.defender, ctx.grid)
	_assert(int(result.hit_chance) == 5, "T3a hit_chance 低位 clamp 到 5")
	_assert(not result.hit, "T3b 5% 命中下首发 miss")
	_assert(int(result.damage) == 0, "T3c miss 时 damage=0")

	_cleanup_ctx(ctx)
	await process_frame


func _test_crit_trigger_determinism() -> void:
	var attacker_data := _make_unit_data(10, 10, 40, WeaponTypes.Type.FIST, 0)
	var defender_data := _make_unit_data(1, 1, 0, WeaponTypes.Type.FIST, 0)
	var ctx := await _spawn_units(attacker_data, defender_data)
	CombatSystem.reset_roll_seed(4)

	var result: Dictionary = {}
	for _i in 6:
		result = CombatSystem.calculate_attack(ctx.attacker, ctx.defender, ctx.grid)

	_assert(result.hit, "T4a 第 6 次攻击仍命中")
	_assert(result.crit, "T4b seed=4 第 6 次攻击触发暴击")
	_assert(result.result == "crit", "T4c result=crit (实际=%s)" % String(result.result))
	_assert(int(result.crit_roll) == 0, "T4d 第 6 次 crit_roll=0 (实际=%d)" % int(result.crit_roll))
	_assert(int(result.damage) == 29, "T4e 暴击伤害=29 (实际=%d)" % int(result.damage))

	_cleanup_ctx(ctx)
	await process_frame


func _spawn_units(attacker_data: UnitData, defender_data: UnitData) -> Dictionary:
	var grid := GridSystem.new()
	root.add_child(grid)
	var terrain: TerrainTileData = load("res://resources/data/tiles/grass.tres")
	grid.tiles[Vector2i(0, 0)] = GridTile.new(Vector2i(0, 0), terrain)
	grid.tiles[Vector2i(1, 0)] = GridTile.new(Vector2i(1, 0), terrain)

	var attacker: Unit = UNIT_SCENE.instantiate()
	var defender: Unit = UNIT_SCENE.instantiate()
	attacker.setup(attacker_data, Vector2i(0, 0))
	defender.setup(defender_data, Vector2i(1, 0))
	root.add_child(attacker)
	root.add_child(defender)
	grid.tiles[Vector2i(0, 0)].occupant = attacker
	grid.tiles[Vector2i(1, 0)].occupant = defender
	await process_frame
	return {"grid": grid, "attacker": attacker, "defender": defender}


func _make_unit_data(constitution: int, strength: int, agility: int, weapon_type: int,
		specialty: int) -> UnitData:
	var attrs := AttributeSet.new()
	attrs.constitution = constitution
	attrs.strength = strength
	attrs.agility = agility
	match weapon_type:
		WeaponTypes.Type.BLADE:
			attrs.spec_blade = specialty
		WeaponTypes.Type.SWORD:
			attrs.spec_sword = specialty
		WeaponTypes.Type.FIST:
			attrs.spec_fist = specialty

	var data := UnitData.new()
	data.attributes = attrs
	data.weapon_type = weapon_type
	return data


func _cleanup_ctx(ctx: Dictionary) -> void:
	if ctx.get("attacker") != null:
		ctx.attacker.queue_free()
	if ctx.get("defender") != null:
		ctx.defender.queue_free()
	if ctx.get("grid") != null:
		ctx.grid.queue_free()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_combat_roll] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
