extends SceneTree
## test_unit_resources —— v2 P1 step-1-2 Unit 运行时资源层单测
##
## 用法：godot --headless --path . --script tests/test_unit_resources.gd
##
## 覆盖：
##   T1  5 角色 setup 后 max_hp / max_mp 符合公式
##   T2  current_hp 初始化为 get_max_hp()；current_mp 初始为 0
##   T3  consume_mp / restore_mp 语义正确
##   T4  回合开始占位集气生效（turn 2 起）

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_unit_resources] ==== BEGIN ====")

	await _check_unit_resource_formula("xu_fengnian", 105, 42)
	await _check_unit_resource_formula("jiang_ni", 80, 49)
	await _check_unit_resource_formula("li_chungang", 105, 54)
	await _check_unit_resource_formula("enemy_soldier", 80, 24)
	await _check_unit_resource_formula("yang_yuanzan", 135, 43)

	await _check_mp_api()
	await _check_turn_mp_regen()

	_finish()


func _check_unit_resource_formula(unit_id: String, expected_hp: int, expected_mp: int) -> void:
	var data: UnitData = load("res://resources/data/units/%s.tres" % unit_id)
	_assert(data != null, "%s data load 非 null" % unit_id)
	if data == null:
		return

	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, Vector2i(1, 1))
	root.add_child(unit)
	await process_frame

	_assert(unit.get_max_hp() == expected_hp,
		"%s max_hp=%d (exp=%d)" % [unit_id, unit.get_max_hp(), expected_hp])
	_assert(unit.get_max_mp() == expected_mp,
		"%s max_mp=%d (exp=%d)" % [unit_id, unit.get_max_mp(), expected_mp])
	_assert(unit.current_hp == expected_hp,
		"%s current_hp 初始=%d" % [unit_id, unit.current_hp])
	_assert(unit.current_mp == 0,
		"%s current_mp 初始=0" % unit_id)

	unit.queue_free()
	await process_frame


func _check_mp_api() -> void:
	var data: UnitData = load("res://resources/data/units/xu_fengnian.tres")
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, Vector2i(2, 2))
	root.add_child(unit)
	await process_frame

	_assert(not unit.consume_mp(1), "T3a 初始 mp=0，consume_mp(1) 返回 false")
	unit.restore_mp(10)
	_assert(unit.current_mp == 10, "T3b restore_mp(10) → current_mp=10")
	_assert(unit.consume_mp(7), "T3c mp 足够时 consume_mp 返回 true")
	_assert(unit.current_mp == 3, "T3d consume_mp(7) 后 current_mp=3")
	_assert(not unit.consume_mp(4), "T3e mp 不足时 consume_mp 返回 false")
	_assert(unit.current_mp == 3, "T3f mp 不足不应扣减")
	unit.restore_mp(999)
	_assert(unit.current_mp == unit.get_max_mp(),
		"T3g restore_mp 封顶到 max_mp=%d" % unit.get_max_mp())

	unit.queue_free()
	await process_frame


func _check_turn_mp_regen() -> void:
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	var battle = packed.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	var xu: Unit = battle.get_player_units()[0]
	var turn_manager: TurnManager = battle.get_turn_manager()
	_assert(xu.current_mp == 0, "T4a 开场 current_mp=0")

	turn_manager._next_turn()
	await process_frame

	_assert(xu.current_mp == 6, "T4b 徐凤年 turn 2 集气 +6 (实际=%d)" % xu.current_mp)

	battle.queue_free()
	await process_frame


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_unit_resources] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
