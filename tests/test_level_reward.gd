extends SceneTree

const BATTLE_SCENE = preload("res://scenes/battle/battle.tscn")
const LEVEL_01 = preload("res://resources/data/levels/level_01.tres")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_level_reward] ==== BEGIN ====")
	await _test_level_01_rewards()
	_finish()


func _test_level_01_rewards() -> void:
	var state := root.get_node_or_null("GameState")
	_assert(state != null, "T1a /root/GameState 存在")
	if state == null:
		return

	state.reset()
	state.start_level("level_01")
	var battle = BATTLE_SCENE.instantiate()
	root.add_child(battle)
	for _i in 12:
		await process_frame

	_assert(battle.get_level_data() == LEVEL_01, "T1b Battle 读取 level_01 资源")
	battle._grant_level_rewards()

	_assert(state.inventory.count("jinchuang_yao") == 2, "T1c level_01 奖励金疮药 x2")
	_assert(state.inventory.count("neili_dan") == 1, "T1d level_01 奖励内力丹 x1")

	battle.queue_free()
	await process_frame


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_level_reward] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
