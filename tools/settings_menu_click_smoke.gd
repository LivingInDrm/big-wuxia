extends SceneTree

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const SETTINGS_MENU_SCENE := "res://scenes/ui/settings_menu.tscn"
const OUTPUT_PATH := "res://tools/screenshots/settings_menu_click_smoke.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))

	var err := change_scene_to_file(MAIN_MENU_SCENE)
	if err != OK:
		push_error("[settings_menu_click_smoke] failed to open main menu err=%s" % err)
		quit(1)
		return

	for _i in 24:
		await process_frame

	var main_menu := current_scene
	if main_menu == null:
		push_error("[settings_menu_click_smoke] current_scene is null after loading main menu")
		quit(2)
		return

	var settings_button := main_menu.get_node_or_null("%SettingsButton") as Button
	if settings_button == null:
		push_error("[settings_menu_click_smoke] failed to find %SettingsButton")
		quit(3)
		return

	print("[settings_menu_click_smoke] pressing settings button")
	settings_button.pressed.emit()

	for _i in 40:
		await process_frame

	if current_scene == null:
		push_error("[settings_menu_click_smoke] current_scene is null after clicking settings")
		quit(4)
		return

	print("[settings_menu_click_smoke] current_scene=%s path=%s" % [current_scene.name, current_scene.scene_file_path])
	if current_scene.scene_file_path != SETTINGS_MENU_SCENE:
		push_error("[settings_menu_click_smoke] expected settings scene, got %s" % current_scene.scene_file_path)
		quit(5)
		return

	var resolution_option := current_scene.get_node_or_null("%ResolutionOption") as OptionButton
	var fullscreen_toggle := current_scene.get_node_or_null("%FullscreenToggle") as CheckButton
	var apply_button := current_scene.get_node_or_null("%ApplyButton") as Button
	if resolution_option == null or fullscreen_toggle == null or apply_button == null:
		push_error("[settings_menu_click_smoke] failed to resolve settings controls")
		quit(6)
		return

	await _save_screenshot()

	resolution_option.select(2)
	fullscreen_toggle.button_pressed = true
	apply_button.pressed.emit()
	for _i in 12:
		await process_frame

	var settings_bootstrap := root.get_node_or_null("SettingsBootstrap")
	print("[settings_menu_click_smoke] after_apply size=%s fullscreen=%s mode=%s" % [
		settings_bootstrap.get_window_size() if settings_bootstrap else null,
		settings_bootstrap.is_fullscreen_enabled() if settings_bootstrap else null,
		DisplayServer.window_get_mode(),
	])

	fullscreen_toggle.button_pressed = false
	apply_button.pressed.emit()
	for _i in 12:
		await process_frame
	print("[settings_menu_click_smoke] after_restore size=%s fullscreen=%s mode=%s" % [
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
		push_error("[settings_menu_click_smoke] viewport image unavailable")
		quit(7)
		return

	var output_abs := ProjectSettings.globalize_path(OUTPUT_PATH)
	var err := image.save_png(output_abs)
	if err != OK:
		push_error("[settings_menu_click_smoke] save_png failed err=%s path=%s" % [err, output_abs])
		quit(8)
		return

	print("[settings_menu_click_smoke] screenshot=%s" % output_abs)
