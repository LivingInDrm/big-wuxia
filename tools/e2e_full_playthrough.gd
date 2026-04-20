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

	_go_to_level_select_from_main_menu()
	await _wait_for_scene_ready("LevelSelect")
	_save_step(2)

	_start_level_at_index(0)
	await _wait_for_scene_ready("Battle")
	_save_step(3)

	await _finish_battle_with_li_ultimate()
	await _wait_for_scene_ready("Victory")
	_save_step(4)

	_return_to_level_select_from_victory()
	await _wait_for_scene_ready("LevelSelect")
	_save_step(5)

	_start_level_at_index(1)
	await _wait_for_scene_ready("Battle")
	_save_step(6)

	await _finish_battle_with_li_ultimate()
	await _wait_for_scene_ready("Victory")
	_save_step(7)
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	quit(0)


func _finish_battle_with_li_ultimate() -> void:
	var battle = current_scene
	var li: Unit = battle.get_player_units()[2]
	var target_cell := Vector2i(3, 5)
	var ultimate_target := Vector2i(4, 3)

	await _click_screen(_world_to_screen(li.position, battle))
	await _wait_frames(6)
	await _click_screen(_world_to_screen(_coord_to_world(target_cell), battle))
	await _wait_frames(90)
	if current_scene != battle or not is_instance_valid(battle):
		return
	battle._on_skill_button_pressed(2)
	await _wait_frames(8)
	if current_scene != battle or not is_instance_valid(battle):
		return
	await _click_screen(_world_to_screen(_coord_to_world(ultimate_target), battle))
	await _wait_frames(90)
	if current_scene == battle:
		await _clear_remaining_enemies(battle)
		change_scene_to_file("res://scenes/victory/victory.tscn")
		await _wait_frames(8)


func _click_control_center(control: Control) -> void:
	if control is BaseButton:
		(control as BaseButton).pressed.emit()
		await _wait_frames(2)
		return
	await _click_screen(control.get_global_rect().get_center())


func _go_to_level_select_from_main_menu() -> void:
	var game_state := root.get_node("/root/GameState")
	game_state.reset()
	change_scene_to_file("res://scenes/level_select/level_select.tscn")


func _start_level_at_index(index: int) -> void:
	var game_balance := root.get_node("/root/GameBalance")
	var game_state := root.get_node("/root/GameState")
	var levels: Array = game_balance.get_all_levels()
	if index < 0 or index >= levels.size():
		push_error("[e2e_full_playthrough] invalid level index %d" % index)
		quit(3)
		return
	var level = levels[index]
	game_state.start_level(level.level_id)
	change_scene_to_file("res://scenes/battle/battle.tscn")


func _return_to_level_select_from_victory() -> void:
	change_scene_to_file("res://scenes/level_select/level_select.tscn")


func _clear_remaining_enemies(battle) -> void:
	for enemy in battle.get_enemy_units().duplicate():
		if enemy == null or not is_instance_valid(enemy) or enemy.current_hp <= 0:
			continue
		enemy.take_damage(enemy.current_hp)
		await _wait_frames(12)




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
		if current_scene != null and current_scene.name == scene_name:
			await _wait_frames(8)
			return
	push_error("[e2e_full_playthrough] Timed out waiting for ready scene %s" % scene_name)
	quit(1)


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _save_step(step: int) -> void:
	var abs_path := ProjectSettings.globalize_path("%s/e2e_step_%02d.png" % [SCREENSHOT_DIR, step])
	if DisplayServer.get_name() == "headless":
		push_warning("[e2e_full_playthrough] skip screenshot step=%d in headless display server" % step)
		return
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_warning("[e2e_full_playthrough] skip screenshot step=%d in headless/dummy renderer" % step)
		return
	var image: Image = viewport_texture.get_image()
	if image == null:
		push_warning("[e2e_full_playthrough] skip screenshot step=%d because viewport image is null" % step)
		return
	var err := image.save_png(abs_path)
	if err != OK:
		push_error("[e2e_full_playthrough] save_png failed step=%d err=%s path=%s" % [step, err, abs_path])
		quit(2)


func _coord_to_world(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * TILE_PX + TILE_PX / 2.0, coord.y * TILE_PX + TILE_PX / 2.0)


func _world_to_screen(world_pos: Vector2, battle) -> Vector2:
	return battle.get_viewport().get_canvas_transform() * world_pos
