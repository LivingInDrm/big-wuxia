extends SceneTree
## test_move_and_attack —— S4 移动/攻击范围 + 伤害结算单测
##
## 用法：godot --headless --path . --script tests/test_move_and_attack.gd
##
## 覆盖：
##   T1  get_move_range 基础：徐凤年 move_range=4 从 (5,5) 在空旷地图可达数 ≤ 期望
##   T2  get_move_range 不含起点；不含被占用格子
##   T3  get_attack_range weapon_range=1 → 8 格
##   T4  get_attack_range weapon_range=2 → 24 格（5x5 - 1）
##   T5  find_path 产出合法 path（连续、无障碍、长度合理）
##   T6  CombatSystem.calc_damage: max(1, attack-defense)
##   T7  Unit.take_damage 正确扣血 + HP 条更新
##   T8  BattleController.debug_move 流程：occupant 更新 + 位置变化
##   T9  BattleController.debug_attack 流程：敌兵 HP 下降

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_move_and_attack] ==== BEGIN ====")

	# --- T1~T5: GridSystem 算法（用空壳 grid，不走 TileMapLayer） ---
	var grid := _build_plain_grid(12, 10)
	# T1
	var r := grid.get_move_range(Vector2i(5, 5), 4, false)
	_assert(not r.is_empty(), "T1 get_move_range 非空")
	_assert(not r.has(Vector2i(5, 5)), "T2a 不含起点")
	# Manhattan ≤ 4 的格子数量为 1+4+8+12+16=41 个（含自身）；去掉自身 40；边界在中央不受影响
	_assert(r.size() == 40, "T1b move_range=4 在空旷地图可达 40 格 (实际=%d)" % r.size())

	# T2: 占用格子不能落脚
	grid.get_tile(Vector2i(5, 6)).occupant = Node.new()
	var r2 := grid.get_move_range(Vector2i(5, 5), 4, false)
	_assert(not r2.has(Vector2i(5, 6)), "T2b 被占用的格子不在 move_range")

	# T3/T4: attack_range
	var a1 := grid.get_attack_range(Vector2i(5, 5), 1)
	_assert(a1.size() == 8, "T3 weapon_range=1 → 8 格 (实际=%d)" % a1.size())
	var a2 := grid.get_attack_range(Vector2i(5, 5), 2)
	_assert(a2.size() == 24, "T4 weapon_range=2 → 24 格 (实际=%d)" % a2.size())

	# T5: find_path
	var path := grid.find_path(Vector2i(2, 2), Vector2i(5, 4), false)
	_assert(not path.is_empty(), "T5a find_path 非空")
	_assert(path.back() == Vector2i(5, 4), "T5b 终点 == to")
	_assert(not path.has(Vector2i(2, 2)), "T5c 不含起点")
	# Manhattan = 3+2 = 5 步
	_assert(path.size() == 5, "T5d path 长度=5 (实际=%d)" % path.size())
	# 每步连续（Chebyshev=1）
	var prev := Vector2i(2, 2)
	var continuous := true
	for step in path:
		if abs(step.x - prev.x) + abs(step.y - prev.y) != 1:
			continuous = false
			break
		prev = step
	_assert(continuous, "T5e path 步步连续")

	# T6: damage 公式
	_assert(CombatSystem.calc_damage(8, 3) == 5, "T6a 8-3=5")
	_assert(CombatSystem.calc_damage(5, 5) == 1, "T6b 5-5=max(1,0)=1")
	_assert(CombatSystem.calc_damage(2, 10) == 1, "T6c 2-10=max(1,-8)=1")

	# --- T7~T9: Unit + BattleController 集成 ---
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	var battle = packed.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	var xu: Unit = battle.get_player_units()[0]
	_assert(xu.unit_data.unit_id == "xu_fengnian", "T7 setup: 第一玩家是徐凤年")
	_assert(xu.current_hp == 105, "T7a 初始 hp=105")

	# T7: take_damage
	xu.take_damage(10)
	await process_frame
	_assert(xu.current_hp == 95, "T7b take_damage(10) → hp=95 (实际=%d)" % xu.current_hp)
	_assert(xu.health_bar.value == 95.0, "T7c health_bar.value=95")

	# T8: debug_move
	var enemy_a: Unit = battle.get_enemy_units()[0]
	var pre_pos := xu.current_position
	# 目标：往东移 3 格（move_range=4 足够）
	var target := pre_pos + Vector2i(3, 0)
	await battle.debug_move(xu, target)
	_assert(xu.current_position == target,
		"T8a debug_move 后 position=%s (期望=%s)" % [str(xu.current_position), str(target)])
	var g: GridSystem = battle.get_grid()
	_assert(g.get_tile(target).occupant == xu, "T8b 新位置 occupant == xu")
	_assert(g.get_tile(pre_pos).occupant == null, "T8c 旧位置 occupant 已清")

	# T9: debug_attack（先把敌兵挪到相邻）
	g.get_tile(enemy_a.current_position).occupant = null
	enemy_a.current_position = xu.current_position + Vector2i(1, 0)
	enemy_a.position = Vector2(
		enemy_a.current_position.x * 64 + 32,
		enemy_a.current_position.y * 64 + 32)
	g.get_tile(enemy_a.current_position).occupant = enemy_a
	var enemy_pre_hp := enemy_a.current_hp
	await battle.debug_attack(xu, enemy_a)
	await process_frame
	_assert(enemy_a.current_hp < enemy_pre_hp,
		"T9a 敌兵 hp 下降 (前=%d 后=%d)" % [enemy_pre_hp, enemy_a.current_hp])
	# dmg = max(1, attack(28) - defense(7)) = 21
	_assert(enemy_pre_hp - enemy_a.current_hp == 21,
		"T9b dmg=21 (实际=%d)" % (enemy_pre_hp - enemy_a.current_hp))

	_finish()


## 构造一个纯 grass（无 TileMapLayer）的 12x10 grid 用于算法测试。
func _build_plain_grid(cols: int, rows: int) -> GridSystem:
	var g := GridSystem.new()
	root.add_child(g)
	var terrain: TerrainTileData = load("res://resources/data/tiles/grass.tres")
	for x in cols:
		for y in rows:
			var tile := GridTile.new(Vector2i(x, y), terrain)
			g.tiles[Vector2i(x, y)] = tile
	return g


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_move_and_attack] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
