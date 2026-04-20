extends Control

const LEVEL_SELECT_SCENE := "res://scenes/level_select/level_select.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"

@onready var retry_button: Button = %RetryButton
@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	retry_button.visible = bool(GameState.return_context.get("allow_retry", false))
	retry_button.pressed.connect(_on_retry_pressed)
	return_button.pressed.connect(_on_return_pressed)


func _on_retry_pressed() -> void:
	SceneManager.change_scene_to_file(BATTLE_SCENE)


func _on_return_pressed() -> void:
	var target_path := GameState.abort_battle()
	if target_path.is_empty():
		target_path = OVERWORLD_SCENE if not GameState.overworld_player_position.is_zero_approx() else LEVEL_SELECT_SCENE
	SceneManager.change_scene_to_file(target_path)
