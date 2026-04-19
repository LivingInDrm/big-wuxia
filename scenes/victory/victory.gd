extends Control

const LEVEL_SELECT_SCENE := "res://scenes/level_select/level_select.tscn"

@onready var return_button: Button = %ReturnButton
@onready var message_label: Label = %MessageLabel


func _ready() -> void:
	if GameState.current_level != "":
		GameState.complete_level(GameState.current_level)
	var level = GameBalance.get_level_data(GameState.current_level)
	if level != null and level.victory_condition == "kill_boss" and level.boss_id != "":
		var boss := GameBalance.get_unit_data(level.boss_id) as UnitData
		var boss_name: String = boss.unit_name if boss != null else String(level.boss_id)
		message_label.text = "%s 已伏诛" % boss_name
	elif level != null:
		message_label.text = "%s 通关" % level.level_name
	return_button.pressed.connect(_on_return_pressed)


func _on_return_pressed() -> void:
	SceneManager.change_scene_to_file(LEVEL_SELECT_SCENE)
