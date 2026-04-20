extends SceneTree

const OUT_PATH := "res://tools/screenshots/p5_s2_dialogue_box.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1366, 768))

	var dialogue_system = root.get_node_or_null("DialogueSystem")
	var dialogue_registry = root.get_node_or_null("DialogueRegistry")
	var game_state = root.get_node_or_null("GameState")
	if dialogue_system == null or dialogue_registry == null or game_state == null:
		push_error("[p5_s2_dialogue_screenshot] missing autoload(s)")
		quit(1)
		return

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#2A2219")
	root.add_child(background)

	dialogue_registry.reload()
	game_state.reset()
	dialogue_system.char_speed = 1
	if not dialogue_system.start("wudang_hong_first_meet"):
		push_error("[p5_s2_dialogue_screenshot] failed to start dialogue")
		quit(1)
		return

	dialogue_system.advance()
	await process_frame
	await process_frame

	var image: Image = root.get_texture().get_image()
	var save_err := image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if save_err != OK:
		push_error("[p5_s2_dialogue_screenshot] save_png failed err=%s" % save_err)
		quit(1)
		return

	print("[p5_s2_dialogue_screenshot] saved %s" % ProjectSettings.globalize_path(OUT_PATH))
	quit(0)
