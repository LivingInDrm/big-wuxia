extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var apply_button: Button = %ApplyButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	_populate_resolution_options()
	_load_current_settings()
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _populate_resolution_options() -> void:
	resolution_option.clear()
	for index in range(RESOLUTION_OPTIONS.size()):
		var resolution: Vector2i = RESOLUTION_OPTIONS[index]
		resolution_option.add_item("%d×%d" % [resolution.x, resolution.y], index)


func _load_current_settings() -> void:
	var settings_bootstrap := _settings_bootstrap()
	var current_size := settings_bootstrap.get_window_size()
	var selected_index := 0
	for index in range(RESOLUTION_OPTIONS.size()):
		if RESOLUTION_OPTIONS[index] == current_size:
			selected_index = index
			break

	resolution_option.select(selected_index)
	fullscreen_toggle.button_pressed = settings_bootstrap.is_fullscreen_enabled()
	status_label.text = "当前：%d×%d%s" % [
		current_size.x,
		current_size.y,
		" · 全屏" if fullscreen_toggle.button_pressed else " · 窗口",
	]


func _on_apply_pressed() -> void:
	var resolution: Vector2i = RESOLUTION_OPTIONS[resolution_option.get_selected_id()]
	var fullscreen := fullscreen_toggle.button_pressed
	_settings_bootstrap().apply_settings(resolution, fullscreen, true)
	status_label.text = "已应用：%d×%d%s" % [
		resolution.x,
		resolution.y,
		" · 全屏" if fullscreen else " · 窗口",
	]


func _on_back_pressed() -> void:
	SceneManager.change_scene_to_file(MAIN_MENU_SCENE)


func _settings_bootstrap() -> Node:
	return get_node("/root/SettingsBootstrap")
