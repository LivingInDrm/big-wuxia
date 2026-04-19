extends SceneTree
## test_turn_cycle —— S3 TurnManager 回合/阶段切换单测
##
## 用法：godot --headless --path . --script tests/test_turn_cycle.gd
##
## 覆盖：
##   T1  Battle 场景加载后 TurnManager 初始：turn=1, phase=PLAYER_SELECT
##   T2  _start_enemy_phase() → phase=ENEMY_TURN，turn 不变
##   T3  _next_turn() → turn=2, phase=PLAYER_SELECT
##   T4  turn_started / phase_changed 信号有被 emit
##   T5  phase_label() 文字正确
##
## 退出码：0 = 全部通过，1 = 有失败

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

var _pass: int = 0
var _fail: int = 0

var _turn_events: Array[int] = []
var _phase_events: Array[int] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_turn_cycle] ==== BEGIN ====")

	var packed: PackedScene = load(BATTLE_SCENE)
	_assert(packed != null, "T1 Battle 场景加载")
	if packed == null:
		_finish()
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var tm: TurnManager = scene.get_turn_manager() if scene.has_method("get_turn_manager") else null
	_assert(tm != null, "T1b BattleController.get_turn_manager() 非 null")
	if tm == null:
		_finish()
		return

	# 挂 spy
	tm.turn_started.connect(func(n: int) -> void: _turn_events.append(n))
	tm.phase_changed.connect(func(p: int) -> void: _phase_events.append(p))

	# T1: 初始
	_assert(tm.current_turn == 1,
		"T1c 初始 turn=1 (实际=%d)" % tm.current_turn)
	_assert(tm.current_phase == TurnManager.Phase.PLAYER_SELECT,
		"T1d 初始 phase=PLAYER_SELECT (实际=%d)" % tm.current_phase)

	# T2: enemy phase
	tm._start_enemy_phase()
	await process_frame
	_assert(tm.current_phase == TurnManager.Phase.ENEMY_TURN,
		"T2a phase=ENEMY_TURN (实际=%d)" % tm.current_phase)
	_assert(tm.current_turn == 1,
		"T2b turn 不变=1 (实际=%d)" % tm.current_turn)

	# T3: next turn
	tm._next_turn()
	await process_frame
	_assert(tm.current_turn == 2,
		"T3a turn=2 (实际=%d)" % tm.current_turn)
	_assert(tm.current_phase == TurnManager.Phase.PLAYER_SELECT,
		"T3b phase=PLAYER_SELECT (实际=%d)" % tm.current_phase)

	# T4: 信号发射 —— start_battle emit 1 次 turn_started + 1 次 phase_changed
	#                 _start_enemy_phase emit 1 次 phase_changed
	#                 _next_turn emit 1 次 turn_started + 1 次 phase_changed
	# spy 挂得晚（start_battle 已经执行过），所以只能收到后两次
	_assert(_phase_events.size() >= 2, "T4a phase_changed ≥ 2 次 (实际=%d)" % _phase_events.size())
	_assert(_turn_events.size() >= 1, "T4b turn_started ≥ 1 次 (实际=%d)" % _turn_events.size())
	_assert(_turn_events[-1] == 2, "T4c 最后一次 turn_started 参数=2")

	# T5: phase_label
	_assert(TurnManager.phase_label(TurnManager.Phase.PLAYER_SELECT) == "玩家阶段",
		"T5a PLAYER_SELECT → 玩家阶段")
	_assert(TurnManager.phase_label(TurnManager.Phase.ENEMY_TURN) == "敌方阶段",
		"T5b ENEMY_TURN → 敌方阶段")

	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_turn_cycle] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
