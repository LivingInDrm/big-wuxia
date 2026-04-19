extends SceneTree

const UNIT_SCENE = preload("res://scenes/unit/unit.tscn")
const ATTRIBUTE_RESOLVER = preload("res://scripts/systems/attribute_resolver.gd")
const ITEM_DATA = preload("res://scripts/core/item_data.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")
const XU_FENGNIAN = preload("res://resources/data/units/xu_fengnian.tres")
const LI_CHUNGANG = preload("res://resources/data/units/li_chungang.tres")
const JIANG_NI = preload("res://resources/data/units/jiang_ni.tres")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_initial_equipment] ==== BEGIN ====")

	_test_reset_equips_starting_items()
	await _test_attribute_totals_include_starting_equipment()
	_test_reset_is_idempotent()

	_finish()


func _test_reset_equips_starting_items() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()

	_assert_equipped(state.get_equipped_items(XU_FENGNIAN.unit_id), ITEM_DATA.EquipSlot.WEAPON, "iron_blade",
		"T1a 徐凤年 WEAPON=iron_blade")
	_assert_equipped(state.get_equipped_items(LI_CHUNGANG.unit_id), ITEM_DATA.EquipSlot.WEAPON, "plain_sword",
		"T1b 李淳罡 WEAPON=plain_sword")
	_assert_equipped(state.get_equipped_items(JIANG_NI.unit_id), ITEM_DATA.EquipSlot.ARMOR, "cloth_robe",
		"T1c 姜泥 ARMOR=cloth_robe")
	_assert(state.inventory.count("iron_blade") == 0, "T1d inventory 不含 iron_blade")
	_assert(state.inventory.count("plain_sword") == 0, "T1e inventory 不含 plain_sword")
	_assert(state.inventory.count("cloth_robe") == 0, "T1f inventory 不含 cloth_robe")


func _test_attribute_totals_include_starting_equipment() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()

	var xu := await _spawn_unit(XU_FENGNIAN)
	var li := await _spawn_unit(LI_CHUNGANG)
	var jiang := await _spawn_unit(JIANG_NI)

	var xu_attack := ATTRIBUTE_RESOLVER.get_attack(xu)
	var li_attack := ATTRIBUTE_RESOLVER.get_attack(li)
	var jiang_defense := ATTRIBUTE_RESOLVER.get_defense(jiang)
	var jiang_max_hp := ATTRIBUTE_RESOLVER.get_max_hp(jiang)

	_assert(int(xu_attack.get("total", -1)) == 33, "T2a 徐凤年 attack.total=33")
	_assert(int(xu_attack.get("sources", {}).get("equipment", -1)) == 5, "T2b 徐凤年 attack.equipment=5")
	_assert(int(li_attack.get("total", -1)) == 37, "T2c 李淳罡 attack.total=37")
	_assert(int(li_attack.get("sources", {}).get("equipment", -1)) == 4, "T2d 李淳罡 attack.equipment=4")
	_assert(int(jiang_defense.get("total", -1)) == 9, "T2e 姜泥 defense.total=9")
	_assert(int(jiang_defense.get("sources", {}).get("equipment", -1)) == 2, "T2f 姜泥 defense.equipment=2")
	_assert(int(jiang_max_hp.get("total", -1)) == 85, "T2g 姜泥 max_hp.total=85")
	_assert(int(jiang_max_hp.get("sources", {}).get("equipment", -1)) == 5, "T2h 姜泥 max_hp.equipment=5")

	_cleanup_unit(xu)
	_cleanup_unit(li)
	_cleanup_unit(jiang)
	await process_frame


func _test_reset_is_idempotent() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()
	var first_xu_weapon := _get_equipped_item_id(state.get_equipped_items(XU_FENGNIAN.unit_id), ITEM_DATA.EquipSlot.WEAPON)
	var first_li_weapon := _get_equipped_item_id(state.get_equipped_items(LI_CHUNGANG.unit_id), ITEM_DATA.EquipSlot.WEAPON)
	var first_jiang_armor := _get_equipped_item_id(state.get_equipped_items(JIANG_NI.unit_id), ITEM_DATA.EquipSlot.ARMOR)

	state.reset()
	var second_xu_weapon := _get_equipped_item_id(state.get_equipped_items(XU_FENGNIAN.unit_id), ITEM_DATA.EquipSlot.WEAPON)
	var second_li_weapon := _get_equipped_item_id(state.get_equipped_items(LI_CHUNGANG.unit_id), ITEM_DATA.EquipSlot.WEAPON)
	var second_jiang_armor := _get_equipped_item_id(state.get_equipped_items(JIANG_NI.unit_id), ITEM_DATA.EquipSlot.ARMOR)

	_assert(first_xu_weapon == "iron_blade" and second_xu_weapon == "iron_blade",
		"T3a reset 多次后徐凤年始终仅装备 iron_blade")
	_assert(first_li_weapon == "plain_sword" and second_li_weapon == "plain_sword",
		"T3b reset 多次后李淳罡始终仅装备 plain_sword")
	_assert(first_jiang_armor == "cloth_robe" and second_jiang_armor == "cloth_robe",
		"T3c reset 多次后姜泥始终仅装备 cloth_robe")
	_assert(state.inventory.count("iron_blade") == 0, "T3d reset 多次后 inventory 无额外 iron_blade")
	_assert(state.inventory.count("plain_sword") == 0, "T3e reset 多次后 inventory 无额外 plain_sword")
	_assert(state.inventory.count("cloth_robe") == 0, "T3f reset 多次后 inventory 无额外 cloth_robe")
	_assert(state.inventory.unique_items.is_empty(), "T3g reset 多次后 inventory.unique_items 仍为空")


func _spawn_unit(data: UnitData) -> Unit:
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, Vector2i(1, 1))
	root.add_child(unit)
	await process_frame
	return unit


func _cleanup_unit(unit: Unit) -> void:
	if unit != null:
		unit.queue_free()


func _get_game_state() -> Node:
	var state := root.get_node_or_null("GameState")
	_assert(state != null, "GameState autoload 存在")
	return state


func _assert_equipped(items: Dictionary, slot: int, expected_item_id: String, msg: String) -> void:
	var instance := items.get(slot) as ItemInstance
	_assert(instance != null and instance.item_data != null and instance.item_data.id == expected_item_id, msg)


func _get_equipped_item_id(items: Dictionary, slot: int) -> String:
	var instance := items.get(slot) as ItemInstance
	if instance == null or instance.item_data == null:
		return ""
	return instance.item_data.id


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_initial_equipment] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
