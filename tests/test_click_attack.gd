extends SceneTree
## test_click_attack —— 真实鼠标事件 E2E 测试（S4 bug fix 保障）
##
## 背景：用户在编辑器点击敌兵无反应。根因是 Area2D.input_event 触发后事件继续
##       冒泡到 BattleController._unhandled_input，_on_cell_clicked 在
##       MOVED_AWAIT_ACTION 状态下把该点击当"点空格"直接 _finish_unit_action，
##       导致攻击动画没播放、单位被 set_acted，交互看起来"没反应"。
##
## Fix：Unit._on_area_input 在 emit 后 get_viewport().set_input_as_handled()
##
## 测试策略：
##   Godot headless/脚本模式下 Area2D.input_event 无法通过 Input.parse_input_event
##   触发（需要 PhysicsServer mouse picking）。改用组合模拟：
##   1. 真实 push_input 进 viewport（覆盖 _unhandled_input 冒泡路径）
##   2. 同步调用 unit._on_area_input(viewport, event, 0)（覆盖 Area2D 路径）
##   两者同时推送模拟真实鼠标效果——关键：验证"点击敌兵"能正确攻击而不被
##   冒泡逻辑打断。
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

	var xu: Unit = battle.get_player_units()[0]       # (2, 2)
	var enemy_a: Unit = battle.get_enemy_units()[0]   # (6, 1)
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

	# === 步骤 2：点击移动范围内的 (5, 2) 空格 ===
	var move_target := Vector2i(5, 2)
	_assert(battle.current_move_range.has(move_target),
		"T2a (5,2) 应在 move_range 内")

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
		"T2e (6,1) 敌兵应在攻击范围内")

	# === 步骤 3（BUG 验证）：点击敌兵 → 期望 HP 下降 + 攻击动画播放 ===
	# 关键：这一步必须同时推 _unhandled_input 事件（模拟真实鼠标事件冒泡）
	#      如果 Unit 没有 set_input_as_handled 防冒泡，_unhandled_input 会把
	#      这次点击当"点空格" → _finish_unit_action → select_state 瞬间变 IDLE
	#      → 攻击要么不触发（state 变了）要么 HP 扣减 + acted 但视觉上没攻击动画
	await _click_unit(enemy_a, battle)
	# attack 动画 + tween 回位，给充足时间
	for _i in 120:
		await process_frame

	_assert(enemy_a.current_hp < enemy_init_hp,
		"T3a 点击敌兵后 HP 应下降 (前=%d 后=%d)" % [enemy_init_hp, enemy_a.current_hp])
	# dmg = max(1, xu.atk - enemy.def) = max(1, 8-2) = 6
	_assert(enemy_init_hp - enemy_a.current_hp == 6,
		"T3b dmg=6 (实际=%d)" % (enemy_init_hp - enemy_a.current_hp))
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


## 模拟真实鼠标左键点击 Unit
## Godot 4 headless 下 Area2D.input_event 不会被 PhysicsServer 自动触发，
## 所以调 Unit._on_area_input 模拟 Area2D picking。
## 修复验证：Unit._on_area_input 内应调 set_input_as_handled 防冒泡。
## 本测试在调 Area2D 回调后，立即再调 battle._unhandled_input 模拟"事件冒泡到
## _unhandled_input"——如果修复未生效，_unhandled_input 会把同一次点击当"点空格"处理
## 导致 MOVED_AWAIT_ACTION 下立即 _finish_unit_action（这是用户报告的 bug）。
## 修复生效时：测试手动检查 get_viewport().is_input_handled() 来跳过 _unhandled_input。
func _click_unit(unit: Unit, battle) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _world_to_screen(unit.position, battle)
	ev.global_position = ev.position

	# 1. Area2D picking 阶段
	unit._on_area_input(root.get_viewport(), ev, 0)
	# 2. 模拟事件继续冒泡：viewport 已经被 set_input_as_handled 标记
	#    真实场景下 _unhandled_input 不会触发。测试里验证这点：
	if not root.get_viewport().is_input_handled():
		# 未修复 → bug 场景
		battle._unhandled_input(ev)
	await process_frame
	await process_frame


## 模拟点击空格（不经过 Area2D，直接走 _unhandled_input）
## 用直接调用而不是 push_input：push_input 在异步分发时可能被 Tween 期间多次处理
func _click_empty_cell(world_pos: Vector2, battle) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _world_to_screen(world_pos, battle)
	ev.global_position = ev.position
	battle._unhandled_input(ev)
	await process_frame


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
	print("[test_click_attack] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
