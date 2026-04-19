extends SceneTree
## test_attribute_resolver —— v2 P1 step-1-3 主战属性推导单测
##
## 用法：godot --headless --path . --script tests/test_attribute_resolver.gd

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")
const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_attribute_resolver] ==== BEGIN ====")

	await _check_unit("xu_fengnian", 16, 10, 8, 6)
	await _check_unit("li_chungang", 18, 10, 8, 6)
	await _check_unit("jiang_ni", 8, 7, 7, 5)
	await _check_unit("enemy_soldier", 10, 7, 4, 3)
	await _check_unit("yang_yuanzan", 18, 13, 6, 4)

	_finish()


func _check_unit(unit_id: String, expected_attack: int, expected_defense: int,
		expected_qinggong: int, expected_qi_speed: int) -> void:
	var data: UnitData = load("res://resources/data/units/%s.tres" % unit_id)
	_assert(data != null, "%s data load 非 null" % unit_id)
	if data == null:
		return

	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, Vector2i(1, 1))
	root.add_child(unit)
	await process_frame

	_check_result(unit_id, "attack", AttributeResolver.get_attack(unit), expected_attack)
	_check_result(unit_id, "defense", AttributeResolver.get_defense(unit), expected_defense)
	_check_result(unit_id, "qinggong", AttributeResolver.get_qinggong(unit), expected_qinggong)
	_check_result(unit_id, "qi_speed", AttributeResolver.get_qi_speed(unit), expected_qi_speed)

	unit.queue_free()
	await process_frame


func _check_result(unit_id: String, label: String, result: Dictionary, expected_total: int) -> void:
	var sources: Dictionary = result.get("sources", {})
	var required_keys := ["base", "attribute", "specialty", "equip", "technique", "status"]
	for key in required_keys:
		_assert(sources.has(key), "%s %s sources 包含 %s" % [unit_id, label, key])

	_assert(int(result.get("total", -1)) == expected_total,
		"%s %s total=%d (exp=%d)" % [unit_id, label, int(result.get("total", -1)), expected_total])
	_assert(int(sources.get("equip", -1)) == 0,
		"%s %s equip=0" % [unit_id, label])
	_assert(int(sources.get("technique", -1)) == 0,
		"%s %s technique=0" % [unit_id, label])
	_assert(int(sources.get("status", -1)) == 0,
		"%s %s status=0" % [unit_id, label])

	var source_sum := 0
	for key in required_keys:
		source_sum += int(sources.get(key, 0))
	_assert(source_sum == int(result.get("total", -1)),
		"%s %s total 等于六源之和 (%d)" % [unit_id, label, source_sum])


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_attribute_resolver] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
