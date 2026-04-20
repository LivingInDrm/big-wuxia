extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_WIDTH := 1600
const DEFAULT_HEIGHT := 900
const DEFAULT_FULLSCREEN := false

var _window_size: Vector2i = Vector2i(DEFAULT_WIDTH, DEFAULT_HEIGHT)
var _fullscreen: bool = DEFAULT_FULLSCREEN


func _ready() -> void:
	_load_settings()
	_apply_display(_window_size, _fullscreen)


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


func apply_settings(window_size: Vector2i, fullscreen: bool, persist: bool = false) -> void:
	_window_size = window_size
	_fullscreen = fullscreen
	_apply_display(_window_size, _fullscreen)
	if persist:
		save_settings()


func toggle_fullscreen() -> void:
	apply_settings(_window_size, not _fullscreen, true)


func save_settings() -> int:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "width", _window_size.x)
	cfg.set_value("display", "height", _window_size.y)
	cfg.set_value("display", "fullscreen", _fullscreen)
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


func _apply_display(window_size: Vector2i, fullscreen: bool) -> void:
	if fullscreen:
		DisplayServer.window_set_size(window_size)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
