extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_WIDTH := 1600
const DEFAULT_HEIGHT := 900
const DEFAULT_FULLSCREEN := false
const DEFAULT_DIALOGUE_CHAR_SPEED := 25

signal settings_changed(window_size: Vector2i, fullscreen: bool, dialogue_char_speed: int)

var _window_size: Vector2i = Vector2i(DEFAULT_WIDTH, DEFAULT_HEIGHT)
var _fullscreen: bool = DEFAULT_FULLSCREEN
var _dialogue_char_speed: int = DEFAULT_DIALOGUE_CHAR_SPEED


func _ready() -> void:
	_load_settings()
	_apply_display(_window_size, _fullscreen)
	settings_changed.emit(_window_size, _fullscreen, _dialogue_char_speed)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F11:
		return

	toggle_fullscreen()
	get_viewport().set_input_as_handled()


func get_window_size() -> Vector2i:
	return _window_size


func is_fullscreen_enabled() -> bool:
	return _fullscreen


func get_dialogue_char_speed() -> int:
	return _dialogue_char_speed


func is_embedded_window_mode() -> bool:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false

	if tree.root.has_method("get_embedder"):
		return tree.root.call("get_embedder") != null

	for arg in OS.get_cmdline_args():
		if arg == "--wid" or arg.begins_with("--wid="):
			return true
		if arg == "--parent-window-id" or arg.begins_with("--parent-window-id="):
			return true

	return false


func apply_settings(window_size: Vector2i, fullscreen: bool, persist: bool = false, dialogue_char_speed: int = _dialogue_char_speed) -> bool:
	_window_size = window_size
	_fullscreen = fullscreen
	_dialogue_char_speed = max(dialogue_char_speed, 0)
	var applied_to_window := _apply_display(_window_size, _fullscreen)
	if persist:
		save_settings()
	settings_changed.emit(_window_size, _fullscreen, _dialogue_char_speed)
	return applied_to_window


func toggle_fullscreen() -> void:
	apply_settings(_window_size, not _fullscreen, true, _dialogue_char_speed)


func save_settings() -> int:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "width", _window_size.x)
	cfg.set_value("display", "height", _window_size.y)
	cfg.set_value("display", "fullscreen", _fullscreen)
	cfg.set_value("dialogue", "char_speed", _dialogue_char_speed)
	return cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_window_size = Vector2i(DEFAULT_WIDTH, DEFAULT_HEIGHT)
		_fullscreen = DEFAULT_FULLSCREEN
		return

	var width := int(cfg.get_value("display", "width", DEFAULT_WIDTH))
	var height := int(cfg.get_value("display", "height", DEFAULT_HEIGHT))
	_window_size = Vector2i(maxi(width, 640), maxi(height, 360))
	_fullscreen = bool(cfg.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	_dialogue_char_speed = max(int(cfg.get_value("dialogue", "char_speed", DEFAULT_DIALOGUE_CHAR_SPEED)), 0)


func _apply_display(window_size: Vector2i, fullscreen: bool) -> bool:
	if is_embedded_window_mode():
		print(
			"[SettingsBootstrap] Embedded editor window detected; saved display settings %dx%d (%s) without resizing the editor pane." % [
				window_size.x,
				window_size.y,
				"fullscreen" if fullscreen else "windowed",
			]
		)
		return false

	if fullscreen:
		DisplayServer.window_set_size(window_size)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return true

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	return true
