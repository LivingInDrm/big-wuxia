extends SceneTree
## test_specialty —— v2 P1 step-1-4 专精系统单测
##
## 用法：godot --headless --path . --script tests/test_specialty.gd

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")
const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")
const AttributeSet = preload("res://scripts/core/attribute_set.gd")
const WeaponTypes = preload("res://scripts/core/weapon_types.gd")

class DummyUnit:
	var unit_data: UnitData


var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_specialty] ==== BEGIN ====")

	await _check_unit("xu_fengnian", WeaponTypes.Type.BLADE, 8, 28)
	await _check_unit("jiang_ni", WeaponTypes.Type.FIST, 0, 8)
	await _check_unit("li_chungang", WeaponTypes.Type.SWORD, 10, 33)
	await _check_unit("enemy_soldier", WeaponTypes.Type.FIST, 3, 14)
	await _check_unit("yang_yuanzan", WeaponTypes.Type.BLADE, 5, 25)
	_check_none_fallback()

	_finish()


func _check_unit(unit_id: String, expected_weapon_type: int, expected_specialty_level: int,
		expected_attack_total: int) -> void:
	var data: UnitData = load("res://resources/data/units/%s.tres" % unit_id)
	_assert(data != null, "%s data load 非 null" % unit_id)
	if data == null:
		return

	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, Vector2i(1, 1))
	root.add_child(unit)
	await process_frame

	var attack := AttributeResolver.get_attack(unit)
	var sources: Dictionary = attack.get("sources", {})
	_assert(int(data.weapon_type) == expected_weapon_type,
		"%s weapon_type=%d (exp=%d)" % [unit_id, int(data.weapon_type), expected_weapon_type])
	_assert(AttributeResolver._get_specialty_for_weapon(unit) == expected_specialty_level,
		"%s specialty level=%d (exp=%d)" % [
			unit_id, AttributeResolver._get_specialty_for_weapon(unit), expected_specialty_level
		])
	_assert(int(sources.get("specialty", -1)) == int(expected_specialty_level * 1.5),
		"%s specialty source=%d (exp=%d)" % [
			unit_id, int(sources.get("specialty", -1)), int(expected_specialty_level * 1.5)
		])
	_assert(int(attack.get("total", -1)) == expected_attack_total,
		"%s attack total=%d (exp=%d)" % [
			unit_id, int(attack.get("total", -1)), expected_attack_total
		])

	unit.queue_free()
	await process_frame


func _check_none_fallback() -> void:
	var attrs := AttributeSet.new()
	attrs.strength = 6
	attrs.spec_fist = 9
	attrs.spec_blade = 9
	attrs.spec_sword = 9

	var data := UnitData.new()
	data.attributes = attrs
	data.weapon_type = WeaponTypes.Type.NONE

	var unit := DummyUnit.new()
	unit.unit_data = data

	var attack := AttributeResolver.get_attack(unit)
	var sources: Dictionary = attack.get("sources", {})
	_assert(AttributeResolver._get_specialty_for_weapon(unit) == 0, "NONE weapon_type specialty level=0")
	_assert(int(sources.get("specialty", -1)) == 0, "NONE weapon_type specialty source=0")
	_assert(int(attack.get("total", -1)) == 12, "NONE weapon_type attack=strength*2=12")


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_specialty] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
