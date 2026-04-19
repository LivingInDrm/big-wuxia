extends SceneTree

const VIEWPORT := Vector2i(1366, 768)
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const SHOT_BEFORE := "res://tools/screenshots/p2_item_use_01_before.png"
const SHOT_PANEL := "res://tools/screenshots/p2_item_use_02_panel.png"
const SHOT_AFTER := "res://tools/screenshots/p2_item_use_03_after.png"

var _mode: String = "after"
var _inventory_before: int = 0
var _inventory_after: int = 0
var _hp_before: int = 0
var _hp_after: int = 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_mode = String(args[0]).to_lower()
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT)
	change_scene_to_file(MAIN_MENU_SCENE)
	var game_state := root.get_node("/root/GameState")

	await _wait_for_scene_ready("MainMenu")
	var main_menu := current_scene as Control
	await _click_control_center(main_menu.get_node("%StartButton") as Control)

	await _wait_for_scene_ready("LevelSelect")
	var level_select := current_scene as Control
	var levels_container := level_select.get_node("%LevelsContainer") as VBoxContainer
	await _click_control_center(levels_container.get_child(0) as Control)

	await _wait_for_scene_ready("Battle")
	var battle = current_scene
	var xu: Unit = battle.get_player_units()[0]
	var item_button: Button = battle.ui.item_button

	await _click_screen(_world_to_screen(xu.global_position, battle))
	await _wait_frames(8)
	if battle.selected_unit != xu:
		push_error("[e2e_item_use] expected xu selected after click, got %s" % [
			battle.selected_unit.unit_data.unit_id if battle.selected_unit != null else "<null>",
		])
		quit(13)
		return
	if not item_button.disabled:
		push_error("[e2e_item_use] expected item button disabled with empty inventory")
		quit(2)
		return

	game_state.inventory.add("jinchuang_yao", 3)
	game_state.inventory.add("neili_dan", 1)
	battle.ui.refresh_items()
	_inventory_before = game_state.inventory.count("jinchuang_yao")
	if _inventory_before != 3:
		push_error("[e2e_item_use] expected injected jinchuang_yao count=3, got %d" % _inventory_before)
		quit(3)
		return

	await _wound_xu_for_demo(battle, xu)
	if xu.current_hp >= xu.max_hp:
		push_error("[e2e_item_use] failed to wound xu before item use")
		quit(4)
		return

	await _click_screen(_world_to_screen(xu.global_position, battle))
	await _wait_frames(10)
	if battle.selected_unit != xu:
		push_error("[e2e_item_use] expected xu reselected after wound, got %s" % [
			battle.selected_unit.unit_data.unit_id if battle.selected_unit != null else "<null>",
		])
		quit(14)
		return
	if item_button.disabled:
		push_error("[e2e_item_use] item button stayed disabled after inventory injection")
		quit(5)
		return

	_hp_before = xu.current_hp
	if _mode == "before":
		_save_png(SHOT_BEFORE)
		quit(0)
		return

	await _click_control_center(item_button)
	await _wait_frames(10)
	var panel = battle.ui.item_select_panel
	if not panel.visible:
		push_error("[e2e_item_use] item select panel did not open")
		quit(6)
		return
	if battle.select_state == battle.SelectState.ITEM_TARGETING:
		push_error("[e2e_item_use] item panel closed immediately after opening")
		quit(15)
		return
	if _mode == "panel":
		_save_png(SHOT_PANEL)
		quit(0)
		return

	var item_list: ItemList = panel.item_list
	var item_index := _find_item_index(item_list, "金疮药")
	if item_index == -1:
		push_error("[e2e_item_use] could not find 金疮药 in item list")
		quit(7)
		return
	await _click_item_list_index(item_list, item_index)
	await _wait_frames(8)

	if battle.select_state != battle.SelectState.ITEM_TARGETING:
		push_error("[e2e_item_use] expected ITEM_TARGETING after choosing item, got %s" % battle.select_state)
		quit(8)
		return

	await _click_screen(_world_to_screen(xu.global_position, battle))
	await _wait_frames(8)
	_hp_after = xu.current_hp
	_inventory_after = game_state.inventory.count("jinchuang_yao")
	if _hp_after <= _hp_before:
		push_error("[e2e_item_use] HP did not increase after item use (%d -> %d)" % [_hp_before, _hp_after])
		quit(9)
		return
	if _inventory_after != _inventory_before - 1:
		push_error("[e2e_item_use] inventory did not decrement (%d -> %d)" % [_inventory_before, _inventory_after])
		quit(10)
		return
	if not xu.acted:
		push_error("[e2e_item_use] xu should be marked acted after item use")
		quit(11)
		return

	if _mode == "after":
		_save_png(SHOT_AFTER)
	print("[e2e_item_use] PASS hp %d -> %d, jinchuang_yao %d -> %d" % [
		_hp_before, _hp_after, _inventory_before, _inventory_after,
	])
	quit(0)


func _wound_xu_for_demo(battle, xu: Unit) -> void:
	var enemy: Unit = battle.get_enemy_units()[0]
	for seed in [4, 7, 12, 19]:
		if xu.current_hp < xu.max_hp:
			return
		CombatSystem.reset_roll_seed(seed)
		await battle.debug_attack(enemy, xu)
		await _wait_frames(18)


func _find_item_index(item_list: ItemList, item_name: String) -> int:
	for index in item_list.item_count:
		if item_list.get_item_text(index).contains(item_name):
			return index
	return -1


func _click_item_list_index(item_list: ItemList, index: int) -> void:
	var item_rect := item_list.get_item_rect(index)
	var screen_pos := item_list.global_position + item_rect.position + item_rect.size * 0.5
	await _click_screen(screen_pos)


func _click_control_center(control: Control) -> void:
	await _click_screen(control.get_global_rect().get_center())


func _click_screen(screen_pos: Vector2) -> void:
	var viewport: Viewport = root
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	viewport.push_input(press, true)
	await process_frame
	await physics_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_pos
	release.global_position = screen_pos
	viewport.push_input(release, true)
	await process_frame
	await physics_frame


func _wait_for_scene_ready(scene_name: String, max_frames: int = 300) -> void:
	for _i in max_frames:
		await process_frame
		var scene_manager := root.get_node_or_null("SceneManager")
		var loading := scene_manager != null and bool(scene_manager.get("_loading"))
		if current_scene != null and current_scene.name == scene_name and not loading:
			await _wait_frames(8)
			return
	push_error("[e2e_item_use] timed out waiting for scene %s" % scene_name)
	quit(1)


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _save_png(res_path: String) -> void:
	await RenderingServer.frame_post_draw
	var abs_path := ProjectSettings.globalize_path(res_path)
	var image: Image = root.get_texture().get_image()
	var err := image.save_png(abs_path)
	if err != OK:
		push_error("[e2e_item_use] save_png failed err=%s path=%s" % [err, abs_path])
		quit(12)
		return
	print("[e2e_item_use] saved %s (%sx%s)" % [abs_path, image.get_width(), image.get_height()])


func _world_to_screen(world_pos: Vector2, battle) -> Vector2:
	return battle.get_viewport().get_canvas_transform() * world_pos
