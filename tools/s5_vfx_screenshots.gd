extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SKILL_EXECUTOR = preload("res://scripts/systems/skill_executor.gd")
const VIEWPORT := Vector2i(1280, 720)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT)

	var battle = await _load_battle_as_current()
	if battle == null:
		quit(1)
		return

	await _capture_cross_skill(battle)
	await _capture_ultimate(battle)
	await _capture_heal(battle)
	quit(0)


func _load_battle_as_current():
	root.get_tree().change_scene_to_file(BATTLE_SCENE)
	for _i in 60:
		await process_frame
		if root.get_tree().current_scene != null and root.get_tree().current_scene.name == "Battle":
			return root.get_tree().current_scene
	push_error("[s5_vfx_screenshots] Failed to load battle as current scene")
	return root.get_tree().current_scene


func _capture_cross_skill(battle) -> void:
	var xu: Unit = battle.get_player_units()[0]
	await battle.debug_move(xu, Vector2i(5, 2))
	for _i in 10:
		await process_frame
	await SKILL_EXECUTOR.execute_skill(
		xu,
		xu.get_skill(1),
		Vector2i(6, 2),
		battle.get_grid(),
		CombatSystem
	)
	for _i in 8:
		await process_frame
	_save("tools/screenshots/s5_skill_cross.png")


func _capture_ultimate(battle) -> void:
	battle = await _load_battle_as_current()
	var li: Unit = battle.get_player_units()[2]
	await battle.debug_move(li, Vector2i(5, 6))
	for _i in 10:
		await process_frame
	await SKILL_EXECUTOR.execute_skill(
		li,
		li.get_skill(2),
		Vector2i(6, 3),
		battle.get_grid(),
		CombatSystem
	)
	for _i in 8:
		await process_frame
	_save("tools/screenshots/s5_ultimate.png")


func _capture_heal(battle) -> void:
	battle = await _load_battle_as_current()
	var jiang: Unit = battle.get_player_units()[1]
	var xu: Unit = battle.get_player_units()[0]
	xu.take_damage(5)
	await SKILL_EXECUTOR.execute_skill(
		jiang,
		jiang.get_skill(1),
		xu.current_position,
		battle.get_grid(),
		CombatSystem
	)
	for _i in 8:
		await process_frame
	_save("tools/screenshots/s5_heal.png")


func _save(rel_path: String) -> void:
	var abs := ProjectSettings.globalize_path("res://" + rel_path)
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(abs)
	if err != OK:
		push_error("[s5_vfx_screenshots] save_png failed err=%s path=%s" % [err, abs])
	else:
		print("[s5_vfx_screenshots] saved %s (%sx%s)" % [abs, img.get_width(), img.get_height()])
