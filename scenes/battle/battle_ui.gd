extends CanvasLayer
class_name BattleUI
## BattleUI —— 战斗 UI（Sprint 3 占位）
##
## S3 仅提供 TurnLabel（回合 N - 阶段名） + MessageLabel（临时消息提示）
##   S4 后扩展：UnitInfoPanel、ActionMenu、HP 弹字等

@onready var turn_label: Label = $Root/TopBar/TurnLabel
@onready var message_label: Label = $Root/MessageLabel


func set_turn(turn_num: int, phase_name: String) -> void:
	turn_label.text = "回合 %d - %s" % [turn_num, phase_name]


func set_message(text: String) -> void:
	message_label.text = text


func clear_message() -> void:
	message_label.text = ""
