extends SceneTree

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_skill_cd] ==== BEGIN ====")
	var packed := load("res://scenes/battle/battle.tscn") as PackedScene
	var battle = packed.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	var xu: Unit = battle.get_player_units()[0]
	var skill = xu.get_skill(1)
	await SkillExecutor.execute_skill(xu, skill, Vector2i(6, 2), battle.get_grid(), CombatSystem)
	_assert(skill.current_cd == 2, "T1 两袖青蛇释放后 current_cd=2 (实际=%d)" % skill.current_cd)

	battle.get_turn_manager()._next_turn()
	await process_frame
	_assert(skill.current_cd == 1, "T2 下一回合后 current_cd=1 (实际=%d)" % skill.current_cd)

	battle.get_turn_manager()._next_turn()
	await process_frame
	_assert(skill.current_cd == 0, "T3 再下一回合后 current_cd=0 (实际=%d)" % skill.current_cd)

	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_skill_cd] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
