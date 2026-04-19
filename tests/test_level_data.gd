extends SceneTree

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_level_data] ==== BEGIN ====")

	var balance := root.get_node_or_null("GameBalance")
	var state := root.get_node_or_null("GameState")
	_assert(balance != null, "T0a /root/GameBalance 存在")
	_assert(state != null, "T0b /root/GameState 存在")
	if balance == null or state == null:
		_finish()
		return

	var level_01 = balance.get_level_data("level_01")
	var level_02 = balance.get_level_data("level_02")

	_assert(level_01 != null, "T1a level_01 已加载")
	_assert(level_02 != null, "T1b level_02 已加载")
	if level_01 != null:
		_assert(level_01.player_units.size() == 3, "T1c level_01 玩家布阵数量=3")
		_assert(level_01.enemy_units.size() == 3, "T1d level_01 敌军布阵数量=3")
		_assert(level_01.victory_condition == "kill_all", "T1e level_01 胜利条件=kill_all")
	if level_02 != null:
		_assert(level_02.victory_condition == "kill_boss", "T2a level_02 胜利条件=kill_boss")
		_assert(level_02.boss_id == "yang_yuanzan", "T2b level_02 boss_id 正确")

	state.start_level("level_02")
	var packed := load("res://scenes/battle/battle.tscn") as PackedScene
	var battle = packed.instantiate()
	root.add_child(battle)
	for _i in 20:
		await process_frame

	var battle_level = battle.get_level_data()
	_assert(battle_level != null and battle_level.level_id == "level_02",
		"T3a Battle 按 GameState.current_level 读取 level_02")
	_assert(battle.get_enemy_units().size() == 3, "T3b level_02 战场敌军数量=3")
	if battle.get_enemy_units().size() >= 1:
		_assert(battle.get_enemy_units()[0].unit_data.unit_id == "yang_yuanzan",
			"T3c 首个敌军为 boss 杨元赞")

	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_level_data] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
