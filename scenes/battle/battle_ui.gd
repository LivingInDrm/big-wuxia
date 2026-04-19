extends CanvasLayer
class_name BattleUI
## BattleUI —— 战斗 UI

@onready var turn_label: Label = $Root/TopBar/TurnLabel
@onready var message_label: Label = $Root/MessageLabel
@onready var action_panel: PanelContainer = $Root/ActionPanel
@onready var skill_buttons: Array[Button] = [
	$Root/ActionPanel/Margin/VBox/Skill1Button,
	$Root/ActionPanel/Margin/VBox/Skill2Button,
	$Root/ActionPanel/Margin/VBox/Skill3Button,
]

signal skill_button_pressed(skill_index: int)


func _ready() -> void:
	for idx in skill_buttons.size():
		skill_buttons[idx].pressed.connect(_emit_skill_button.bind(idx))
	hide_actions()


func set_turn(turn_num: int, phase_name: String) -> void:
	turn_label.text = "回合 %d - %s" % [turn_num, phase_name]


func set_message(text: String) -> void:
	message_label.text = text


func clear_message() -> void:
	message_label.text = ""


func show_skills(unit: Unit) -> void:
	if unit == null:
		hide_actions()
		return
	action_panel.visible = true
	for idx in skill_buttons.size():
		var button := skill_buttons[idx]
		var skill = unit.get_skill(idx)
		if skill == null:
			button.visible = false
			continue
		button.visible = true
		button.text = _build_skill_text(skill)
		button.disabled = not skill.is_available()


func hide_actions() -> void:
	action_panel.visible = false


func _build_skill_text(skill) -> String:
	var cd_text := "CD:%d" % skill.current_cd if skill.current_cd > 0 else "就绪"
	if skill.remaining_uses == 0:
		cd_text = "已用尽"
	return "%s  %s" % [skill.skill_name, cd_text]


func _emit_skill_button(idx: int) -> void:
	skill_button_pressed.emit(idx)
