extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

@onready var retry_button: Button = %RetryButton
@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	return_button.pressed.connect(_on_return_pressed)


func _on_retry_pressed() -> void:
	SceneManager.change_scene_to_file(BATTLE_SCENE)


func _on_return_pressed() -> void:
	SceneManager.change_scene_to_file(MAIN_MENU_SCENE)
