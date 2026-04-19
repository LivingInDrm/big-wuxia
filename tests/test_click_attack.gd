extends SceneTree
## test_click_attack —— 真实鼠标事件 E2E 测试（S4 bug fix 保障）
##
## 背景：用户在编辑器点击敌兵无反应。真实事件顺序里 _unhandled_input 先于
##       Area2D.input_event 执行，BattleController 会先把这次点击当"点空格"
##       处理，导致 MOVED_AWAIT_ACTION 下直接 _finish_unit_action。
##
## Fix：BattleController._unhandled_input 先做 Physics 点查询；若点在 Unit 身上，
##      就跳过空格点击逻辑，让后续 Area2D.input_event 正常处理单位点击。
##
## 测试策略：
##   真实使用 Viewport.push_input(..., true) 注入鼠标事件，要求事件同时经过
##   BattleController._unhandled_input 与 Area2D.input_event，最终验证敌兵 HP 下降。
##
## 用法：godot --path . --script tests/test_click_attack.gd

const TILE_PX := 64

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_click_attack] ==== BEGIN ====")

	DisplayServer.window_set_size(Vector2i(960, 720))

	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	var battle = packed.instantiate()
	root.add_child(battle)

	for _i in 20:
		await process_frame

	var xu: Unit = battle.get_player_units()[0]       # (1, 2)
	var enemy_a: Unit = battle.get_enemy_units()[0]   # (4, 2)
	var grid: GridSystem = battle.get_grid()

	_assert(xu.unit_data.unit_id == "xu_fengnian", "setup: xu is 徐凤年")
	var enemy_init_hp := enemy_a.current_hp
	print("[T] xu@%s hp=%d / enemy@%s hp=%d" % [
		str(xu.current_position), xu.current_hp,
		str(enemy_a.current_position), enemy_init_hp])

	# === 步骤 1：模拟点击己方徐凤年 ===
	await _click_unit(xu, battle)
	await process_frame

	_assert(battle.selected_unit == xu, "T1a 点击徐凤年后 selected_unit == xu")
	_assert(battle.select_state == 1,  # UNIT_SELECTED
		"T1b select_state == UNIT_SELECTED (实际=%d)" % battle.select_state)
	_assert(not battle.current_move_range.is_empty(),
		"T1c move_range 非空 (size=%d)" % battle.current_move_range.size())

	# === 步骤 2：点击移动范围内的 (3, 2) 空格 ===
	var move_target := Vector2i(3, 2)
	_assert(battle.current_move_range.has(move_target),
		"T2a (3,2) 应在 move_range 内")

	var target_world := Vector2(
		move_target.x * TILE_PX + TILE_PX / 2.0,
		move_target.y * TILE_PX + TILE_PX / 2.0)
	await _click_empty_cell(target_world, battle)
	# Tween 3 格 x 0.15s = 0.45s，--script 模式 process_frame 间隔不稳定，给 120 帧
	for _i in 120:
		await process_frame

	_assert(xu.current_position == move_target,
		"T2b 移动后 position=%s (期望=%s)" % [str(xu.current_position), str(move_target)])
	_assert(battle.select_state == 2,  # MOVED_AWAIT_ACTION
		"T2c select_state == MOVED_AWAIT_ACTION (实际=%d)" % battle.select_state)
	_assert(not battle.current_attack_range.is_empty(),
		"T2d attack_range 非空 (size=%d)" % battle.current_attack_range.size())
	_assert(battle.current_attack_range.has(enemy_a.current_position),
		"T2e (4,2) 敌兵应在攻击范围内")

	# === 步骤 3（BUG 验证）：点击敌兵 → 期望 HP 下降 + 攻击动画播放 ===
	# 关键：真实管线里这次点击会先进入 _unhandled_input，再进入 Area2D.input_event。
	#      修复前，前者会直接把单位点击误当作空格结束回合；修复后，点击敌兵应正常
	#      进入攻击分支并扣减 HP。
	await _click_unit(enemy_a, battle)
	# attack 动画 + tween 回位，给充足时间
	for _i in 120:
		await process_frame

	_assert(enemy_a.current_hp < enemy_init_hp,
		"T3a 点击敌兵后 HP 应下降 (前=%d 后=%d)" % [enemy_init_hp, enemy_a.current_hp])
	# dmg = max(1, attack(28) - defense(7)) = 21
	_assert(enemy_init_hp - enemy_a.current_hp == 21,
		"T3b dmg=21 (实际=%d)" % (enemy_init_hp - enemy_a.current_hp))
	_assert(xu.acted, "T3c 徐凤年攻击后 acted=true")

	# === 步骤 4：点击已 acted 的己方单位应无反应 ===
	var xu_acted_before := xu.acted
	await _click_unit(xu, battle)
	await process_frame
	_assert(battle.selected_unit == null,
		"T4a 点击 acted 单位不应选中 (selected_unit=%s)" % str(battle.selected_unit))

	# === 步骤 5：点击另一个己方（未 acted）应能选中 ===
	var jiang: Unit = battle.get_player_units()[1]
	await _click_unit(jiang, battle)
	await process_frame
	_assert(battle.selected_unit == jiang,
		"T5a 点击姜泥应选中 (实际=%s)" % str(battle.selected_unit))
	_assert(battle.select_state == 1, "T5b 状态回到 UNIT_SELECTED")

	# === 步骤 6：点击移动范围外的格子 → 取消选择 ===
	var far_world := Vector2(
		11 * TILE_PX + TILE_PX / 2.0,
		9 * TILE_PX + TILE_PX / 2.0)
	await _click_empty_cell(far_world, battle)
	await process_frame
	_assert(battle.selected_unit == null, "T6a 点范围外应取消选择")
	_assert(battle.select_state == 0, "T6b state 回到 IDLE")

	_finish()


func _click_unit(unit: Unit, battle) -> void:
	var viewport: Viewport = battle.get_viewport()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _world_to_screen(unit.position, battle)
	ev.global_position = ev.position
	viewport.push_input(ev, true)
	await process_frame
	await physics_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = ev.position
	release.global_position = ev.global_position
	viewport.push_input(release, true)
	await process_frame
	await physics_frame


## 模拟点击空格（不经过 Area2D，直接走 _unhandled_input）
func _click_empty_cell(world_pos: Vector2, battle) -> void:
	var viewport: Viewport = battle.get_viewport()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _world_to_screen(world_pos, battle)
	ev.global_position = ev.position
	viewport.push_input(ev, true)
	await process_frame
	await physics_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = ev.position
	release.global_position = ev.global_position
	viewport.push_input(release, true)
	await process_frame
	await physics_frame


func _world_to_screen(world_pos: Vector2, battle) -> Vector2:
	return battle.get_viewport().get_canvas_transform() * world_pos


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_click_attack] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
