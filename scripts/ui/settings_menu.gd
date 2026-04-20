extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DIALOGUE_SPEED_OPTIONS := [
	{"label": "快", "char_speed": 12},
	{"label": "普通", "char_speed": 25},
	{"label": "慢", "char_speed": 40},
	{"label": "瞬显", "char_speed": 0},
]
const TITLE_COLOR := UIColors.OCHRE
const LABEL_COLOR := UIColors.PAPER_WHITE
const SUBTEXT_COLOR := Color("#B8A898")

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var dialogue_speed_option: OptionButton = %DialogueSpeedOption
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var apply_button: Button = %ApplyButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var resolution_label: Label = $Center/Panel/Margin/VBox/Body/ResolutionRow/ResolutionLabel
@onready var dialogue_speed_label: Label = $Center/Panel/Margin/VBox/Body/DialogueSpeedRow/DialogueSpeedLabel
@onready var fullscreen_label: Label = $Center/Panel/Margin/VBox/Body/FullscreenRow/FullscreenLabel
@onready var hint_label: Label = $Center/Panel/Margin/VBox/HintLabel


func _ready() -> void:
	_apply_text_colors()
	_populate_resolution_options()
	_populate_dialogue_speed_options()
	_load_current_settings()
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _populate_resolution_options() -> void:
	resolution_option.clear()
	for index in range(RESOLUTION_OPTIONS.size()):
		var resolution: Vector2i = RESOLUTION_OPTIONS[index]
		resolution_option.add_item("%d×%d" % [resolution.x, resolution.y], index)


func _populate_dialogue_speed_options() -> void:
	dialogue_speed_option.clear()
	for index in range(DIALOGUE_SPEED_OPTIONS.size()):
		dialogue_speed_option.add_item(String(DIALOGUE_SPEED_OPTIONS[index]["label"]), index)


func _load_current_settings() -> void:
	var settings_bootstrap: Node = _settings_bootstrap()
	var current_size: Vector2i = settings_bootstrap.get_window_size()
	var selected_index: int = 0
	for index in range(RESOLUTION_OPTIONS.size()):
		if RESOLUTION_OPTIONS[index] == current_size:
			selected_index = index
			break

	resolution_option.select(selected_index)
	fullscreen_toggle.button_pressed = settings_bootstrap.is_fullscreen_enabled()
	dialogue_speed_option.select(_find_dialogue_speed_index(settings_bootstrap.get_dialogue_char_speed()))
	status_label.text = _format_status(
		"当前",
		current_size,
		fullscreen_toggle.button_pressed,
		_current_dialogue_char_speed()
	)


func _on_apply_pressed() -> void:
	var resolution: Vector2i = RESOLUTION_OPTIONS[resolution_option.get_selected_id()]
	var fullscreen: bool = fullscreen_toggle.button_pressed
	var dialogue_char_speed := _current_dialogue_char_speed()
	var settings_bootstrap := _settings_bootstrap()
	var applied_to_window: bool = settings_bootstrap.apply_settings(resolution, fullscreen, true, dialogue_char_speed)
	if not applied_to_window and settings_bootstrap.is_embedded_window_mode():
		print(
			"[SettingsMenu] Embedded editor preview detected; display settings were saved and will apply in a standalone run."
		)
		status_label.text = _format_status("已保存", resolution, fullscreen, dialogue_char_speed) + "（编辑器嵌入运行未改窗口）"
		return

	status_label.text = _format_status("已应用", resolution, fullscreen, dialogue_char_speed)


func _on_back_pressed() -> void:
	SceneManager.change_scene_to_file(MAIN_MENU_SCENE)


func _settings_bootstrap() -> Node:
	return get_node("/root/SettingsBootstrap")


func _apply_text_colors() -> void:
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	resolution_label.add_theme_color_override("font_color", LABEL_COLOR)
	dialogue_speed_label.add_theme_color_override("font_color", LABEL_COLOR)
	fullscreen_label.add_theme_color_override("font_color", LABEL_COLOR)
	hint_label.add_theme_color_override("font_color", SUBTEXT_COLOR)
	status_label.add_theme_color_override("font_color", SUBTEXT_COLOR)


func _format_status(prefix: String, resolution: Vector2i, fullscreen: bool, dialogue_char_speed: int) -> String:
	return "%s：%d×%d%s · 文字%s" % [
		prefix,
		resolution.x,
		resolution.y,
		" · 全屏" if fullscreen else " · 窗口",
		_dialogue_speed_label_for(dialogue_char_speed),
	]


func _current_dialogue_char_speed() -> int:
	return int(DIALOGUE_SPEED_OPTIONS[dialogue_speed_option.get_selected_id()]["char_speed"])


func _find_dialogue_speed_index(char_speed: int) -> int:
	for index in range(DIALOGUE_SPEED_OPTIONS.size()):
		if int(DIALOGUE_SPEED_OPTIONS[index]["char_speed"]) == char_speed:
			return index
	return 1


func _dialogue_speed_label_for(char_speed: int) -> String:
	for entry in DIALOGUE_SPEED_OPTIONS:
		if int(entry["char_speed"]) == char_speed:
			return String(entry["label"])
	return "普通"
