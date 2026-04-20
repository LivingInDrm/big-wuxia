extends SceneTree

const VIEWPORT := Vector2i(1366, 768)
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"
const SCREENSHOT_DIR := "res://tools/screenshots"

var _shot_index: int = 1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
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
	dialogue_system.char_speed = 1

	change_scene_to_file(MAIN_MENU_SCENE)
	await _wait_for_scene_ready("MainMenu")
	_save_step("01_main_menu")

	game_state.reset()
	change_scene_to_file(OVERWORLD_SCENE)
	await _wait_for_scene_ready("Overworld")
	_save_step("02_overworld_start")

	await _enter_poi("beiliang", "POIMapBeiliang")
	_save_step("03_beiliang_poi")
	await _play_dialogue("beiliang.xu_xiao_main", 0)
	_save_step("04_xu_xiao_dialogue")
	_assert(game_state.get_flag("beiliang.xu_xiao_met", false), "beiliang.xu_xiao_met 已写入")
	await _return_to_overworld("beiliang")
	_save_step("05_overworld_after_beiliang")

	await _enter_poi("wudang", "POIMapWudang")
	_save_step("06_wudang_poi")
	await _play_dialogue("wudang.hong_first_meet", 2)
	if current_scene == null or current_scene.name != "Battle":
		change_scene_to_file("res://scenes/battle/battle.tscn")
	await _wait_for_scene_ready("Battle")
	_save_step("07_battle_loaded")

	var battle = current_scene
	change_scene_to_file("res://scenes/victory/victory.tscn")
	await _wait_for_scene_ready("Victory")
	_save_step("08_victory")

	change_scene_to_file("res://scenes/overworld/poi_map_wudang.tscn")
	await _wait_for_scene_ready("POIMapWudang")
	_save_step("09_wudang_returned")
	await _play_dialogue("wudang.hong_after_battle")
	_save_step("10_hong_after_battle")
	_assert(game_state.get_flag("wudang.hong_defeated", false), "wudang.hong_defeated 已写入")
	_assert(game_state.get_flag("qingliang.unlocked", false), "qingliang.unlocked 已写入")

	await _return_to_overworld("wudang")
	_save_step("11_overworld_qingliang_visible")
	var qingliang_marker = current_scene.get_node("POINodes/POI_Qingliang")
	_assert(qingliang_marker.visible == true, "qingliang marker 已可见")

	await _enter_poi("qingliang", "POIMapQingliang")
	_save_step("12_qingliang_poi")
	await _play_dialogue("qingliang.jiang_ni_main", 0)
	_save_step("13_jiang_ni_dialogue")
	_assert(game_state.get_flag("qingliang.jiang_ni_met", false), "qingliang.jiang_ni_met 已写入")

	print("MAIN LINE COMPLETE")
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	quit(0)


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


func _play_dialogue(dialogue_id: String, choice_index: int = -1) -> void:
	var dialogue_system = root.get_node("/root/DialogueSystem")
	dialogue_system.start(dialogue_id)
	await _wait_frames(2)
	while dialogue_system.current_node != null:
		if dialogue_system.current_node.choices.size() > 0 and choice_index >= 0:
			await _reveal_current(dialogue_system)
			dialogue_system.select_choice(choice_index)
			await process_frame
			choice_index = -1
			continue
		await _advance_dialogue_once(dialogue_system)
		if dialogue_system.current_dialogue_id == "":
			break


func _finish_current_dialogue() -> void:
	var dialogue_system = root.get_node("/root/DialogueSystem")
	while dialogue_system.current_node != null:
		await _advance_dialogue_once(dialogue_system)
		if dialogue_system.current_dialogue_id == "":
			return


func _advance_dialogue_once(dialogue_system) -> void:
	dialogue_system.advance()
	await process_frame
	if dialogue_system.current_node != null and dialogue_system.current_dialogue_id != "":
		dialogue_system.advance()
		await process_frame


func _reveal_current(dialogue_system) -> void:
	dialogue_system.advance()
	await process_frame


func _wait_for_scene_ready(scene_name: String, max_frames: int = 300) -> void:
	for _i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == scene_name:
			await _wait_frames(30)
			return
	push_error("[p5_s4_main_flow_e2e] timed out waiting for %s" % scene_name)
	quit(1)


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _save_step(label: String) -> void:
	var abs_path := ProjectSettings.globalize_path("%s/p5_s4_flow_%02d_%s.png" % [SCREENSHOT_DIR, _shot_index, label])
	_shot_index += 1
	if DisplayServer.get_name() == "headless":
		push_warning("[p5_s4_main_flow_e2e] skip screenshot=%s on headless" % label)
		return
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_warning("[p5_s4_main_flow_e2e] skip screenshot=%s viewport_texture=null" % label)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_warning("[p5_s4_main_flow_e2e] skip screenshot=%s image=null" % label)
		return
	var err := image.save_png(abs_path)
	if err != OK:
		push_error("[p5_s4_main_flow_e2e] save_png failed err=%s path=%s" % [err, abs_path])
		quit(2)


func _assert(ok: bool, msg: String) -> void:
	if ok:
		print("[ASSERT PASS] %s" % msg)
	else:
		push_error("[ASSERT FAIL] %s" % msg)
		quit(3)
