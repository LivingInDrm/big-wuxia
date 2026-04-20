extends SceneTree

const OUTPUT_PATH := "res://tools/screenshots/settings_menu_fixed.png"
const SETTINGS_MENU_SCENE := "res://scenes/ui/settings_menu.tscn"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))

	var main_scene_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene_path.is_empty():
		push_error("[settings_menu_fixed_capture] application/run/main_scene is empty")
		quit(1)
		return

	var err := change_scene_to_file(main_scene_path)
	if err != OK:
		push_error("[settings_menu_fixed_capture] failed to open main scene err=%s path=%s" % [err, main_scene_path])
		quit(2)
		return

	for _i in 24:
		await process_frame

	var main_menu := current_scene
	if main_menu == null:
		push_error("[settings_menu_fixed_capture] current_scene is null after loading main scene")
		quit(3)
		return

	var settings_button := main_menu.get_node_or_null("%SettingsButton") as Button
	if settings_button == null:
		push_error("[settings_menu_fixed_capture] failed to find %SettingsButton in %s" % main_scene_path)
		quit(4)
		return

	settings_button.pressed.emit()
	for _i in 40:
		await process_frame

	if current_scene == null or current_scene.scene_file_path != SETTINGS_MENU_SCENE:
		push_error("[settings_menu_fixed_capture] expected settings scene, got %s" % [current_scene.scene_file_path if current_scene else "<null>"])
		quit(5)
		return

	var resolution_option := current_scene.get_node_or_null("%ResolutionOption") as OptionButton
	var fullscreen_toggle := current_scene.get_node_or_null("%FullscreenToggle") as CheckButton
	var apply_button := current_scene.get_node_or_null("%ApplyButton") as Button
	if resolution_option == null or fullscreen_toggle == null or apply_button == null:
		push_error("[settings_menu_fixed_capture] failed to resolve settings controls")
		quit(6)
		return

	await _save_screenshot()

	var settings_bootstrap := root.get_node_or_null("SettingsBootstrap")
	var original_size := Vector2i(1600, 900)
	var original_fullscreen := false
	if settings_bootstrap != null:
		original_size = settings_bootstrap.get_window_size()
		original_fullscreen = settings_bootstrap.is_fullscreen_enabled()

	resolution_option.select(2)
	fullscreen_toggle.button_pressed = true
	apply_button.pressed.emit()
	for _i in 12:
		await process_frame

	print("[settings_menu_fixed_capture] after_apply size=%s fullscreen=%s mode=%s embedded=%s" % [
		settings_bootstrap.get_window_size() if settings_bootstrap else null,
		settings_bootstrap.is_fullscreen_enabled() if settings_bootstrap else null,
		DisplayServer.window_get_mode(),
		settings_bootstrap.is_embedded_window_mode() if settings_bootstrap else null,
	])

	var restore_index := 0
	for index in range(resolution_option.item_count):
		if resolution_option.get_item_text(index) == "%d×%d" % [original_size.x, original_size.y]:
			restore_index = index
			break

	resolution_option.select(restore_index)
	fullscreen_toggle.button_pressed = original_fullscreen
	apply_button.pressed.emit()
	for _i in 12:
		await process_frame

	print("[settings_menu_fixed_capture] after_restore size=%s fullscreen=%s mode=%s" % [
		settings_bootstrap.get_window_size() if settings_bootstrap else null,
		settings_bootstrap.is_fullscreen_enabled() if settings_bootstrap else null,
		DisplayServer.window_get_mode(),
	])
	quit(0)


func _save_screenshot() -> void:
	for _i in 4:
		await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("[settings_menu_fixed_capture] viewport image unavailable")
		quit(7)
		return

	var output_abs := ProjectSettings.globalize_path(OUTPUT_PATH)
	var err := image.save_png(output_abs)
	if err != OK:
		push_error("[settings_menu_fixed_capture] save_png failed err=%s path=%s" % [err, output_abs])
		quit(8)
		return

	print("[settings_menu_fixed_capture] screenshot=%s" % output_abs)
