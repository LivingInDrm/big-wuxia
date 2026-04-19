extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const VIEWPORT := Vector2i(1280, 720)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT)

	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		push_error("[s5_damage_number_shot] Failed to load battle scene")
		quit(1)
		return

	var battle = packed.instantiate()
	root.add_child(battle)
	for _i in 20:
		await process_frame

	var xu: Unit = battle.get_player_units()[0]
	var enemy: Unit = battle.get_enemy_units()[0]

	await _click_unit(xu, battle)
	await _click_empty_cell(_coord_to_world(Vector2i(5, 2)), battle)
	for _i in 120:
		await process_frame

	await _click_unit(enemy, battle)
	var enemy_hp_before := enemy.current_hp
	var damage_observed := false
	for _i in 120:
		await process_frame
		if enemy.current_hp < enemy_hp_before:
			damage_observed = true
			break
	if not damage_observed:
		push_error("[s5_damage_number_shot] attack did not resolve before screenshot")
		quit(2)
		return
	_save("tools/screenshots/s5_damage_number.png")
	quit(0)


func _click_unit(unit: Unit, battle) -> void:
	await _click_screen(_world_to_screen(unit.position, battle))


func _click_empty_cell(world_pos: Vector2, battle) -> void:
	await _click_screen(_world_to_screen(world_pos, battle))


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


func _coord_to_world(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * 64 + 32, coord.y * 64 + 32)


func _world_to_screen(world_pos: Vector2, battle) -> Vector2:
	return battle.get_viewport().get_canvas_transform() * world_pos


func _save(rel_path: String) -> void:
	var abs := ProjectSettings.globalize_path("res://" + rel_path)
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(abs)
	if err != OK:
		push_error("[s5_damage_number_shot] save_png failed err=%s path=%s" % [err, abs])
	else:
		print("[s5_damage_number_shot] saved %s (%sx%s)" % [abs, img.get_width(), img.get_height()])
