extends SceneTree

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const DEFEAT_SCENE := "res://scenes/defeat/defeat.tscn"
const OUT_PATH := "res://tools/screenshots/defeat_ink_v1.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1366, 768))

	# 先加载 MainMenu 触发 GameState / SettingsBootstrap 的 autoload
	change_scene_to_file(MAIN_MENU_SCENE)
	for _i in 30:
		await process_frame

	# GameState 有 start_level 但 defeat.gd 只需要 last_level_id；我们直接写
	var gs := root.get_node_or_null("/root/GameState")
	if gs and gs.has_method("start_level"):
		var gb := root.get_node_or_null("/root/GameBalance")
		if gb and gb.has_method("get_all_levels"):
			var levels: Array = gb.get_all_levels()
			if levels.size() > 0:
				gs.start_level(levels[0].level_id)

	change_scene_to_file(DEFEAT_SCENE)
	for _i in 40:
		await process_frame

	var img := root.get_texture().get_image()
	var abs := ProjectSettings.globalize_path(OUT_PATH)
	var err := img.save_png(abs)
	if err != OK:
		push_error("failed save: err=%s" % err)
		quit(1)
		return
	print("[defeat_shot] saved=%s" % abs)
	quit(0)
