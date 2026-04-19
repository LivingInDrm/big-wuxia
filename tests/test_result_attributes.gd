extends SceneTree
## test_result_attributes —— v2 P1 step-1-5 结果属性单测
##
## 用法：godot --headless --path . --script tests/test_result_attributes.gd

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")
const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_result_attributes] ==== BEGIN ====")

	await _check_unit("xu_fengnian", 87, 4, 11, 5)
	await _check_unit("li_chungang", 88, 5, 11, 5)
	await _check_unit("jiang_ni", 82, 0, 10, 5)
	await _check_unit("enemy_soldier", 80, 1, 8, 5)
	await _check_unit("yang_yuanzan", 83, 2, 9, 5)

	_finish()


func _check_unit(unit_id: String, expected_hit: int, expected_hit_specialty: int,
		expected_dodge: int, expected_crit: int) -> void:
	var data: UnitData = load("res://resources/data/units/%s.tres" % unit_id)
	_assert(data != null, "%s data load 非 null" % unit_id)
	if data == null:
		return

	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, Vector2i(1, 1))
	root.add_child(unit)
	await process_frame

	_check_result(unit_id, "hit", AttributeResolver.get_hit(unit), expected_hit, expected_hit_specialty, 0)
	_check_result(unit_id, "dodge", AttributeResolver.get_dodge(unit), expected_dodge, 0, 0)
	_check_result(unit_id, "crit", AttributeResolver.get_crit(unit), expected_crit, 0, 0)

	unit.queue_free()
	await process_frame


func _check_result(unit_id: String, label: String, result: Dictionary, expected_total: int,
		expected_specialty: int = 0, expected_status: int = 0) -> void:
	var sources: Dictionary = result.get("sources", {})
	var required_keys := ["base", "attribute", "specialty", "equip", "technique", "status"]
	for key in required_keys:
		_assert(sources.has(key), "%s %s sources 包含 %s" % [unit_id, label, key])

	_assert(int(result.get("total", -1)) == expected_total,
		"%s %s total=%d (exp=%d)" % [unit_id, label, int(result.get("total", -1)), expected_total])
	_assert(int(sources.get("specialty", -1)) == expected_specialty,
		"%s %s specialty=%d (exp=%d)" % [
			unit_id, label, int(sources.get("specialty", -1)), expected_specialty
		])
	_assert(int(sources.get("status", -1)) == expected_status,
		"%s %s status=%d (exp=%d)" % [
			unit_id, label, int(sources.get("status", -1)), expected_status
		])

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
	print("[test_result_attributes] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
