extends SceneTree

const TILE_PX := 64

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_skill_cast] ==== BEGIN ====")
	DisplayServer.window_set_size(Vector2i(1366, 768))

	var packed := load("res://scenes/battle/battle.tscn") as PackedScene
	var battle = packed.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	var xu: Unit = battle.get_player_units()[0]
	var enemy_top: Unit = battle.get_enemy_units()[0]
	var enemy_mid: Unit = battle.get_enemy_units()[1]
	var hp_top := enemy_top.current_hp
	var hp_mid := enemy_mid.current_hp

	await _click_unit(xu, battle)
	await _click_empty_cell(_coord_to_world(Vector2i(5, 2)), battle)
	for _i in 120:
		await process_frame

	var skill_button: Button = battle.ui.skill_buttons[1]
	_assert(skill_button.visible, "T1 技能按钮可见")
	await _click_control(skill_button)
	await process_frame
	_assert(battle.select_state == 3, "T2 进入 SKILL_TARGETING")

	await _click_empty_cell(_coord_to_world(Vector2i(6, 2)), battle)
	for _i in 120:
		await process_frame

	_assert(enemy_top.current_hp < hp_top,
		"T3a 上方敌兵吃到十字范围伤害 (前=%d 后=%d)" % [hp_top, enemy_top.current_hp])
	_assert(enemy_mid.current_hp < hp_mid,
		"T3b 下方敌兵吃到十字范围伤害 (前=%d 后=%d)" % [hp_mid, enemy_mid.current_hp])
	_assert(xu.get_skill(1).current_cd == 2,
		"T3c 两袖青蛇释放后 current_cd=2 (实际=%d)" % xu.get_skill(1).current_cd)

	_finish()


func _click_unit(unit: Unit, battle) -> void:
	await _click_screen(_world_to_screen(unit.position, battle))


func _click_empty_cell(world_pos: Vector2, battle) -> void:
	await _click_screen(_world_to_screen(world_pos, battle))


func _click_control(control: Control) -> void:
	await _click_screen(control.global_position + control.size * 0.5)


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
	return Vector2(coord.x * TILE_PX + TILE_PX / 2.0, coord.y * TILE_PX + TILE_PX / 2.0)


func _world_to_screen(world_pos: Vector2, battle) -> Vector2:
	var cam: Camera2D = battle.camera
	var vp_size: Vector2 = root.get_viewport().get_visible_rect().size
	return world_pos - cam.position + vp_size * 0.5


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_skill_cast] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
