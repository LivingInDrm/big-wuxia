extends SceneTree

const TILE_PX := 64.0
const MOVE_TARGET := Vector2i(3, 2)
const XU_ORIGIN := Vector2i(1, 2)

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_battle_hud_v3_action_menu_clicks] ==== BEGIN ====")
	DisplayServer.window_set_size(Vector2i(1366, 768))
	await _test_attack_button()
	await _test_martial_button()
	await _test_item_button()
	await _test_wait_button()
	await _test_cancel_move_button()
	_finish()


func _test_attack_button() -> void:
	var ctx := await _prepare_context()
	var trace := await _click_action_button(ctx, &"attack")
	_assert(trace.pressed, "T1a 攻击按钮 pressed 触发")
	_assert(trace.emitted == PackedStringArray(["attack"]), "T1b 攻击按钮 emit_menu_action=attack")
	_assert(ctx.battle.select_state == 2, "T1c 攻击按钮后仍在 MOVED_AWAIT_ACTION")
	_assert(String(ctx.battle.ui.message_label.text).contains("攻击模式"), "T1d controller 收到攻击动作并更新提示")
	print("[TRACE] attack pressed=%s emitted=%s state=%d msg=%s" % [
		str(trace.pressed), str(trace.emitted), ctx.battle.select_state, ctx.battle.ui.message_label.text
	])
	await _cleanup_battle(ctx.battle)


func _test_martial_button() -> void:
	var ctx := await _prepare_context()
	var trace := await _click_action_button(ctx, &"martial")
	_assert(trace.pressed, "T2a 武功按钮 pressed 触发")
	_assert(trace.emitted == PackedStringArray(["martial"]), "T2b 武功按钮 emit_menu_action=martial")
	_assert(ctx.hud.is_submenu_open(&"skill"), "T2c controller 收到武功动作并打开武功子面板")
	_assert(String(ctx.battle.ui.message_label.text).contains("选择武功"), "T2d 武功按钮后提示为选择武功")
	print("[TRACE] martial pressed=%s emitted=%s submenu=%s state=%d msg=%s" % [
		str(trace.pressed), str(trace.emitted), str(ctx.hud.is_submenu_open(&"skill")),
		ctx.battle.select_state, ctx.battle.ui.message_label.text
	])
	await _cleanup_battle(ctx.battle)


func _test_item_button() -> void:
	var ctx := await _prepare_context(["jinchuang_yao"])
	var trace := await _click_action_button(ctx, &"item")
	_assert(trace.pressed, "T3a 道具按钮 pressed 触发")
	_assert(trace.emitted == PackedStringArray(["item"]), "T3b 道具按钮 emit_menu_action=item")
	_assert(ctx.hud.is_submenu_open(&"item"), "T3c controller 收到道具动作并打开道具子面板")
	_assert(String(ctx.battle.ui.message_label.text).contains("选择一个消耗品"), "T3d 道具按钮后提示为选择消耗品")
	print("[TRACE] item pressed=%s emitted=%s submenu=%s state=%d msg=%s" % [
		str(trace.pressed), str(trace.emitted), str(ctx.hud.is_submenu_open(&"item")),
		ctx.battle.select_state, ctx.battle.ui.message_label.text
	])
	await _cleanup_battle(ctx.battle)


func _test_wait_button() -> void:
	var ctx := await _prepare_context()
	var xu: Unit = ctx.xu
	var trace := await _click_action_button(ctx, &"wait")
	await _wait_frames(4)
	_assert(trace.pressed, "T4a 待机按钮 pressed 触发")
	_assert(trace.emitted == PackedStringArray(["wait"]), "T4b 待机按钮 emit_menu_action=wait")
	_assert(xu.acted, "T4c controller 收到待机动作并结束单位行动")
	_assert(ctx.battle.select_state == 0 and ctx.battle.selected_unit == null, "T4d 待机后状态回到 IDLE")
	print("[TRACE] wait pressed=%s emitted=%s acted=%s state=%d" % [
		str(trace.pressed), str(trace.emitted), str(xu.acted), ctx.battle.select_state
	])
	await _cleanup_battle(ctx.battle)


func _test_cancel_move_button() -> void:
	var ctx := await _prepare_context()
	var xu: Unit = ctx.xu
	var trace := await _click_action_button(ctx, &"cancel_move")
	await _wait_frames(4)
	_assert(trace.pressed, "T5a 取消移动按钮 pressed 触发")
	_assert(trace.emitted == PackedStringArray(["cancel_move"]), "T5b 取消移动按钮 emit_menu_action=cancel_move")
	_assert(ctx.battle.select_state == 1 and ctx.battle.selected_unit == xu, "T5c controller 收到取消移动并回到 UNIT_SELECTED")
	_assert(xu.current_position == XU_ORIGIN, "T5d 取消移动后徐凤年回到初始格")
	print("[TRACE] cancel_move pressed=%s emitted=%s state=%d pos=%s" % [
		str(trace.pressed), str(trace.emitted), ctx.battle.select_state, str(xu.current_position)
	])
	await _cleanup_battle(ctx.battle)


func _prepare_context(extra_items: Array[String] = []) -> Dictionary:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.reset()
	for item_id in extra_items:
		game_state.inventory.add(item_id)
	var battle: Node = await _load_battle()
	var hud = battle.ui.get_battle_hud_v3()
	var xu: Unit = battle.get_player_units()[0]
	await _click_world(battle, xu.global_position)
	await _click_world(battle, _coord_to_world(MOVE_TARGET))
	await _wait_frames(120)
	await create_timer(0.2).timeout
	_assert(xu.current_position == MOVE_TARGET, "setup 徐凤年移动到动作菜单阶段")
	_assert(battle.select_state == 2, "setup 进入 MOVED_AWAIT_ACTION")
	return {
		"battle": battle,
		"hud": hud,
		"xu": xu,
	}


func _load_battle() -> Node:
	var packed := load("res://scenes/battle/battle.tscn") as PackedScene
	var battle = packed.instantiate()
	root.add_child(battle)
	await _wait_frames(2)
	return battle


func _cleanup_battle(battle: Node) -> void:
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
	await _wait_frames(2)


func _click_action_button(ctx: Dictionary, action: StringName) -> Dictionary:
	var hud = ctx.hud
	var button = hud._action_buttons.get(action) as Button
	var emitted := PackedStringArray()
	var trace := {
		"pressed": false,
	}
	hud.emit_menu_action.connect(func(name: StringName) -> void:
		emitted.append(String(name))
	, CONNECT_ONE_SHOT)
	button.pressed.connect(func() -> void:
		trace["pressed"] = true
	, CONNECT_ONE_SHOT)
	await _click_control(button)
	await _wait_frames(2)
	return {
		"pressed": bool(trace["pressed"]),
		"emitted": emitted,
	}


func _click_control(control: Control) -> void:
	await _click_screen(control.get_global_rect().get_center())


func _click_world(battle: Node, world: Vector2) -> void:
	await _click_screen(battle.get_viewport().get_canvas_transform() * world)


func _click_screen(screen_pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = screen_pos
	motion.global_position = screen_pos
	root.push_input(motion, true)
	await process_frame
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


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_battle_hud_v3_action_menu_clicks] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
