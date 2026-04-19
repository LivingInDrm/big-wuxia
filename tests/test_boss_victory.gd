extends SceneTree

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_boss_victory] ==== BEGIN ====")

	var state := root.get_node_or_null("GameState")
	_assert(state != null, "T0 /root/GameState 存在")
	if state == null:
		_finish()
		return
	state.start_level("level_02")
	var battle = await _load_battle_as_current()
	var enemies = battle.get_enemy_units()
	_assert(enemies.size() == 3, "T1a level_02 初始敌军数量=3")

	var boss := enemies[0] as Unit
	var guard := enemies[1] as Unit
	var guard_hp_before := guard.current_hp if guard != null else 0
	_assert(boss != null and boss.unit_data.unit_id == "yang_yuanzan", "T1b 首个敌军是 boss")
	_assert(guard != null and guard.current_hp > 0, "T1c 护卫初始存活")

	if boss != null:
		boss.take_damage(boss.current_hp)
	await _wait_scene_change("Victory")

	var current_name: String = root.get_tree().current_scene.name if root.get_tree().current_scene != null else "<null>"
	_assert(current_name == "Victory", "T2a 击杀 boss 后立即胜利 (实际=%s)" % current_name)
	_assert(guard_hp_before > 0, "T2b 触发胜利前仍有护卫存活，证明并非 kill_all")

	_finish()


func _load_battle_as_current():
	root.get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
	for _i in 60:
		await process_frame
		if root.get_tree().current_scene != null and root.get_tree().current_scene.name == "Battle":
			return root.get_tree().current_scene
	return root.get_tree().current_scene


func _wait_scene_change(target_name: String) -> void:
	for _i in 120:
		await process_frame
		if root.get_tree().current_scene != null and root.get_tree().current_scene.name == target_name:
			return


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_boss_victory] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
