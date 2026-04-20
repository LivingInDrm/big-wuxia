extends SceneTree

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var mode := "smoke"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		mode = String(args[0])

	var packed := ResourceLoader.load(MAIN_MENU_SCENE) as PackedScene
	if packed == null:
		push_error("[settings_smoke] failed to load %s" % MAIN_MENU_SCENE)
		quit(1)
		return

	root.add_child(packed.instantiate())
	for _i in 20:
		await process_frame

	if mode == "probe":
		_print_state("probe")
		quit(0)
		return

	_print_state("startup")

	_settings_bootstrap().apply_settings(Vector2i(1920, 1080), false, true)
	for _i in 12:
		await process_frame
	_print_state("after_apply_1080p")

	_settings_bootstrap().apply_settings(Vector2i(1920, 1080), true, true)
	for _i in 12:
		await process_frame
	_print_state("after_fullscreen")

	_settings_bootstrap().apply_settings(Vector2i(1920, 1080), false, true)
	for _i in 12:
		await process_frame
	_print_state("after_windowed")

	_settings_bootstrap().toggle_fullscreen()
	for _i in 12:
		await process_frame
	_print_state("after_f11_on")

	_settings_bootstrap().toggle_fullscreen()
	for _i in 12:
		await process_frame
	_print_state("after_f11_off")

	var cfg := ConfigFile.new()
	var err := cfg.load("user://settings.cfg")
	print("[settings_smoke] cfg_load=%s width=%s height=%s fullscreen=%s" % [
		err,
		cfg.get_value("display", "width", -1),
		cfg.get_value("display", "height", -1),
		cfg.get_value("display", "fullscreen", null),
	])

	quit(0)


func _print_state(label: String) -> void:
	var settings_bootstrap := _settings_bootstrap()
	print("[settings_smoke] %s size=%s mode=%s stored=%s fullscreen=%s" % [
		label,
		DisplayServer.window_get_size(),
		_mode_name(DisplayServer.window_get_mode()),
		settings_bootstrap.get_window_size(),
		settings_bootstrap.is_fullscreen_enabled(),
	])


func _mode_name(mode: int) -> String:
	match mode:
		DisplayServer.WINDOW_MODE_WINDOWED:
			return "windowed"
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return "fullscreen"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return "exclusive_fullscreen"
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			return "maximized"
		DisplayServer.WINDOW_MODE_MINIMIZED:
			return "minimized"
		_:
			return str(mode)


func _settings_bootstrap() -> Node:
	return root.get_node("SettingsBootstrap")
