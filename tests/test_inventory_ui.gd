extends SceneTree

const INVENTORY_PANEL_SCENE = preload("res://scenes/inventory/inventory_panel.tscn")
const INVENTORY_SCRIPT = preload("res://scripts/core/inventory.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_inventory_ui] ==== BEGIN ====")
	await _test_panel_renders_and_switches_tabs()
	_finish()


func _test_panel_renders_and_switches_tabs() -> void:
	var inventory = INVENTORY_SCRIPT.new()
	inventory.add("jinchuang_yao", 3)
	inventory.add("jiedu_dan", 1)
	inventory.add("iron_blade", 2)
	inventory.add("chunqiu_daofa", 1)

	var panel = INVENTORY_PANEL_SCENE.instantiate()
	panel.set_inventory_source(inventory)
	root.add_child(panel)
	await process_frame
	await process_frame

	_assert(panel != null, "T1a InventoryPanel 可实例化")
	var item_grid := panel.get_node_or_null("RootMargin/RootVBox/Content/ListCard/Margin/VBox/ItemsScroll/ItemGrid") as GridContainer
	var equipment_tab := panel.get_node_or_null("RootMargin/RootVBox/TabBar/EquipmentTab") as Button
	var quest_tab := panel.get_node_or_null("RootMargin/RootVBox/TabBar/QuestTab") as Button
	var detail_name := panel.get_node_or_null("RootMargin/RootVBox/Content/DetailCard/Margin/VBox/DetailNameLabel") as Label
	var empty_label := panel.get_node_or_null("RootMargin/RootVBox/Content/ListCard/Margin/VBox/EmptyLabel") as Label
	_assert(item_grid != null, "T1b ItemGrid 存在")
	_assert(equipment_tab != null, "T1c EquipmentTab 存在")
	_assert(detail_name != null, "T1d DetailNameLabel 存在")

	if item_grid != null:
		_assert(item_grid.get_child_count() == 2, "T2 默认消耗品 Tab 渲染 2 个格子")

	if equipment_tab != null and item_grid != null:
		equipment_tab.pressed.emit()
		await process_frame
		_assert(item_grid.get_child_count() == 2, "T3 切到装备 Tab 后渲染 2 个独立格子")

	if item_grid != null and item_grid.get_child_count() > 0 and detail_name != null:
		var first_item := item_grid.get_child(0) as Button
		_assert(first_item != null, "T4a 装备格子按钮存在")
		if first_item != null:
			first_item.pressed.emit()
			await process_frame
			_assert(detail_name.text.contains("铁刀"), "T4b 点击物品后详情包含物品名")

	if quest_tab != null and item_grid != null and empty_label != null:
		quest_tab.pressed.emit()
		await process_frame
		_assert(item_grid.get_child_count() == 0, "T5a 空任务 Tab 没有格子")
		_assert(empty_label.visible and empty_label.text == "无", "T5b 空任务 Tab 显示 '无'")

	panel.queue_free()
	await process_frame
	_assert(true, "T6 基础渲染与销毁不崩")


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_inventory_ui] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
