extends Control

@onready var _blue_hover: Button = %BlueHoverButton
@onready var _blue_pressed: Button = %BluePressedButton
@onready var _blue_disabled: Button = %BlueDisabledButton
@onready var _red_hover: Button = %RedHoverButton
@onready var _red_pressed: Button = %RedPressedButton
@onready var _red_disabled: Button = %RedDisabledButton
@onready var _progress_bar: TextureProgressBar = %PreviewProgressBar


func _ready() -> void:
	_apply_preview_button_states()
	_progress_bar.value = 70.0


func _apply_preview_button_states() -> void:
	var blue_hover_box := theme.get_stylebox("hover", "Button")
	var red_hover_box := theme.get_stylebox("hover", "danger")

	_blue_hover.add_theme_stylebox_override("normal", blue_hover_box)
	_blue_hover.add_theme_color_override("font_color", theme.get_color("font_hover_color", "Button"))

	_red_hover.add_theme_stylebox_override("normal", red_hover_box)
	_red_hover.add_theme_color_override("font_color", theme.get_color("font_hover_color", "danger"))

	for pressed_button in [_blue_pressed, _red_pressed]:
		pressed_button.toggle_mode = true
		pressed_button.set_pressed_no_signal(true)

	for disabled_button in [_blue_disabled, _red_disabled]:
		disabled_button.disabled = true
