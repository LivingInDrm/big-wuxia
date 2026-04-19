extends SceneTree

const CHARACTER_PANEL_SCENE = preload("res://scenes/character_panel/character_panel.tscn")
const ItemData = preload("res://scripts/core/item_data.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("[p3_character_screenshot] Usage: <xu|popup|jiang> <out_abs_path>")
		quit(1)
		return

	var shot_name := String(args[0])
	var out_path := String(args[1])

	DisplayServer.window_set_size(Vector2i(1600, 900))

	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		push_error("[p3_character_screenshot] GameState missing")
		quit(2)
		return

	game_state.reset()
	if shot_name == "popup":
		game_state.inventory.add("heal_amulet")
		game_state.inventory.add("jade_pendant")

	var panel := CHARACTER_PANEL_SCENE.instantiate()
	root.add_child(panel)
	await process_frame
	await process_frame

	match shot_name:
		"xu":
			pass
		"popup":
			var acc1_button := panel.call("get_slot_button", ItemData.EquipSlot.ACCESSORY_1) as Button
			if acc1_button != null:
				acc1_button.pressed.emit()
		"jiang":
			var jiang_button := panel.call("get_character_button", "jiang_ni") as Button
			if jiang_button != null:
				jiang_button.pressed.emit()
		_:
			push_error("[p3_character_screenshot] Unknown shot %s" % shot_name)
			quit(3)
			return

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw

	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("[p3_character_screenshot] Failed to read viewport image")
		quit(4)
		return

	var err := image.save_png(out_path)
	if err != OK:
		push_error("[p3_character_screenshot] save_png failed err=%s path=%s" % [err, out_path])
		quit(5)
		return

	print("[p3_character_screenshot] saved %s" % out_path)
	quit(0)
