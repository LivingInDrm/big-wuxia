extends SceneTree

const POI_WUDANG_SCENE := "res://scenes/overworld/poi_map_wudang.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

var _pass: int = 0
var _fail: int = 0
var _change_scene_calls: Array[String] = []
var _dialogue_started_ids: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_p5_battle_flow] ==== BEGIN ====")

	var scene_manager: Node = root.get_node_or_null("SceneManager")
	var dialogue_system = root.get_node_or_null("DialogueSystem")
	var dialogue_registry = root.get_node_or_null("DialogueRegistry")
	var game_state = root.get_node_or_null("GameState")
	_assert(scene_manager != null, "T0a /root/SceneManager 存在")
	_assert(dialogue_system != null, "T0b /root/DialogueSystem 存在")
	_assert(dialogue_registry != null, "T0c /root/DialogueRegistry 存在")
	_assert(game_state != null, "T0d /root/GameState 存在")
	if scene_manager == null or dialogue_system == null or dialogue_registry == null or game_state == null:
		_finish()
		return

	scene_manager.set_script(load("res://tests/helpers/scene_manager_spy.gd"))
	scene_manager.set_meta("spy_change_scene", Callable(self, "_spy_on_change_scene"))
	dialogue_registry.reload()
	game_state.reset()
	dialogue_system.char_speed = 1
	if not dialogue_system.dialogue_started.is_connected(_on_dialogue_started):
		dialogue_system.dialogue_started.connect(_on_dialogue_started)

	await _test_dialogue_start_battle(dialogue_system, game_state)
	await _test_victory_route(game_state)
	await _test_defeat_route(game_state)
	await _test_poi_auto_dialogue(game_state, dialogue_system)

	_finish()


func _test_dialogue_start_battle(dialogue_system, game_state) -> void:
	_change_scene_calls.clear()
	change_scene_to_file(POI_WUDANG_SCENE)
	await _wait_for_scene("POIMapWudang")

	var poi_scene := current_scene
	var player := poi_scene.get_node("Player") as Node2D
	player.global_position = Vector2(1111, 666)
	game_state.location = "poi:wudang"

	var started: bool = dialogue_system.start("wudang.hong_first_meet")
	_assert(started, "T1a wudang.hong_first_meet 可启动")
	await _reveal_and_advance(dialogue_system)
	await _reveal_and_advance(dialogue_system)
	await _reveal_current(dialogue_system)
	dialogue_system.select_choice(2)
	await process_frame
	await _reveal_and_advance(dialogue_system)
	await process_frame

	_assert(_change_scene_calls.size() == 1, "T1b start_battle 触发 1 次切场")
	if _change_scene_calls.size() >= 1:
		_assert(_change_scene_calls[0] == BATTLE_SCENE, "T1c start_battle 切到 battle.tscn")
	_assert(game_state.current_level == "level_01", "T1d start_battle 写入 current_level")
	_assert(game_state.location == "battle", "T1e begin_battle_from 后 location=battle")
	_assert(game_state.overworld_player_position == Vector2(1111, 666), "T1f begin_battle_from 保存当前 POI 玩家坐标")
	_assert(String(game_state.return_context.get("return_to_poi", "")) == "wudang", "T1g return_to_poi=wudang")
	_assert(String(game_state.return_context.get("on_victory_dialogue", "")) == "wudang.hong_after_battle", "T1h 胜利后对话 id 正确")
	_assert(String(game_state.return_context.get("on_defeat_dialogue", "")) == "wudang.hong_defeat", "T1i 失败后对话 id 正确")
	_assert(bool(game_state.return_context.get("allow_retry", false)) == true, "T1j allow_retry=true")
	_assert(dialogue_system.current_dialogue_id == "", "T1k start_battle 前会先 end 对话")


func _test_victory_route(game_state) -> void:
	_change_scene_calls.clear()
	game_state.return_context = {
		"allow_retry": true,
		"from_battle": true,
		"on_victory_dialogue": "wudang.hong_after_battle",
		"return_scene": POI_WUDANG_SCENE,
		"return_to_poi": "wudang"
	}
	var packed := load("res://scenes/victory/victory.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("%ReturnButton").pressed.emit()
	await process_frame
	_assert(_change_scene_calls.size() == 1, "T2a victory 返回按钮触发切场")
	if _change_scene_calls.size() >= 1:
		_assert(_change_scene_calls[0] == POI_WUDANG_SCENE, "T2b victory 走 return_context 回 wudang")
	_assert(String(game_state.return_context.get("battle_result", "")) == "victory", "T2c victory 写入 battle_result")
	scene.queue_free()
	await process_frame


func _test_defeat_route(game_state) -> void:
	_change_scene_calls.clear()
	game_state.return_context = {
		"allow_retry": true,
		"from_battle": true,
		"on_defeat_dialogue": "wudang.hong_defeat",
		"return_scene": POI_WUDANG_SCENE,
		"return_to_poi": "wudang"
	}
	var packed := load("res://scenes/defeat/defeat.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	var retry_button := scene.get_node("%RetryButton") as Button
	var return_button := scene.get_node("%ReturnButton") as Button
	_assert(retry_button.visible == true, "T3a allow_retry=true 时显示重试按钮")
	retry_button.pressed.emit()
	await process_frame
	_assert(_change_scene_calls.size() == 1 and _change_scene_calls[0] == BATTLE_SCENE, "T3b defeat 重试会重进 battle")
	_change_scene_calls.clear()
	return_button.pressed.emit()
	await process_frame
	_assert(_change_scene_calls.size() == 1 and _change_scene_calls[0] == POI_WUDANG_SCENE, "T3c defeat 返回会回 wudang")
	_assert(String(game_state.return_context.get("battle_result", "")) == "defeat", "T3d abort_battle 写入 defeat")
	_assert(not game_state.return_context.has("on_defeat_dialogue"), "T3e abort_battle 不保留 defeat 对话")
	scene.queue_free()
	await process_frame


func _test_poi_auto_dialogue(game_state, dialogue_system) -> void:
	_dialogue_started_ids.clear()
	dialogue_system.end(false)
	game_state.return_context = {
		"battle_result": "victory",
		"entry_spawn_name": "EntrySpawn",
		"from_battle": true,
		"on_victory_dialogue": "wudang.hong_after_battle",
		"return_to_poi": "wudang"
	}
	var packed := load(POI_WUDANG_SCENE) as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var entry_spawn := scene.get_node("EntrySpawn") as Marker2D
	var player := scene.get_node("Player") as Node2D
	_assert(player.global_position == entry_spawn.global_position, "T4a from_battle 回 POI 时落在 EntrySpawn")
	_assert(game_state.return_context.is_empty(), "T4b POI _ready 后清空 return_context")
	_assert(_dialogue_started_ids.has("wudang.hong_after_battle"), "T4c 回 POI 后自动触发 on_victory_dialogue")
	_assert(dialogue_system.current_dialogue_id == "wudang.hong_after_battle", "T4d 当前对话切到 hong_after_battle")
	scene.queue_free()
	dialogue_system.end(false)
	await process_frame


func _reveal_current(dialogue_system) -> void:
	dialogue_system.advance()
	await process_frame


func _reveal_and_advance(dialogue_system) -> void:
	dialogue_system.advance()
	await process_frame
	dialogue_system.advance()
	await process_frame


func _wait_for_scene(scene_name: String, max_frames: int = 120) -> void:
	for _i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == scene_name:
			return


func _spy_on_change_scene(path: String) -> void:
	_change_scene_calls.append(path)


func _on_dialogue_started(dialogue_id: String) -> void:
	_dialogue_started_ids.append(dialogue_id)


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_p5_battle_flow] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
