extends SceneTree

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"
const WUDANG_SCENE := "res://scenes/overworld/poi_map_wudang.tscn"
const BEILIANG_SCENE := "res://scenes/overworld/poi_map_beiliang.tscn"
const SCREENSHOT_DIR := "res://tools/screenshots"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
	var game_state: Node = root.get_node("GameState")
	var scene_manager: Node = root.get_node("SceneManager")
	var poi_registry: Node = root.get_node("POIRegistry")
	game_state.reset()

	await scene_manager.change_scene_to_file(MAIN_MENU_SCENE)
	await _wait_frames(6)
	await scene_manager.change_scene_to_file(OVERWORLD_SCENE)
	await _wait_for_scene(OVERWORLD_SCENE)

	var overworld := current_scene
	var overworld_player := overworld.get_node("Player") as CharacterBody2D
	var overworld_player_area := overworld.get_node("Player/PlayerInteractionArea") as Area2D
	overworld_player.global_position = Vector2(900, 540)
	await _wait_frames(8)
	await _save_screenshot("p5_s3_overworld.png")

	var wudang_marker := overworld.get_node("POINodes/POI_Wudang")
	wudang_marker._on_area_entered(overworld_player_area)
	game_state.overworld_player_position = overworld_player.global_position
	await scene_manager.change_scene_to_file(WUDANG_SCENE)
	await _wait_for_scene(WUDANG_SCENE)

	var wudang := current_scene
	var wudang_player := wudang.get_node("Player") as CharacterBody2D
	var wudang_player_area := wudang.get_node("Player/PlayerInteractionArea") as Area2D
	var hong_node := wudang.get_node("NPCNodes/NPC_HongXiXiang")
	wudang_player.global_position = Vector2(1040, 760)
	await _wait_frames(8)
	await _save_screenshot("p5_s3_poi_wudang.png")

	wudang_player.global_position = hong_node.global_position + Vector2(-24, 18)
	hong_node._on_area_entered(wudang_player_area)
	await _wait_frames(8)
	await _save_screenshot("p5_s3_interaction_hint.png")

	var exit_area := wudang.get_node("ExitArea")
	wudang_player.global_position = exit_area.global_position
	wudang._on_exit_area_entered(wudang_player_area)
	game_state.return_context = {
		"from_poi": true,
		"poi_id": "wudang",
		"player_position_in_poi": wudang_player.global_position,
	}
	await scene_manager.change_scene_to_file(OVERWORLD_SCENE)
	await _wait_for_scene(OVERWORLD_SCENE)

	var returned_overworld := current_scene
	var returned_player := returned_overworld.get_node("Player") as CharacterBody2D
	var expected_return: Vector2 = poi_registry.get_data("wudang").position_on_overworld + poi_registry.get_data("wudang").overworld_return_offset
	if returned_player.global_position.distance_to(expected_return) > 1.0:
		push_error("[p5_s3_smoke] Overworld return position mismatch: %s vs %s" % [returned_player.global_position, expected_return])
		quit(1)
		return

	var returned_area := returned_overworld.get_node("Player/PlayerInteractionArea") as Area2D
	var beiliang_marker := returned_overworld.get_node("POINodes/POI_Beiliang")
	returned_player.global_position = Vector2(420, 620)
	await _wait_frames(8)
	beiliang_marker._on_area_entered(returned_area)
	game_state.overworld_player_position = returned_player.global_position
	await scene_manager.change_scene_to_file(BEILIANG_SCENE)
	await _wait_for_scene(BEILIANG_SCENE)
	await _wait_frames(8)
	await _save_screenshot("p5_s3_poi_beiliang.png")

	print("[p5_s3_smoke] smoke ok")
	quit(0)


func _wait_for_scene(path: String) -> bool:
	var timeout_frames := 120
	while timeout_frames > 0:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			await _wait_frames(6)
			return true
		timeout_frames -= 1
	push_error("[p5_s3_smoke] Timed out waiting for scene: %s" % path)
	return false


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _save_screenshot(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [SCREENSHOT_DIR, file_name]))
