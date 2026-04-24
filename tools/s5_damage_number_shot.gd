extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const VIEWPORT := Vector2i(1280, 720)
const ATTRIBUTE_SET = preload("res://scripts/core/attribute_set.gd")
const UNIT_DATA = preload("res://scripts/core/unit_data.gd")


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

	var controller = battle
	var xu: Unit = battle.get_player_units()[0]
	var enemy: Unit = battle.get_enemy_units()[0]

	await controller.debug_move(xu, Vector2i(3, 2))
	for _i in 10:
		await process_frame

	var enemy_hp_before := enemy.current_hp
	await controller.debug_attack(xu, enemy)
	for _i in 10:
		await process_frame
	var damage_observed := enemy.current_hp < enemy_hp_before
	if not damage_observed:
		push_error("[s5_damage_number_shot] attack did not resolve before screenshot")
		quit(2)
		return
	_save("tools/screenshots/s5_damage_number.png")

	battle.queue_free()
	await process_frame
	await _capture_miss_screenshot()
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


func _capture_miss_screenshot() -> void:
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle = packed.instantiate()
	root.add_child(battle)
	for _i in 20:
		await process_frame

	var xu: Unit = battle.get_player_units()[0]
	var enemy: Unit = battle.get_enemy_units()[0]
	var enemy_data := UNIT_DATA.new()
	enemy_data.unit_id = enemy.unit_data.unit_id
	enemy_data.unit_name = enemy.unit_data.unit_name
	enemy_data.is_enemy = enemy.unit_data.is_enemy
	enemy_data.weapon_type = enemy.unit_data.weapon_type
	enemy_data.weapon_range = enemy.unit_data.weapon_range
	enemy_data.skill_ids = enemy.unit_data.skill_ids.duplicate()
	enemy_data.sprite_frames = enemy.unit_data.sprite_frames
	enemy_data.sprite_offset = enemy.unit_data.sprite_offset
	enemy_data.modulate = enemy.unit_data.modulate
	enemy_data.attributes = ATTRIBUTE_SET.new()
	enemy_data.attributes.constitution = 5
	enemy_data.attributes.strength = 5
	enemy_data.attributes.agility = 100
	enemy_data.attributes.insight = 3
	enemy_data.attributes.fortune = 2
	enemy_data.attributes.base_hp = 25
	enemy_data.attributes.base_mp = 5
	enemy_data.attributes.move_range = 3
	enemy_data.attributes.spec_fist = 3
	enemy_data.attributes.spec_blade = 3
	enemy.setup(enemy_data, enemy.current_position)
	for _i in 10:
		await process_frame

	await battle.debug_move(xu, Vector2i(3, 2))
	for _i in 10:
		await process_frame

	CombatSystem.reset_roll_seed(4)
	await xu.play_attack(enemy.current_position)
	CombatSystem.resolve_attack(xu, enemy, battle.get_grid())
	for _i in 12:
		await process_frame
	_save("tools/screenshots/s5_miss_number.png")


func _save(rel_path: String) -> void:
	var abs := ProjectSettings.globalize_path("res://" + rel_path)
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(abs)
	if err != OK:
		push_error("[s5_damage_number_shot] save_png failed err=%s path=%s" % [err, abs])
	else:
		print("[s5_damage_number_shot] saved %s (%sx%s)" % [abs, img.get_width(), img.get_height()])
