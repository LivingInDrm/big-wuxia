extends SceneTree

const VIEWPORT := Vector2i(1366, 768)
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const SCREENSHOT_DIR := "res://tools/screenshots"
const TILE_PX := 64


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT)
	change_scene_to_file(MAIN_MENU_SCENE)

	await _wait_for_scene_ready("MainMenu")
	_save_step(1)

	var main_menu := current_scene as Control
	await _click_control_center(main_menu.get_node("%StartButton") as Control)
	await _wait_for_scene_ready("LevelSelect")
	_save_step(2)

	var level_select := current_scene as Control
	var levels_container := level_select.get_node("%LevelsContainer") as VBoxContainer
	await _click_control_center(levels_container.get_child(0) as Control)
	await _wait_for_scene_ready("Battle")
	_save_step(3)

	await _finish_battle_with_li_ultimate()
	await _wait_for_scene_ready("Victory")
	_save_step(4)

	var victory := current_scene as Control
	await _click_control_center(victory.get_node("%ReturnButton") as Control)
	await _wait_for_scene_ready("LevelSelect")
	_save_step(5)

	level_select = current_scene as Control
	levels_container = level_select.get_node("%LevelsContainer") as VBoxContainer
	await _click_control_center(levels_container.get_child(1) as Control)
	await _wait_for_scene_ready("Battle")
	_save_step(6)

	await _finish_battle_with_li_ultimate()
	await _wait_for_scene_ready("Victory")
	_save_step(7)
	quit(0)


func _finish_battle_with_li_ultimate() -> void:
	var battle = current_scene
	var li: Unit = battle.get_player_units()[2]
	var target_cell := Vector2i(3, 5)
	var ultimate_target := Vector2i(4, 3)
	var skill_button: Control = battle.ui.skill_buttons[2]

	await _click_screen(_world_to_screen(li.position, battle))
	await _wait_frames(6)
	await _click_screen(_world_to_screen(_coord_to_world(target_cell), battle))
	await _wait_frames(90)
	await _click_control_center(skill_button)
	await _wait_frames(8)
	await _click_screen(_world_to_screen(_coord_to_world(ultimate_target), battle))
	await _wait_frames(90)


func _click_control_center(control: Control) -> void:
	await _click_screen(control.get_global_rect().get_center())


func _click_screen(screen_pos: Vector2) -> void:
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


func _wait_for_scene(scene_name: String, max_frames: int = 240) -> void:
	for _i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == scene_name:
			return
	push_error("[e2e_full_playthrough] Timed out waiting for scene %s" % scene_name)
	quit(1)


func _wait_for_scene_ready(scene_name: String, max_frames: int = 300) -> void:
	for _i in max_frames:
		await process_frame
		var scene_manager := root.get_node_or_null("SceneManager")
		var loading := scene_manager != null and bool(scene_manager.get("_loading"))
		if current_scene != null and current_scene.name == scene_name and not loading:
			await _wait_frames(8)
			return
	push_error("[e2e_full_playthrough] Timed out waiting for ready scene %s" % scene_name)
	quit(1)


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _save_step(step: int) -> void:
	var abs_path := ProjectSettings.globalize_path("%s/e2e_step_%02d.png" % [SCREENSHOT_DIR, step])
	var image: Image = root.get_texture().get_image()
	var err := image.save_png(abs_path)
	if err != OK:
		push_error("[e2e_full_playthrough] save_png failed step=%d err=%s path=%s" % [step, err, abs_path])
		quit(2)


func _coord_to_world(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * TILE_PX + TILE_PX / 2.0, coord.y * TILE_PX + TILE_PX / 2.0)


func _world_to_screen(world_pos: Vector2, battle) -> Vector2:
	return battle.get_viewport().get_canvas_transform() * world_pos
