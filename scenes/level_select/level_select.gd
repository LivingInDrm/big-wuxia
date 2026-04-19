extends Control

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const CHARACTER_PANEL_SCENE := "res://scenes/character_panel/character_panel.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const UI_FONT: FontFile = preload("res://resources/fonts/NotoSerifCJKsc-Regular.otf")

@onready var levels_container: VBoxContainer = %LevelsContainer
@onready var subtitle_label: Label = %SubtitleLabel
@onready var character_button: Button = %CharacterButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	character_button.pressed.connect(_on_character_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_populate_levels()


func _populate_levels() -> void:
	for child in levels_container.get_children():
		child.queue_free()

	var levels := GameBalance.get_all_levels()
	subtitle_label.text = "已通关 %d / %d" % [GameState.completed_levels.size(), levels.size()]
	for level_res in levels:
		var level = level_res
		if level == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(440, 76)
		button.focus_mode = Control.FOCUS_NONE
		button.text = _build_button_text(level)
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 28)
		button.add_theme_color_override("font_color", Color(0.14, 0.1, 0.08, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.3, 0.18, 0.08, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.04, 1.0))
		button.add_theme_stylebox_override("normal", back_button.get_theme_stylebox("normal"))
		button.add_theme_stylebox_override("hover", back_button.get_theme_stylebox("hover"))
		button.add_theme_stylebox_override("pressed", back_button.get_theme_stylebox("pressed"))
		button.pressed.connect(_on_level_pressed.bind(level.level_id))
		levels_container.add_child(button)


func _build_button_text(level) -> String:
	if level == null:
		return ""
	var prefix := "已通关 · " if GameState.is_level_completed(level.level_id) else ""
	return "%s%s" % [prefix, level.level_name]


func _on_level_pressed(level_id: String) -> void:
	GameState.start_level(level_id)
	SceneManager.change_scene_to_file(BATTLE_SCENE)


func _on_back_pressed() -> void:
	SceneManager.change_scene_to_file(MAIN_MENU_SCENE)


func _on_character_pressed() -> void:
	SceneManager.change_scene_to_file(CHARACTER_PANEL_SCENE)
