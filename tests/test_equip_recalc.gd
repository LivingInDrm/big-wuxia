extends SceneTree

const UNIT_SCENE = preload("res://scenes/unit/unit.tscn")
const ITEM_DATA = preload("res://scripts/core/item_data.gd")
const ITEM_INSTANCE = preload("res://scripts/core/item_instance.gd")
const XU_FENGNIAN = preload("res://resources/data/units/xu_fengnian.tres")
const JADE_PENDANT = preload("res://resources/data/items/jade_pendant.tres")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_equip_recalc] ==== BEGIN ====")

	await _test_full_hp_grows_with_max_hp()
	await _test_partial_hp_keeps_ratio_on_equip()
	await _test_full_hp_shrinks_to_new_cap_on_unequip()
	await _test_partial_hp_keeps_ratio_on_unequip()

	_finish()


func _test_full_hp_grows_with_max_hp() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	_assert(unit.current_hp == 105 and unit.get_max_hp() == 105, "T1a 初始满血 105/105")
	var pendant := _equip_jade_pendant(state)
	_assert(pendant != null, "T1b jade_pendant 可装备")
	await process_frame

	_assert(unit.current_hp == 125, "T1c 满血装备后 current_hp=125")
	_assert(unit.get_max_hp() == 125, "T1d 满血装备后 max_hp=125")

	_cleanup_unit(unit)


func _test_partial_hp_keeps_ratio_on_equip() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	unit.current_hp = 80
	unit._refresh_health_bar()
	var pendant := _equip_jade_pendant(state)
	_assert(pendant != null, "T2a 低血量时 jade_pendant 可装备")
	await process_frame

	_assert(unit.current_hp == 95, "T2b 80/105 装备后 current_hp=95")
	_assert(unit.get_max_hp() == 125, "T2c 80/105 装备后 max_hp=125")

	_cleanup_unit(unit)


func _test_full_hp_shrinks_to_new_cap_on_unequip() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	var pendant := _equip_jade_pendant(state)
	_assert(pendant != null, "T3a 卸装前 jade_pendant 已装备")
	await process_frame
	unit.current_hp = 125
	unit._refresh_health_bar()
	state.unequip(XU_FENGNIAN.unit_id, ITEM_DATA.EquipSlot.ACCESSORY_1)
	await process_frame

	_assert(unit.current_hp == 105, "T3b 125/125 卸装后 current_hp=105")
	_assert(unit.get_max_hp() == 105, "T3c 125/125 卸装后 max_hp=105")

	_cleanup_unit(unit)


func _test_partial_hp_keeps_ratio_on_unequip() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	var pendant := _equip_jade_pendant(state)
	_assert(pendant != null, "T4a 比例卸装前 jade_pendant 已装备")
	await process_frame
	unit.current_hp = 80
	unit._refresh_health_bar()
	state.unequip(XU_FENGNIAN.unit_id, ITEM_DATA.EquipSlot.ACCESSORY_1)
	await process_frame

	_assert(unit.current_hp == 67, "T4b 80/125 卸装后 current_hp=67")
	_assert(unit.get_max_hp() == 105, "T4c 80/125 卸装后 max_hp=105")

	_cleanup_unit(unit)


func _spawn_unit() -> Unit:
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(XU_FENGNIAN, Vector2i(1, 1))
	root.add_child(unit)
	await process_frame
	return unit


func _cleanup_unit(unit: Unit) -> void:
	if unit != null:
		unit.queue_free()


func _equip_jade_pendant(state: Node) -> ItemInstance:
	state.inventory.add(JADE_PENDANT.id)
	var instance := _find_unique_item(state, JADE_PENDANT.id)
	if instance == null:
		return null
	if not state.equip(XU_FENGNIAN.unit_id, ITEM_DATA.EquipSlot.ACCESSORY_1, instance):
		return null
	return instance


func _find_unique_item(state: Node, item_id: String) -> ItemInstance:
	for entry in state.inventory.unique_items:
		var instance := entry as ItemInstance
		if instance != null and instance.item_data != null and instance.item_data.id == item_id:
			return instance
	return null


func _get_game_state() -> Node:
	var state := root.get_node_or_null("GameState")
	_assert(state != null, "GameState autoload 存在")
	return state


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_equip_recalc] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
