extends SceneTree

const VIEWPORT := Vector2i(1366, 768)
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"
const SCREENSHOT_DIR := "res://tools/screenshots"

var _shot_index: int = 1
var _dialogue_node_visits: int = 0
var _set_flags: PackedStringArray = PackedStringArray()
var _started_at_ms: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[p5_s5_full_playthrough] requires a non-headless display driver")
		quit(2)
		return

	_started_at_ms = Time.get_ticks_msec()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VIEWPORT)

	var game_state = root.get_node("/root/GameState")
	var dialogue_system = root.get_node("/root/DialogueSystem")
	var dialogue_registry = root.get_node("/root/DialogueRegistry")
	var poi_registry = root.get_node("/root/POIRegistry")
	var npc_registry = root.get_node("/root/NPCRegistry")
	game_state.reset()
	dialogue_registry.reload()
	poi_registry.reload()
	npc_registry.reload()
	dialogue_system.char_speed = 0
	dialogue_system.instant_mode = true
	if not dialogue_system.node_changed.is_connected(_on_dialogue_node_changed):
		dialogue_system.node_changed.connect(_on_dialogue_node_changed)
	if not dialogue_system.action_executed.is_connected(_on_action_executed):
		dialogue_system.action_executed.connect(_on_action_executed)

	change_scene_to_file(MAIN_MENU_SCENE)
	await _wait_for_scene_ready("MainMenu")
	await _save_step("01_main_menu")

	var main_menu := current_scene
	var start_button := main_menu.get_node("ButtonContainer/StartButton") as Button
	start_button.pressed.emit()
	await _wait_for_scene_ready("Overworld")
	await _save_step("02_overworld_start")

	await _focus_marker("beiliang", "03_beiliang_hover")
	await _enter_poi("beiliang", "POIMapBeiliang")
	await _save_step("04_beiliang_poi")
	await _play_dialogue("beiliang.xu_xiao_main", 0, ["05_xu_xiao_open", "06_xu_xiao_branch", "07_xu_xiao_end"])
	await _return_to_overworld("beiliang")
	await _save_step("08_overworld_after_beiliang")

	await _focus_marker("wudang", "09_wudang_hover")
	await _enter_poi("wudang", "POIMapWudang")
	await _save_step("10_wudang_poi")
	await _play_dialogue("wudang.hong_first_meet", 2, ["11_hong_open", "12_hong_choice", "13_hong_before_battle"])

	await _wait_for_scene_ready("Battle")
	await _save_step("14_battle_loaded")
	change_scene_to_file("res://scenes/victory/victory.tscn")
	await _wait_for_scene_ready("Victory")
	await _save_step("15_victory")

	change_scene_to_file("res://scenes/overworld/poi_map_wudang.tscn")
	await _wait_for_scene_ready("POIMapWudang")
	await _save_step("16_wudang_returned")
	await _play_dialogue("wudang.hong_after_battle", -1, ["17_hong_after_battle_open", "18_hong_after_battle_end"])
	await _return_to_overworld("wudang")
	await _save_step("19_overworld_qingliang_unlocked")
	var qingliang_marker := current_scene.get_node("POINodes/POI_Qingliang")
	_assert(qingliang_marker.visible == true, "qingliang marker 已解锁可见")

	await _focus_marker("qingliang", "20_qingliang_hover")
	await _enter_poi("qingliang", "POIMapQingliang")
	await _save_step("21_qingliang_poi")
	await _play_dialogue("qingliang.jiang_ni_main", 0, ["22_jiang_ni_open", "23_jiang_ni_branch", "24_jiang_ni_end"])

	var duration_sec := (Time.get_ticks_msec() - _started_at_ms) / 1000.0
	print("[p5_s5_full_playthrough] duration_sec=%.2f" % duration_sec)
	print("[p5_s5_full_playthrough] dialogue_nodes=%d" % _dialogue_node_visits)
	print("[p5_s5_full_playthrough] set_flags=%s" % JSON.stringify(_set_flags))
	print("FULL PLAYTHROUGH OK")
	quit(0)


func _focus_marker(poi_id: String, screenshot_label: String) -> void:
	if current_scene == null:
		return
	var marker := current_scene.get_node("POINodes/POI_%s" % _poi_node_suffix(poi_id)) as Node2D
	var player := current_scene.get_node("Player") as Node2D
	player.global_position = marker.global_position + Vector2(60.0, 0.0)
	current_scene._process(0.2)
	await _wait_frames(8)
	await _save_step(screenshot_label)


func _enter_poi(poi_id: String, scene_name: String) -> void:
	var game_state = root.get_node("/root/GameState")
	var poi_registry = root.get_node("/root/POIRegistry")
	var poi_data = poi_registry.get_data(poi_id)
	if current_scene != null and current_scene.has_node("Player"):
		game_state.overworld_player_position = current_scene.get_node("Player").global_position
	game_state.location = "poi:%s" % poi_id
	change_scene_to_file(poi_data.scene_path)
	await _wait_for_scene_ready(scene_name)


func _return_to_overworld(poi_id: String) -> void:
	var game_state = root.get_node("/root/GameState")
	var player_node := current_scene.get_node_or_null("Player") as Node2D
	game_state.return_context = {
		"from_poi": true,
		"poi_id": poi_id,
		"player_position_in_poi": player_node.global_position if player_node != null else Vector2.ZERO,
	}
	game_state.location = "overworld"
	change_scene_to_file(OVERWORLD_SCENE)
	await _wait_for_scene_ready("Overworld")


func _play_dialogue(dialogue_id: String, choice_index: int = -1, screenshot_labels: Array[String] = []) -> void:
	var dialogue_system = root.get_node("/root/DialogueSystem")
	dialogue_system.start(dialogue_id)
	await _wait_frames(2)
	if screenshot_labels.size() > 0:
		await _save_step(screenshot_labels[0])

	var shot_index := 1
	while dialogue_system.current_node != null:
		if dialogue_system.current_node.choices.size() > 0 and choice_index >= 0:
			if shot_index < screenshot_labels.size():
				await _save_step(screenshot_labels[shot_index])
				shot_index += 1
			dialogue_system.select_choice(choice_index)
			await process_frame
			choice_index = -1
			continue
		await _advance_dialogue_once(dialogue_system)
		if dialogue_system.current_dialogue_id == "":
			break

	if shot_index < screenshot_labels.size():
		await _save_step(screenshot_labels[shot_index])


func _advance_dialogue_once(dialogue_system) -> void:
	dialogue_system.advance()
	await process_frame
	if dialogue_system.current_node != null and dialogue_system.current_dialogue_id != "":
		dialogue_system.advance()
		await process_frame


func _wait_for_scene_ready(scene_name: String, max_frames: int = 300) -> void:
	for _i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == scene_name:
			await _wait_frames(15)
			return
	push_error("[p5_s5_full_playthrough] timed out waiting for %s" % scene_name)
	quit(1)


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _save_step(label: String) -> void:
	var abs_path := ProjectSettings.globalize_path("%s/p5_s5_playthrough_%02d_%s.png" % [SCREENSHOT_DIR, _shot_index, label])
	_shot_index += 1
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("[p5_s5_full_playthrough] viewport_texture unavailable for %s" % label)
		quit(3)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("[p5_s5_full_playthrough] viewport image unavailable for %s" % label)
		quit(3)
		return
	var err := image.save_png(abs_path)
	if err != OK:
		push_error("[p5_s5_full_playthrough] save_png failed err=%s path=%s" % [err, abs_path])
		quit(3)
		return
	print("[p5_s5_full_playthrough] screenshot=%s" % abs_path)


func _poi_node_suffix(poi_id: String) -> String:
	match poi_id:
		"beiliang":
			return "Beiliang"
		"wudang":
			return "Wudang"
		"qingliang":
			return "Qingliang"
		_:
			return poi_id.capitalize()


func _on_dialogue_node_changed(_node) -> void:
	_dialogue_node_visits += 1


func _on_action_executed(action) -> void:
	if action == null or action.type != "set_flag":
		return
	var payload: Dictionary = action.payload
	var flag_key := String(payload.get("key", payload.get("flag", "")))
	if flag_key.is_empty():
		return
	if flag_key not in _set_flags:
		_set_flags.append(flag_key)


func _assert(ok: bool, msg: String) -> void:
	if ok:
		print("[ASSERT PASS] %s" % msg)
		return
	push_error("[ASSERT FAIL] %s" % msg)
	quit(4)
