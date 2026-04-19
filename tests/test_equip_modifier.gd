extends SceneTree

const UNIT_SCENE = preload("res://scenes/unit/unit.tscn")
const ATTRIBUTE_RESOLVER = preload("res://scripts/systems/attribute_resolver.gd")
const ITEM_DATA = preload("res://scripts/core/item_data.gd")
const ITEM_INSTANCE = preload("res://scripts/core/item_instance.gd")
const XU_FENGNIAN = preload("res://resources/data/units/xu_fengnian.tres")
const IRON_BLADE = preload("res://resources/data/items/iron_blade.tres")
const LEATHER_ARMOR = preload("res://resources/data/items/leather_armor.tres")
const JADE_PENDANT = preload("res://resources/data/items/jade_pendant.tres")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_equip_modifier] ==== BEGIN ====")

	await _test_weapon_attack_modifier()
	await _test_armor_defense_and_hp_modifier()
	await _test_accessory_hp_modifier()
	await _test_multi_equipment_stack()
	await _test_unequip_clears_equipment_source()

	_finish()


func _test_weapon_attack_modifier() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	var blade := _equip_item(state, IRON_BLADE.id, ITEM_DATA.EquipSlot.WEAPON)
	_assert(blade != null, "T1a iron_blade 实例可装备")
	if blade == null:
		_cleanup_unit(unit)
		return
	await process_frame

	var attack := ATTRIBUTE_RESOLVER.get_attack(unit)
	_assert(int(attack["sources"].get("equipment", -1)) == 5, "T1b iron_blade attack.equipment=5")

	_cleanup_unit(unit)


func _test_armor_defense_and_hp_modifier() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	var armor := _equip_item(state, LEATHER_ARMOR.id, ITEM_DATA.EquipSlot.ARMOR)
	_assert(armor != null, "T2a leather_armor 实例可装备")
	if armor == null:
		_cleanup_unit(unit)
		return
	await process_frame

	var defense := ATTRIBUTE_RESOLVER.get_defense(unit)
	var max_hp := ATTRIBUTE_RESOLVER.get_max_hp(unit)
	_assert(int(defense["sources"].get("equipment", -1)) == 3, "T2b leather_armor defense.equipment=3")
	_assert(int(max_hp["sources"].get("equipment", -1)) == 10, "T2c leather_armor max_hp.equipment=10")

	_cleanup_unit(unit)


func _test_accessory_hp_modifier() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	var pendant := _equip_item(state, JADE_PENDANT.id, ITEM_DATA.EquipSlot.ACCESSORY_1)
	_assert(pendant != null, "T3a jade_pendant 实例可装备")
	if pendant == null:
		_cleanup_unit(unit)
		return
	await process_frame

	var max_hp := ATTRIBUTE_RESOLVER.get_max_hp(unit)
	_assert(int(max_hp["sources"].get("equipment", -1)) == 20, "T3b jade_pendant max_hp.equipment=20")

	_cleanup_unit(unit)


func _test_multi_equipment_stack() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	var blade := _equip_item(state, IRON_BLADE.id, ITEM_DATA.EquipSlot.WEAPON)
	var armor := _equip_item(state, LEATHER_ARMOR.id, ITEM_DATA.EquipSlot.ARMOR)
	var pendant := _equip_item(state, JADE_PENDANT.id, ITEM_DATA.EquipSlot.ACCESSORY_1)
	_assert(blade != null and armor != null and pendant != null, "T4a 三件装备都已装上")
	await process_frame

	var attack := ATTRIBUTE_RESOLVER.get_attack(unit)
	var defense := ATTRIBUTE_RESOLVER.get_defense(unit)
	var max_hp := ATTRIBUTE_RESOLVER.get_max_hp(unit)
	_assert(int(attack["sources"].get("equipment", -1)) == 5, "T4b 多件叠加 attack.equipment=5")
	_assert(int(defense["sources"].get("equipment", -1)) == 3, "T4c 多件叠加 defense.equipment=3")
	_assert(int(max_hp["sources"].get("equipment", -1)) == 30, "T4d 多件叠加 max_hp.equipment=30")

	_cleanup_unit(unit)


func _test_unequip_clears_equipment_source() -> void:
	var state := _get_game_state()
	if state == null:
		return
	state.reset()

	var unit := await _spawn_unit()
	var blade := _equip_item(state, IRON_BLADE.id, ITEM_DATA.EquipSlot.WEAPON)
	var armor := _equip_item(state, LEATHER_ARMOR.id, ITEM_DATA.EquipSlot.ARMOR)
	var pendant := _equip_item(state, JADE_PENDANT.id, ITEM_DATA.EquipSlot.ACCESSORY_1)
	_assert(blade != null and armor != null and pendant != null, "T5a 先装备三件成功")
	state.unequip(XU_FENGNIAN.unit_id, ITEM_DATA.EquipSlot.WEAPON)
	state.unequip(XU_FENGNIAN.unit_id, ITEM_DATA.EquipSlot.ARMOR)
	state.unequip(XU_FENGNIAN.unit_id, ITEM_DATA.EquipSlot.ACCESSORY_1)
	await process_frame

	var attack := ATTRIBUTE_RESOLVER.get_attack(unit)
	var defense := ATTRIBUTE_RESOLVER.get_defense(unit)
	var max_hp := ATTRIBUTE_RESOLVER.get_max_hp(unit)
	_assert(int(attack["sources"].get("equipment", -1)) == 0, "T5b 卸下后 attack.equipment=0")
	_assert(int(defense["sources"].get("equipment", -1)) == 0, "T5c 卸下后 defense.equipment=0")
	_assert(int(max_hp["sources"].get("equipment", -1)) == 0, "T5d 卸下后 max_hp.equipment=0")

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


func _equip_item(state: Node, item_id: String, slot: int) -> ItemInstance:
	state.inventory.add(item_id)
	var instance := _find_unique_item(state, item_id)
	if instance == null:
		return null
	if not state.equip(XU_FENGNIAN.unit_id, slot, instance):
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
	print("[test_equip_modifier] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
