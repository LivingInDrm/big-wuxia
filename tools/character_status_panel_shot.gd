extends SceneTree

const PREVIEW_SCENE_PATH := "res://scenes/debug/character_status_panel_preview.tscn"
const WAIT_FRAMES := 50
const VIEWPORT_SIZE := Vector2i(1800, 1000)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("[character_status_panel_shot] Usage: godot --path . --script tools/character_status_panel_shot.gd -- tools/screenshots/character_status_panel_v1.png")
		quit(1)
		return

	var out_path := ProjectSettings.globalize_path("res://%s" % args[0].trim_prefix("res://"))
	if not args[0].begins_with("res://"):
		out_path = ProjectSettings.globalize_path("res://%s" % args[0].trim_prefix("./"))

	DisplayServer.window_set_size(VIEWPORT_SIZE)

	var packed := load(PREVIEW_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[character_status_panel_shot] Failed to load scene: %s" % PREVIEW_SCENE_PATH)
		quit(2)
		return

	var scene := packed.instantiate()
	root.add_child(scene)

	for _i in WAIT_FRAMES:
		await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("[character_status_panel_shot] Failed to capture viewport image")
		quit(3)
		return

	var err := image.save_png(out_path)
	if err != OK:
		push_error("[character_status_panel_shot] save_png failed err=%s out=%s" % [err, out_path])
		quit(4)
		return

	print("[character_status_panel_shot] OK out=%s size=%sx%s" % [out_path, image.get_width(), image.get_height()])
	quit(0)
