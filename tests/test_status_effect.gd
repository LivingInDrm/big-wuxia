extends SceneTree

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")
const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_status_effect] ==== BEGIN ====")

	await _test_attack_buff_reads_from_status_source()
	await _test_status_effect_expires_after_turn_end()
	await _test_trait_and_status_stack()

	_finish()


func _test_attack_buff_reads_from_status_source() -> void:
	var unit := await _spawn_unit("xu_fengnian")
	var base_attack := AttributeResolver.get_attack(unit)

	unit.add_status_effect("test_buff", {"attack": 3}, 2)
	var buffed_attack := AttributeResolver.get_attack(unit)
	var sources: Dictionary = buffed_attack.get("sources", {})

	_assert(int(base_attack.get("total", -1)) == 33, "T1a 基础 attack total=33")
	_assert(int(buffed_attack.get("total", -1)) == 36, "T1b attack buff 后 total=36")
	_assert(int(sources.get("status", -1)) == 3, "T1c attack sources.status=3")

	unit.queue_free()
	await process_frame


func _test_status_effect_expires_after_turn_end() -> void:
	var battle = await _load_battle()
	var xu: Unit = battle.get_player_units()[0]

	xu.add_status_effect("temp_attack", {"attack": 3}, 2)
	_assert(xu.status_effects.size() == 1, "T2a 挂上 remaining_turns=2 状态")
	_assert(xu.status_effects[0].remaining_turns == 2, "T2b 初始 remaining_turns=2")

	battle.get_turn_manager()._next_turn()
	await process_frame
	_assert(xu.status_effects.size() == 1, "T2c 下一回合开始后状态仍存在")
	_assert(xu.status_effects[0].remaining_turns == 1, "T2d 第一次回合末扣到 1")

	battle.get_turn_manager()._next_turn()
	await process_frame
	_assert(xu.status_effects.is_empty(), "T2e 第二次回合末扣到 0 自动清除")
	_assert(int(AttributeResolver.get_attack(xu).get("total", -1)) == 33, "T2f 清除后 attack 恢复")

	battle.queue_free()
	await process_frame
	await process_frame


func _test_trait_and_status_stack() -> void:
	var unit := await _spawn_unit("jiang_ni")

	unit.add_trait("born_precise", {"hit": 2})
	unit.add_status_effect("focus", {"hit": 3}, 3)
	var hit_result := AttributeResolver.get_hit(unit)
	var sources: Dictionary = hit_result.get("sources", {})

	_assert(int(hit_result.get("total", -1)) == 87, "T3a trait + status 叠加后 hit total=87")
	_assert(int(sources.get("status", -1)) == 5, "T3b hit sources.status=5")

	unit.queue_free()
	await process_frame


func _spawn_unit(unit_id: String) -> Unit:
	var data: UnitData = load("res://resources/data/units/%s.tres" % unit_id)
	_assert(data != null, "%s data load 非 null" % unit_id)
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, Vector2i(1, 1))
	root.add_child(unit)
	await process_frame
	return unit


func _load_battle():
	var packed := load("res://scenes/battle/battle.tscn") as PackedScene
	_assert(packed != null, "battle.tscn load 非 null")
	if packed == null:
		return null
	var battle = packed.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	return battle


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_status_effect] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
