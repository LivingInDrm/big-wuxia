extends SceneTree
## trace_click_pipeline —— 用真实 Viewport.push_input 复现点击敌兵链路
##
## 用法：
##   godot --headless --path . --script tools/trace_click_pipeline.gd

const TILE_PX := 64


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[trace_click_pipeline] ==== BEGIN ====")
	DisplayServer.window_set_size(Vector2i(1366, 768))

	var packed := load("res://scenes/battle/battle.tscn") as PackedScene
	if packed == null:
		push_error("[trace_click_pipeline] failed to load battle scene")
		quit(2)
		return

	var battle = packed.instantiate()
	root.add_child(battle)

	await process_frame
	await physics_frame
	await physics_frame

	var xu: Unit = battle.get_player_units()[0]
	var enemy: Unit = battle.get_enemy_units()[0]
	print("[trace_click_pipeline] setup xu=%s@%s enemy=%s@%s enemy_hp=%d" % [
		xu.unit_data.unit_id, str(xu.current_position),
		enemy.unit_data.unit_id, str(enemy.current_position), enemy.current_hp,
	])

	await battle.debug_select(xu)
	await process_frame
	print("[trace_click_pipeline] after debug_select state=%s selected=%s" % [
		str(battle.select_state),
		battle.selected_unit.unit_data.unit_id if battle.selected_unit != null else "<null>",
	])

	await battle.debug_move(xu, Vector2i(5, 2))
	await process_frame
	await physics_frame
	await physics_frame
	print("[trace_click_pipeline] after debug_move state=%s xu_pos=%s attack_has_enemy=%s" % [
		str(battle.select_state),
		str(xu.current_position),
		str(battle.current_attack_range.has(enemy.current_position)),
	])

	var enemy_screen_pos := _world_to_screen(enemy.position, battle)
	print("[trace_click_pipeline] enemy_screen_pos=%s enemy_world=%s" % [
		str(enemy_screen_pos), str(enemy.position),
	])

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = enemy_screen_pos
	press.global_position = enemy_screen_pos

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = enemy_screen_pos
	release.global_position = enemy_screen_pos

	print("[trace_click_pipeline] push_input press")
	root.push_input(press, true)
	await process_frame
	await physics_frame
	await physics_frame

	print("[trace_click_pipeline] push_input release")
	root.push_input(release, true)
	await process_frame
	await physics_frame
	await physics_frame

	for _i in 120:
		if xu.acted or enemy.current_hp < enemy.unit_data.max_hp:
			break
		await process_frame

	print("[trace_click_pipeline] result state=%s selected=%s xu_acted=%s enemy_hp=%d" % [
		str(battle.select_state),
		battle.selected_unit.unit_data.unit_id if battle.selected_unit != null else "<null>",
		str(xu.acted),
		enemy.current_hp,
	])
	print("[trace_click_pipeline] ==== END ====")
	quit(0)


func _world_to_screen(world_pos: Vector2, battle) -> Vector2:
	var cam: Camera2D = battle.camera
	var vp_size: Vector2 = root.get_viewport().get_visible_rect().size
	return world_pos - cam.position + vp_size * 0.5
