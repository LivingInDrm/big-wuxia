extends SceneTree

const Inventory = preload("res://scripts/core/inventory.gd")
const ItemData = preload("res://scripts/core/item_data.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")
var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_inventory] ==== BEGIN ====")

	_test_stackable_add_and_remove()
	_test_unique_instances()
	_test_category_filters()
	_test_missing_item_behaviors()
	_test_game_state_inventory_reset()

	_finish()


func _test_stackable_add_and_remove() -> void:
	var inventory := Inventory.new()
	inventory.add("jinchuang_yao")
	inventory.add("jinchuang_yao")
	inventory.add("jinchuang_yao")

	_assert(inventory.count("jinchuang_yao") == 3, "T1a 金疮药 add 3 次后 count=3")
	_assert(inventory.has("jinchuang_yao"), "T1b 金疮药 has=true")

	var removed := inventory.remove("jinchuang_yao", 2)
	_assert(removed, "T1c 金疮药 remove 2 成功")
	_assert(inventory.count("jinchuang_yao") == 1, "T1d 金疮药剩余 count=1")


func _test_unique_instances() -> void:
	var inventory := Inventory.new()
	inventory.add("iron_blade", 2)

	_assert(inventory.unique_items.size() == 2, "T2a 铁刀 add 2 次后 unique_items 长度=2")
	_assert(inventory.count("iron_blade") == 2, "T2b 铁刀 count=2")

	var first := inventory.unique_items[0] as ItemInstance
	var second := inventory.unique_items[1] as ItemInstance
	_assert(first != null and second != null, "T2c unique_items 都是 ItemInstance")
	if first != null and second != null:
		_assert(first.instance_id != second.instance_id,
			"T2d 两个铁刀实例 instance_id 不同 (%d != %d)" % [first.instance_id, second.instance_id])


func _test_category_filters() -> void:
	var inventory := Inventory.new()
	inventory.add("jinchuang_yao", 3)
	inventory.add("iron_blade", 2)
	inventory.add("misc_caoyao", 5)

	var consumables := inventory.list_by_category(ItemData.ItemCategory.CONSUMABLE)
	_assert(consumables.size() == 1, "T3a CONSUMABLE 只返回 1 条")
	if consumables.size() == 1:
		var entry = consumables[0]
		_assert(entry is Dictionary, "T3b CONSUMABLE 返回堆叠字典")
		if entry is Dictionary:
			_assert(entry["item_data"].id == "jinchuang_yao", "T3c CONSUMABLE 只含金疮药")
			_assert(int(entry["count"]) == 3, "T3d 金疮药 count=3")

	var equipments := inventory.list_by_category(ItemData.ItemCategory.EQUIPMENT)
	_assert(equipments.size() == 2, "T3e EQUIPMENT 返回 2 个独立实例")
	if equipments.size() == 2:
		_assert(equipments[0] is ItemInstance and equipments[1] is ItemInstance,
			"T3f EQUIPMENT 全部为 ItemInstance")
		if equipments[0] is ItemInstance and equipments[1] is ItemInstance:
			_assert(equipments[0].item_data.id == "iron_blade" and equipments[1].item_data.id == "iron_blade",
				"T3g EQUIPMENT 两项都为 iron_blade")


func _test_missing_item_behaviors() -> void:
	var inventory := Inventory.new()
	_assert(not inventory.has("missing_item"), "T4a 不存在物品 has=false")
	_assert(not inventory.remove("missing_item"), "T4b 不存在物品 remove=false")


func _test_game_state_inventory_reset() -> void:
	var state := root.get_node_or_null("GameState")
	_assert(state != null, "T5a /root/GameState 存在")
	if state == null:
		return

	_assert(state.inventory is Inventory, "T5b GameState.inventory 已挂载")
	state.inventory.add("jinchuang_yao", 2)
	_assert(state.inventory.count("jinchuang_yao") == 2, "T5c GameState.inventory 可 add")

	state.reset()
	_assert(state.inventory != null, "T5d reset 后 inventory 非 null")
	_assert(state.inventory.count("jinchuang_yao") == 0, "T5e reset 后背包清空")


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_inventory] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
