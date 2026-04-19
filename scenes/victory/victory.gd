extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)


func _on_return_pressed() -> void:
	SceneManager.change_scene_to_file(MAIN_MENU_SCENE)
