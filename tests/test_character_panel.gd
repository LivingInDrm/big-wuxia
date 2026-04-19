extends SceneTree

const CHARACTER_PANEL_SCENE = preload("res://scenes/character_panel/character_panel.tscn")
const CHARACTER_PANEL_SCRIPT = preload("res://scenes/character_panel/character_panel.gd")
const ItemData = preload("res://scripts/core/item_data.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")

var _pass: int = 0
var _fail: int = 0
var _change_scene_calls: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_character_panel] ==== BEGIN ====")

	var scene_manager := root.get_node_or_null("SceneManager")
	var game_state := root.get_node_or_null("GameState")
	_assert(scene_manager != null, "T0a /root/SceneManager 存在")
	_assert(game_state != null, "T0b /root/GameState 存在")
	if scene_manager == null or game_state == null:
		_finish()
		return

	scene_manager.set_script(load("res://tests/helpers/scene_manager_spy.gd"))
	scene_manager.set_meta("spy_change_scene", Callable(self, "_spy_on_change_scene"))

	game_state.reset()
	game_state.inventory.add("heal_amulet")

	var panel = CHARACTER_PANEL_SCENE.instantiate()
	root.add_child(panel)
	await process_frame
	await process_frame

	_assert(panel != null, "T1a CharacterPanel 可实例化")
	_assert(await _test_switch_character(panel), "T1b 切换角色后中右列更新")
	_assert(await _test_popup_and_equip(panel, game_state), "T1c 弹窗装备与卸下流程正常")
	_assert(await _test_return_button(panel), "T1d 返回按钮触发切场景")

	panel.queue_free()
	await process_frame
	_finish()


func _test_switch_character(panel: Node) -> bool:
	var jiang_button := panel.call("get_character_button", "jiang_ni") as Button
	var current_name := panel.get_node_or_null("RootMargin/RootVBox/Content/EquipmentCard/Margin/VBox/CurrentCharacterLabel") as Label
	if jiang_button == null or current_name == null:
		_assert(false, "T2a 切换角色所需节点存在")
		return false

	jiang_button.pressed.emit()
	await process_frame

	var ok := true
	ok = ok and current_name.text.contains("姜泥")
	ok = ok and String(panel.call("get_slot_item_name", ItemData.EquipSlot.ARMOR)).contains("布袍")
	ok = ok and String(panel.call("get_basic_stat_text", "attack")).begins_with("8")
	_assert(ok, "T2b 切到姜泥后标题/护甲/属性刷新")
	return ok


func _test_popup_and_equip(panel: Node, game_state: Node) -> bool:
	var xu_button := panel.call("get_character_button", "xu_fengnian") as Button
	var acc1_button := panel.call("get_slot_button", ItemData.EquipSlot.ACCESSORY_1) as Button
	var popup := panel.get_node_or_null("EquipSelectPopup") as Control
	var option_list := popup.get_node_or_null("Center/PopupPanel/Margin/VBox/OptionList") as ItemList if popup != null else null
	if xu_button == null or acc1_button == null or popup == null or option_list == null:
		_assert(false, "T3a 装备流程所需节点存在")
		return false

	xu_button.pressed.emit()
	await process_frame

	var base_hp := String(panel.call("get_basic_stat_text", "max_hp"))
	acc1_button.pressed.emit()
	await process_frame
	_assert(popup.visible, "T3b 点击装备槽后弹窗出现")
	if option_list.item_count < 1:
		_assert(false, "T3c 弹窗内至少有 1 个条目")
		return false

	option_list.item_selected.emit(0)
	await process_frame

	var equipped := game_state.get_equipped_items("xu_fengnian").get(ItemData.EquipSlot.ACCESSORY_1) as ItemInstance
	var ok := equipped != null and equipped.item_data != null and equipped.item_data.id == "heal_amulet"
	ok = ok and String(panel.call("get_slot_item_name", ItemData.EquipSlot.ACCESSORY_1)).contains("养息护符")
	ok = ok and String(panel.call("get_basic_stat_text", "max_hp")) != base_hp
	_assert(ok, "T3d 选择装备后 equipped 与属性刷新")

	acc1_button.pressed.emit()
	await process_frame
	option_list.item_selected.emit(0)
	await process_frame

	var after_unequip := game_state.get_equipped_items("xu_fengnian").get(ItemData.EquipSlot.ACCESSORY_1) as ItemInstance
	var found_back := false
	for entry in game_state.inventory.unique_items:
		var item_instance := entry as ItemInstance
		if item_instance != null and item_instance.item_data != null and item_instance.item_data.id == "heal_amulet":
			found_back = true
			break
	ok = after_unequip == null and found_back and String(panel.call("get_basic_stat_text", "max_hp")) == base_hp
	_assert(ok, "T3e 卸下后回背包且属性回落")
	return ok


func _test_return_button(panel: Node) -> bool:
	var return_button := panel.get_node_or_null("RootMargin/RootVBox/Header/ReturnButton") as Button
	if return_button == null:
		_assert(false, "T4a ReturnButton 存在")
		return false
	_change_scene_calls.clear()
	return_button.pressed.emit()
	await process_frame
	var ok := _change_scene_calls.size() == 1 and _change_scene_calls[0] == CHARACTER_PANEL_SCRIPT.LEVEL_SELECT_SCENE
	_assert(ok, "T4b 点击返回后跳回选关")
	return ok


func _spy_on_change_scene(path: String) -> void:
	_change_scene_calls.append(path)


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_character_panel] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
