extends SceneTree

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_victory_defeat] ==== BEGIN ====")
	await _test_victory()
	await _wait_idle_frames(60)
	await _test_defeat()
	_finish()


func _test_victory() -> void:
	var battle = await _load_battle_as_current()
	for enemy: Unit in battle.get_enemy_units().duplicate():
		enemy.take_damage(enemy.current_hp)
	await _wait_scene_change("Victory")
	_assert(root.get_tree().current_scene != null and root.get_tree().current_scene.name == "Victory",
		"T1 击杀所有敌人后切到 Victory")


func _test_defeat() -> void:
	var battle = await _load_battle_as_current()
	for player: Unit in battle.get_player_units().duplicate():
		player.take_damage(player.current_hp)
	await _wait_scene_change("Defeat")
	var current_name: String = root.get_tree().current_scene.name if root.get_tree().current_scene != null else "<null>"
	_assert(root.get_tree().current_scene != null and root.get_tree().current_scene.name == "Defeat",
		"T2 我方全灭后切到 Defeat (实际=%s)" % current_name)


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


func _wait_idle_frames(count: int) -> void:
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
	print("[test_victory_defeat] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
