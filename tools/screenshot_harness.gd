extends SceneTree
## screenshot_harness —— 通用截图 harness（godot-dev skill 标准实现）
##
## 用法：
##   godot --path . --script tools/screenshot_harness.gd -- \
##         <scene_res_path> <out_abs_path> [wait_frames] [WxH]
##
## 示例：
##   godot --path . --script tools/screenshot_harness.gd -- \
##         res://scenes/main_menu/main_menu.tscn /abs/out/s1_mainmenu.png 45 1366x768
##
## 约定（不要改）：
## - 不能用 --headless（渲染不会跑，get_texture() 会是空图）
## - autoload 会正常加载（Godot 读取 project.godot 时注入）
## - DisplayServer.window_set_size() 必须在 instantiate 之前调用

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("[screenshot_harness] Usage: <scene_path> <out_path> [wait_frames] [WxH]")
		quit(1)
		return

	var scene_path: String = args[0]
	var out_path: String = args[1]
	var wait_frames: int = int(args[2]) if args.size() >= 3 else 30
	var viewport_size := Vector2i.ZERO
	if args.size() >= 4:
		var parts := String(args[3]).split("x")
		if parts.size() == 2:
			viewport_size = Vector2i(int(parts[0]), int(parts[1]))

	if viewport_size != Vector2i.ZERO:
		DisplayServer.window_set_size(viewport_size)

	var packed := ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		push_error("[screenshot_harness] Failed to load scene: %s" % scene_path)
		quit(2)
		return

	var scene := packed.instantiate()
	root.add_child(scene)

	for _i in wait_frames:
		await process_frame

	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("[screenshot_harness] Failed to get viewport image (did you run with --headless? don't.)")
		quit(3)
		return

	var err := img.save_png(out_path)
	if err != OK:
		push_error("[screenshot_harness] save_png failed err=%s out=%s" % [err, out_path])
		quit(4)
		return

	print("[screenshot_harness] OK scene=%s size=%sx%s out=%s" % [scene_path, img.get_width(), img.get_height(), out_path])
	quit(0)
