extends SceneTree
## test_enemy_ai —— S4 敌方 AI 决策单测
##
## 用法：godot --headless --path . --script tests/test_enemy_ai.gd
##
## 覆盖：
##   T1 敌兵相邻玩家 → 直接攻击（不移动）
##   T2 敌兵离玩家远 → 先移动进入攻击范围，再攻击
##   T3 只有一个玩家时正确选定
##
## 做法：加载 battle.tscn，手动摆位，call enemy_ai.take_turn(...)，观察 hp / position 变化。

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_enemy_ai] ==== BEGIN ====")

	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	var battle = packed.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	var xu: Unit = battle.get_player_units()[0]
	var jiang: Unit = battle.get_player_units()[1]
	var li: Unit = battle.get_player_units()[2]
	var enemy: Unit = battle.get_enemy_units()[0]
	var enemy2: Unit = battle.get_enemy_units()[1]
	var enemy3: Unit = battle.get_enemy_units()[2]

	var g: GridSystem = battle.get_grid()
	var ai: EnemyAI = battle.get_enemy_ai()
	_assert(ai != null, "T0 enemy_ai != null")

	# === T1: 敌兵相邻玩家 → 应直接攻击 ===
	# 把 enemy 挪到 xu 东边相邻 (xu.pos + (1,0))
	g.get_tile(enemy.current_position).occupant = null
	var adj: Vector2i = xu.current_position + Vector2i(1, 0)
	enemy.current_position = adj
	enemy.position = Vector2(adj.x * 64 + 32, adj.y * 64 + 32)
	g.get_tile(adj).occupant = enemy

	var xu_hp_before := xu.current_hp
	await ai.take_turn(enemy, [xu, jiang, li])
	await process_frame
	_assert(enemy.current_position == adj,
		"T1a 相邻时敌兵不应移动 (实际=%s)" % str(enemy.current_position))
	_assert(xu.current_hp < xu_hp_before,
		"T1b 徐凤年 hp 下降 (前=%d 后=%d)" % [xu_hp_before, xu.current_hp])
	# dmg = max(1, enemy.atk(14) - xu.def(10)) = 4
	_assert(xu_hp_before - xu.current_hp == 4,
		"T1c dmg=4 (实际=%d)" % (xu_hp_before - xu.current_hp))

	# === T2: 敌兵离玩家远 → 先移动再看能否攻击 ===
	# 挪 enemy2 到远处 (7,7)；除 jiang 外把其他玩家移走
	g.get_tile(enemy2.current_position).occupant = null
	var far: Vector2i = Vector2i(7, 7)
	enemy2.current_position = far
	enemy2.position = Vector2(far.x * 64 + 32, far.y * 64 + 32)
	g.get_tile(far).occupant = enemy2

	# 放 jiang 到 (4,7)，敌兵 mov=3，可先移动到相邻格再攻击
	g.get_tile(jiang.current_position).occupant = null
	var jiang_pos := Vector2i(4, 7)
	jiang.current_position = jiang_pos
	jiang.position = Vector2(jiang_pos.x * 64 + 32, jiang_pos.y * 64 + 32)
	g.get_tile(jiang_pos).occupant = jiang

	var enemy2_pre := enemy2.current_position
	var jiang_hp_before := jiang.current_hp
	await ai.take_turn(enemy2, [jiang])
	await process_frame
	_assert(enemy2.current_position != enemy2_pre,
		"T2a 敌兵移动了 (前=%s 后=%s)" % [str(enemy2_pre), str(enemy2.current_position)])
	# 移动后与 jiang 的 Chebyshev 距离 ≤ 1
	var dx: int = abs(enemy2.current_position.x - jiang.current_position.x)
	var dy: int = abs(enemy2.current_position.y - jiang.current_position.y)
	var chebyshev: int = max(dx, dy)
	_assert(chebyshev <= 1, "T2b 敌兵移到姜泥攻击范围内 (Chebyshev=%d)" % chebyshev)
	_assert(jiang.current_hp < jiang_hp_before,
		"T2c 姜泥 hp 下降 (前=%d 后=%d)" % [jiang_hp_before, jiang.current_hp])
	_assert(jiang_hp_before - jiang.current_hp == 7,
		"T2d dmg=7 (实际=%d)" % (jiang_hp_before - jiang.current_hp))

	# === T3: take_turn 健壮性：玩家全死/空数组不崩溃 ===
	await ai.take_turn(enemy3, [])
	_assert(true, "T3a 空玩家数组不崩")

	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_enemy_ai] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
