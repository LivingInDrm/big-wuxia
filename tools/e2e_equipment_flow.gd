extends SceneTree

const VIEWPORT := Vector2i(1600, 900)
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu/main_menu.tscn"
const LEVEL_SELECT_SCENE_PATH := "res://scenes/level_select/level_select.tscn"
const CHARACTER_PANEL_SCENE_PATH := "res://scenes/character_panel/character_panel.tscn"
const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const UNIT_SCENE: PackedScene = preload("res://scenes/unit/unit.tscn")
const ItemData = preload("res://scripts/core/item_data.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")
const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")
const JIANG_NI = preload("res://resources/data/units/jiang_ni.tres")
const SHOT_PANEL_BEFORE := "res://tools/screenshots/p3_e2e_equipment_01_before.png"
const SHOT_PANEL_AFTER := "res://tools/screenshots/p3_e2e_equipment_02_after.png"

var _pass: int = 0
var _fail: int = 0
var _capture_screenshots: bool = false


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).to_lower() == "shots":
			_capture_screenshots = true
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT)
	change_scene_to_file(MAIN_MENU_SCENE_PATH)
	await _wait_for_scene(MAIN_MENU_SCENE_PATH)

	var game_state := root.get_node_or_null("GameState")
	_assert(game_state != null, "T0 GameState autoload 存在")
	if game_state == null:
		_finish()
		return

	await _click_control(_must_find_button(current_scene, "StartButton"))
	await _wait_for_scene(LEVEL_SELECT_SCENE_PATH)

	_assert_equipped_item(game_state, "xu_fengnian", ItemData.EquipSlot.WEAPON, "iron_blade",
		"T1a 初始徐凤年装备 iron_blade")
	_assert_equipped_item(game_state, "li_chungang", ItemData.EquipSlot.WEAPON, "plain_sword",
		"T1b 初始李淳罡装备 plain_sword")
	_assert_equipped_item(game_state, "jiang_ni", ItemData.EquipSlot.ARMOR, "cloth_robe",
		"T1c 初始姜泥装备 cloth_robe")

	change_scene_to_file(CHARACTER_PANEL_SCENE_PATH)
	await _wait_for_scene(CHARACTER_PANEL_SCENE_PATH)

	var panel := current_scene
	await _exercise_xu_weapon_toggle(panel, game_state)
	await _exercise_jiang_accessory(panel, game_state)
	change_scene_to_file(LEVEL_SELECT_SCENE_PATH)
	await _wait_for_scene(LEVEL_SELECT_SCENE_PATH)
	game_state.start_level("level_01")
	change_scene_to_file(BATTLE_SCENE_PATH)
	await _wait_for_scene(BATTLE_SCENE_PATH, 480)
	await _wait_frames(20)

	await _exercise_battle_damage(current_scene)
	_finish()


func _exercise_xu_weapon_toggle(panel: Node, game_state: Node) -> void:
	var xu_button := panel.call("get_character_button", "xu_fengnian") as Button
	var weapon_button := panel.call("get_slot_button", ItemData.EquipSlot.WEAPON) as Button
	_assert(xu_button != null and weapon_button != null, "T2a 徐凤年按钮与武器槽存在")
	if xu_button == null or weapon_button == null:
		return

	await _click_control(xu_button)
	await _wait_frames(8)
	_assert(String(panel.call("get_slot_item_name", ItemData.EquipSlot.WEAPON)).contains("铁刀"),
		"T2b 角色面板显示铁刀")
	_assert(String(panel.call("get_basic_stat_text", "attack")).begins_with("33"),
		"T2c 徐凤年装备时 attack=33")

	if _capture_screenshots:
		await _save_png(SHOT_PANEL_BEFORE)

	await _click_control(weapon_button)
	await _wait_frames(8)
	var option_list := _must_find_node(panel, "OptionList") as ItemList
	if option_list != null and option_list.item_count < 1:
		await _click_world(weapon_button.get_global_rect().position + Vector2(48, weapon_button.size.y * 0.5))
		await _wait_frames(8)
	await _wait_for_item_list_count(option_list, 1)
	_assert(option_list != null and option_list.item_count >= 1, "T2d 武器弹窗条目可见")
	if option_list == null or option_list.item_count < 1:
		return
	await _click_item_list_index(option_list, 0)
	await _wait_frames(8)

	_assert(game_state.get_equipped_items("xu_fengnian").get(ItemData.EquipSlot.WEAPON) == null,
		"T2e 徐凤年卸下武器后 equipped[WEAPON]=null")
	_assert(String(panel.call("get_basic_stat_text", "attack")).begins_with("28"),
		"T2f 徐凤年卸刀后 attack 回落到 28")
	if _capture_screenshots:
		await _save_png(SHOT_PANEL_AFTER)

	await _click_control(weapon_button)
	await _wait_frames(8)
	option_list = _must_find_node(panel, "OptionList") as ItemList
	if option_list != null and option_list.item_count < 1:
		await _click_world(weapon_button.get_global_rect().position + Vector2(48, weapon_button.size.y * 0.5))
		await _wait_frames(8)
	await _wait_for_item_list_count(option_list, 1)
	_assert(option_list != null and option_list.item_count >= 1, "T2g 重新装备时武器列表存在")
	if option_list == null or option_list.item_count < 1:
		return
	var iron_index := _find_item_index(option_list, "铁刀")
	_assert(iron_index != -1, "T2h 武器列表包含铁刀")
	if iron_index == -1:
		return
	await _click_item_list_index(option_list, iron_index)
	await _wait_frames(8)

	var iron_blade := game_state.get_equipped_items("xu_fengnian").get(ItemData.EquipSlot.WEAPON) as ItemInstance
	_assert(iron_blade != null and iron_blade.item_data != null and iron_blade.item_data.id == "iron_blade",
		"T2i 徐凤年重新装备 iron_blade")
	_assert(String(panel.call("get_basic_stat_text", "attack")).begins_with("33"),
		"T2j 徐凤年重新装备后 attack 恢复 33")


func _exercise_jiang_accessory(panel: Node, game_state: Node) -> void:
	game_state.inventory.add("jade_pendant")
	var jiang_unit := await _spawn_monitor_unit(JIANG_NI)
	_assert(jiang_unit != null, "T3a 姜泥监视 Unit 可实例化")
	if jiang_unit == null:
		return
	jiang_unit.current_hp = 68
	jiang_unit._refresh_health_bar()

	var jiang_button := panel.call("get_character_button", "jiang_ni") as Button
	var acc1_button := panel.call("get_slot_button", ItemData.EquipSlot.ACCESSORY_1) as Button
	_assert(jiang_button != null and acc1_button != null, "T3b 姜泥按钮与 ACC_1 存在")
	if jiang_button == null or acc1_button == null:
		jiang_unit.queue_free()
		return

	await _click_control(jiang_button)
	await _wait_frames(8)
	_assert(String(panel.call("get_basic_stat_text", "max_hp")).begins_with("85"),
		"T3c 姜泥初始 max_hp=85")
	_assert(jiang_unit.get_max_hp() == 85 and jiang_unit.current_hp == 68,
		"T3d 姜泥监视 Unit 初始 68/85")

	await _click_control(acc1_button)
	await _wait_frames(8)
	var option_list := _must_find_node(panel, "OptionList") as ItemList
	_assert(option_list != null and option_list.item_count >= 1, "T3e ACC_1 可选条目存在")
	if option_list == null or option_list.item_count < 1:
		jiang_unit.queue_free()
		return
	var pendant_index := _find_item_index(option_list, "玉佩")
	_assert(pendant_index != -1, "T3f ACC_1 列表包含玉佩")
	if pendant_index == -1:
		jiang_unit.queue_free()
		return
	await _click_item_list_index(option_list, pendant_index)
	await _wait_frames(8)

	var pendant := game_state.get_equipped_items("jiang_ni").get(ItemData.EquipSlot.ACCESSORY_1) as ItemInstance
	_assert(pendant != null and pendant.item_data != null and pendant.item_data.id == "jade_pendant",
		"T3g 姜泥 ACC_1 装备 jade_pendant")
	_assert(String(panel.call("get_basic_stat_text", "max_hp")).begins_with("105"),
		"T3h 姜泥装备后 max_hp=105")
	_assert(jiang_unit.get_max_hp() == 105 and jiang_unit.current_hp == 84,
		"T3i 姜泥 68/85 装备后按比例上浮到 84/105")

	await _click_control(acc1_button)
	await _wait_frames(8)
	option_list = _must_find_node(panel, "OptionList") as ItemList
	_assert(option_list != null and option_list.item_count >= 1, "T3j 卸下玉佩选项存在")
	if option_list == null or option_list.item_count < 1:
		jiang_unit.queue_free()
		return
	await _click_item_list_index(option_list, 0)
	await _wait_frames(8)

	_assert(game_state.get_equipped_items("jiang_ni").get(ItemData.EquipSlot.ACCESSORY_1) == null,
		"T3k 姜泥卸下玉佩后 ACC_1 为空")
	_assert(String(panel.call("get_basic_stat_text", "max_hp")).begins_with("85"),
		"T3l 姜泥卸下后 max_hp 回落到 85")
	_assert(jiang_unit.get_max_hp() == 85 and jiang_unit.current_hp == 68,
		"T3m 姜泥卸下后 current_hp 按比例 clamp 回 68/85")
	jiang_unit.queue_free()
	await _wait_frames(2)


func _exercise_battle_damage(battle: Node) -> void:
	var xu: Unit = battle.get_player_units()[0]
	var enemy: Unit = battle.get_enemy_units()[0]
	_assert(xu != null and enemy != null, "T5a 战斗双方单位存在")
	if xu == null or enemy == null:
		return

	var attack_result: Dictionary = AttributeResolver.get_attack(xu)
	var equipment_attack := int(attack_result.get("sources", {}).get("equipment", -1))
	var equipped_attack := int(attack_result.get("total", -1))
	var baseline_damage: int = max(1, 28 - int(AttributeResolver.get_defense(enemy).get("total", 0)))
	_assert(equipment_attack == 5, "T5b 徐凤年 battle attack.equipment=5")
	_assert(equipped_attack == 33, "T5c 徐凤年 battle attack.total=33")

	await _click_world(_world_to_screen(xu.global_position, battle))
	await _wait_frames(10)
	_assert(battle.selected_unit == xu, "T5d 点击徐凤年后进入选中状态")

	var move_target := Vector2i(3, 2)
	_assert(battle.current_move_range.has(move_target), "T5e 移动目标 (3,2) 在 move_range 内")
	await _click_world(_cell_to_screen(move_target, battle))
	await _wait_frames(140)

	_assert(xu.current_position == move_target, "T5f 徐凤年移动到 (3,2)")
	_assert(battle.current_attack_range.has(enemy.current_position), "T5g 敌兵进入攻击范围")
	var enemy_hp_before := enemy.current_hp
	await _click_world(_world_to_screen(enemy.global_position, battle))
	await _wait_frames(120)

	var actual_damage := enemy_hp_before - enemy.current_hp
	_assert(actual_damage == baseline_damage + 5, "T5h 实际伤害=裸值基线+5 (%d vs %d)" % [actual_damage, baseline_damage])
	_assert(actual_damage == 26, "T5i 徐凤年对 enemy_soldier 实际伤害=26")
	_assert(xu.acted, "T5j 徐凤年攻击后 acted=true")


func _spawn_monitor_unit(unit_data) -> Unit:
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(unit_data, Vector2i(99, 99))
	root.add_child(unit)
	await process_frame
	unit.position = Vector2(-4096, -4096)
	return unit


func _assert_equipped_item(game_state: Node, char_id: String, slot: int, expected_item_id: String,
		msg: String) -> void:
	var item_instance := game_state.get_equipped_items(char_id).get(slot) as ItemInstance
	_assert(item_instance != null and item_instance.item_data != null
		and item_instance.item_data.id == expected_item_id, msg)


func _must_find_button(root_node: Node, node_name: String) -> Button:
	var button := root_node.find_child(node_name, true, false) as Button
	_assert(button != null, "节点 %s 可定位" % node_name)
	return button


func _must_find_node(root_node: Node, node_name: String) -> Node:
	var node := root_node.find_child(node_name, true, false)
	_assert(node != null, "节点 %s 可定位" % node_name)
	return node


func _find_item_index(item_list: ItemList, keyword: String) -> int:
	for index in item_list.item_count:
		if item_list.get_item_text(index).contains(keyword):
			return index
	return -1


func _click_control(control: Control) -> void:
	if control == null:
		return
	await _click_world(control.get_global_rect().get_center())


func _click_item_list_index(item_list: ItemList, index: int) -> void:
	var item_rect := item_list.get_item_rect(index)
	var screen_pos := item_list.global_position + item_rect.position + item_rect.size * 0.5
	await _click_world(screen_pos)


func _click_world(screen_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	root.push_input(press, true)
	await process_frame
	await physics_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_pos
	release.global_position = screen_pos
	root.push_input(release, true)
	await process_frame
	await physics_frame


func _wait_for_scene(scene_path: String, max_frames: int = 360) -> void:
	for _i in max_frames:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == scene_path:
			await _wait_frames(8)
			return
	_assert(false, "等待场景超时: %s" % scene_path)


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _wait_for_item_list_count(item_list: ItemList, min_count: int, max_frames: int = 45) -> void:
	if item_list == null:
		return
	for _i in max_frames:
		if item_list.item_count >= min_count:
			return
		await process_frame


func _world_to_screen(world_pos: Vector2, battle: Node) -> Vector2:
	return battle.get_viewport().get_canvas_transform() * world_pos


func _cell_to_screen(cell: Vector2i, battle: Node) -> Vector2:
	var world_pos := Vector2(cell.x * 64 + 32, cell.y * 64 + 32)
	return _world_to_screen(world_pos, battle)


func _save_png(res_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path(res_path)
	var err := image.save_png(abs_path)
	_assert(err == OK, "保存截图成功: %s" % abs_path)


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		push_error("  [FAIL] %s" % msg)


func _finish() -> void:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	print("[e2e_equipment_flow] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
