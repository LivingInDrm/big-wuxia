extends SceneTree

const GameStateScript = preload("res://autoload/game_state.gd")
const ItemData = preload("res://scripts/core/item_data.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")
const XU_FENGNIAN = preload("res://resources/data/units/xu_fengnian.tres")
const JIANG_NI = preload("res://resources/data/units/jiang_ni.tres")
const LI_CHUNGANG = preload("res://resources/data/units/li_chungang.tres")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_equipment_api] ==== BEGIN ====")

	_test_equip_success()
	_test_swap_returns_old_item_to_inventory()
	_test_unequip_returns_item_to_inventory()
	_test_weapon_type_mismatch_rejected()
	_test_slot_mismatch_rejected()
	_test_unequip_empty_slot_returns_null()
	_test_reset_reinitializes_equipped()

	_finish()


func _test_equip_success() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()
	state.inventory.add("iron_blade")
	var blade := _find_unique_item(state.inventory, "iron_blade")
	_assert(blade != null, "T1a iron_blade instance 创建成功")
	if blade == null:
		return

	var ok: bool = state.equip("xu_fengnian", ItemData.EquipSlot.WEAPON, blade)
	_assert(ok, "T1b equip 徐凤年 weapon 成功")

	var equipped: Dictionary = state.get_equipped_items("xu_fengnian")
	_assert(equipped.get(ItemData.EquipSlot.WEAPON) == blade, "T1c equipped.weapon 挂上 iron_blade")
	_assert(state.inventory.count("iron_blade") == 0, "T1d equip 后 inventory 不再保留 iron_blade")
	_assert(not _inventory_has_instance(state.inventory, blade.instance_id), "T1e equip 后实例已从 unique_items 移除")


func _test_swap_returns_old_item_to_inventory() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()
	state.inventory.add("iron_blade", 2)
	var first := state.inventory.unique_items[0] as ItemInstance
	var second := state.inventory.unique_items[1] as ItemInstance
	_assert(first != null and second != null, "T2a 两把 iron_blade 实例存在")
	if first == null or second == null:
		return

	_assert(state.equip("xu_fengnian", ItemData.EquipSlot.WEAPON, first), "T2b 首次装备成功")
	_assert(state.equip("xu_fengnian", ItemData.EquipSlot.WEAPON, second), "T2c 换装第二把成功")

	var equipped: Dictionary = state.get_equipped_items("xu_fengnian")
	_assert(equipped.get(ItemData.EquipSlot.WEAPON) == second, "T2d weapon 槽已换成第二把")
	_assert(state.inventory.count("iron_blade") == 1, "T2e 换装后 inventory 留下一把 iron_blade")
	_assert(_inventory_has_instance(state.inventory, first.instance_id), "T2f 旧武器已回到 inventory")
	_assert(not _inventory_has_instance(state.inventory, second.instance_id), "T2g 新武器不在 inventory")


func _test_unequip_returns_item_to_inventory() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()
	state.inventory.add("iron_blade")
	var blade := _find_unique_item(state.inventory, "iron_blade")
	_assert(blade != null, "T3a iron_blade instance 可用于卸装测试")
	if blade == null:
		return

	_assert(state.equip("xu_fengnian", ItemData.EquipSlot.WEAPON, blade), "T3b 先装备成功")
	var removed: ItemInstance = state.unequip("xu_fengnian", ItemData.EquipSlot.WEAPON)
	_assert(removed == blade, "T3c unequip 返回原实例")

	var equipped: Dictionary = state.get_equipped_items("xu_fengnian")
	_assert(equipped.get(ItemData.EquipSlot.WEAPON) == null, "T3d unequip 后 weapon 槽为 null")
	_assert(state.inventory.count("iron_blade") == 1, "T3e unequip 后物品回到 inventory")
	_assert(_inventory_has_instance(state.inventory, blade.instance_id), "T3f unequip 后实例可在 inventory 找到")


func _test_weapon_type_mismatch_rejected() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()
	state.inventory.add("iron_blade")
	state.inventory.add("plain_sword")

	var blade := _find_unique_item(state.inventory, "iron_blade")
	var sword := _find_unique_item(state.inventory, "plain_sword")
	_assert(blade != null and sword != null, "T4a blade/sword 实例存在")
	if blade == null or sword == null:
		return

	_assert(state.equip("xu_fengnian", ItemData.EquipSlot.WEAPON, blade), "T4b 徐凤年先装刀成功")
	var before_count: int = state.inventory.count("plain_sword")
	var ok: bool = state.equip("xu_fengnian", ItemData.EquipSlot.WEAPON, sword)
	_assert(not ok, "T4c 徐凤年装 plain_sword 被拒绝")

	var equipped: Dictionary = state.get_equipped_items("xu_fengnian")
	_assert(equipped.get(ItemData.EquipSlot.WEAPON) == blade, "T4d weapon_type 不匹配时原装备不变")
	_assert(state.inventory.count("plain_sword") == before_count, "T4e plain_sword 仍留在 inventory")
	_assert(_inventory_has_instance(state.inventory, sword.instance_id), "T4f sword 实例未被移出 inventory")


func _test_slot_mismatch_rejected() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()
	state.inventory.add("leather_armor")
	var armor := _find_unique_item(state.inventory, "leather_armor")
	_assert(armor != null, "T5a leather_armor instance 创建成功")
	if armor == null:
		return

	var ok: bool = state.equip("xu_fengnian", ItemData.EquipSlot.WEAPON, armor)
	_assert(not ok, "T5b armor 装到 WEAPON 槽被拒绝")

	var equipped: Dictionary = state.get_equipped_items("xu_fengnian")
	_assert(equipped.get(ItemData.EquipSlot.WEAPON) == null, "T5c slot 不匹配时 weapon 槽保持 null")
	_assert(state.inventory.count("leather_armor") == 1, "T5d slot 不匹配时 armor 仍在 inventory")


func _test_unequip_empty_slot_returns_null() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()
	var removed: ItemInstance = state.unequip("xu_fengnian", ItemData.EquipSlot.ARMOR)
	_assert(removed == null, "T6a 空槽 unequip 返回 null")


func _test_reset_reinitializes_equipped() -> void:
	var state := _get_game_state()
	if state == null:
		return

	state.reset()
	state.inventory.add("iron_blade")
	var blade := _find_unique_item(state.inventory, "iron_blade")
	_assert(blade != null, "T7a reset 测试物品创建成功")
	if blade != null:
		_assert(state.equip("xu_fengnian", ItemData.EquipSlot.WEAPON, blade), "T7b reset 前可先装备")

	state.reset()
	_assert(state.inventory.unique_items.is_empty(), "T7c reset 后 inventory.unique_items 清空")
	_assert(state.equipped.has(XU_FENGNIAN.unit_id), "T7d reset 初始化 xu_fengnian equipped")
	_assert(state.equipped.has(JIANG_NI.unit_id), "T7e reset 初始化 jiang_ni equipped")
	_assert(state.equipped.has(LI_CHUNGANG.unit_id), "T7f reset 初始化 li_chungang equipped")
	_assert_all_slots_null(state.get_equipped_items(XU_FENGNIAN.unit_id), "T7g xu_fengnian 四槽全 null")
	_assert_all_slots_null(state.get_equipped_items(JIANG_NI.unit_id), "T7h jiang_ni 四槽全 null")
	_assert_all_slots_null(state.get_equipped_items(LI_CHUNGANG.unit_id), "T7i li_chungang 四槽全 null")


func _get_game_state() -> Node:
	var state := root.get_node_or_null("GameState")
	_assert(state != null, "GameState autoload 存在")
	return state


func _find_unique_item(inventory, item_id: String) -> ItemInstance:
	for instance in inventory.unique_items:
		var unique := instance as ItemInstance
		if unique != null and unique.item_data != null and unique.item_data.id == item_id:
			return unique
	return null


func _inventory_has_instance(inventory, instance_id: int) -> bool:
	for instance in inventory.unique_items:
		var unique := instance as ItemInstance
		if unique != null and unique.instance_id == instance_id:
			return true
	return false


func _assert_all_slots_null(items: Dictionary, msg: String) -> void:
	var all_null := (
		items.get(ItemData.EquipSlot.WEAPON) == null
		and items.get(ItemData.EquipSlot.ARMOR) == null
		and items.get(ItemData.EquipSlot.ACCESSORY_1) == null
		and items.get(ItemData.EquipSlot.ACCESSORY_2) == null
	)
	_assert(all_null, msg)


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_equipment_api] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
