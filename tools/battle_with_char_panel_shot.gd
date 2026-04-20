extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const OUTPUT_PATH := "tools/screenshots/battle_with_char_panel.png"
const VIEWPORT := Vector2i(1280, 720)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT)

	var packed := ResourceLoader.load(BATTLE_SCENE) as PackedScene
	if packed == null:
		push_error("[battle_with_char_panel_shot] Failed to load %s" % BATTLE_SCENE)
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)

	for _i in 20:
		await process_frame

	var controller = scene
	var players: Array = controller.get_player_units()
	if players.is_empty():
		push_error("[battle_with_char_panel_shot] no player units")
		quit(2)
		return

	controller.debug_select(players[0])

	for _i in 12:
		await process_frame

	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("[battle_with_char_panel_shot] failed to read viewport image")
		quit(3)
		return

	var output_abs := ProjectSettings.globalize_path("res://" + OUTPUT_PATH)
	var err := image.save_png(output_abs)
	if err != OK:
		push_error("[battle_with_char_panel_shot] save_png failed err=%s path=%s" % [err, output_abs])
		quit(4)
		return

	print("[battle_with_char_panel_shot] saved %s" % output_abs)
	quit(0)
