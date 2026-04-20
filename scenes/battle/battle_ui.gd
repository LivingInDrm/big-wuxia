extends CanvasLayer
class_name BattleUI
## BattleUI —— 战斗 UI

const ItemData = preload("res://scripts/core/item_data.gd")

@onready var turn_label: Label = $Root/TopBar/TurnLabel
@onready var message_label: Label = $Root/MessageLabel
@onready var action_panel: PanelContainer = $Root/ActionPanel
@onready var skill_buttons: Array[Button] = [
	$Root/ActionPanel/Margin/VBox/Skill1Button,
	$Root/ActionPanel/Margin/VBox/Skill2Button,
	$Root/ActionPanel/Margin/VBox/Skill3Button,
]
@onready var item_button: Button = $Root/ActionPanel/Margin/VBox/ItemButton
@onready var item_select_panel = $Root/ItemSelectPanel
@onready var battle_hud_v3 = $Root/BattleHUDV3

signal skill_button_pressed(skill_index: int)
signal item_button_pressed()
signal item_selected(item_id: String)
signal item_panel_closed()


func _ready() -> void:
	for idx in skill_buttons.size():
		skill_buttons[idx].pressed.connect(_emit_skill_button.bind(idx))
	item_button.pressed.connect(_emit_item_button)
	item_select_panel.item_chosen.connect(_on_item_chosen)
	item_select_panel.panel_closed.connect(_on_item_panel_closed)
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
	action_panel.visible = false
	for idx in skill_buttons.size():
		var button := skill_buttons[idx]
		var skill = unit.get_skill(idx)
		if skill == null:
			button.visible = false
			continue
		button.visible = true
		button.text = _build_skill_text(skill)
		button.disabled = not skill.is_available()
	_refresh_item_button()


func hide_actions() -> void:
	action_panel.visible = false
	hide_item_panel()


func refresh_items() -> void:
	_refresh_item_button()


func show_item_panel(entries: Array) -> void:
	item_select_panel.set_items(entries)
	item_select_panel.show_panel()


func hide_item_panel() -> void:
	item_select_panel.hide_panel()


func _build_skill_text(skill) -> String:
	var cd_text := "CD:%d" % skill.current_cd if skill.current_cd > 0 else "就绪"
	if skill.remaining_uses == 0:
		cd_text = "已用尽"
	return "%s  %s" % [skill.skill_name, cd_text]


func _emit_skill_button(idx: int) -> void:
	skill_button_pressed.emit(idx)


func _emit_item_button() -> void:
	item_button_pressed.emit()


func _on_item_chosen(item_id: String) -> void:
	item_selected.emit(item_id)


func _on_item_panel_closed() -> void:
	item_panel_closed.emit()


func _refresh_item_button() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		item_button.disabled = true
		return
	var consumables: Array = game_state.inventory.list_by_category(ItemData.ItemCategory.CONSUMABLE)
	var has_usable := false
	for entry in consumables:
		if not (entry is Dictionary):
			continue
		if int(entry.get("count", 0)) > 0:
			has_usable = true
			break
	item_button.disabled = not has_usable


func get_battle_hud_v3():
	return battle_hud_v3
