extends CanvasLayer
class_name BattleUI
## BattleUI —— 战斗 UI

const ItemData = preload("res://scripts/core/item_data.gd")

@onready var turn_label: Label = $Root/TopBar/TurnLabel
@onready var message_label: Label = $Root/MessageLabel
@onready var battle_hud_v3 = $Root/BattleHUDV3

signal skill_button_pressed(skill_index: int)
signal item_button_pressed()
signal item_selected(item_id: String)
signal item_panel_closed()


func _ready() -> void:
	battle_hud_v3.skill_selected.connect(_emit_skill_button)
	battle_hud_v3.item_selected.connect(_on_item_chosen)
	battle_hud_v3.submenu_closed.connect(_on_submenu_closed)
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
	var entries: Array[Dictionary] = []
	for idx in 3:
		var skill = unit.get_skill(idx)
		if skill == null:
			continue
		entries.append({
			"type": &"skill",
			"index": idx,
			"key": str(idx + 1),
			"label": skill.skill_name,
			"detail": _build_skill_text(skill),
			"disabled": not skill.is_available(),
		})
	battle_hud_v3.set_skill_entries(entries)
	_refresh_item_button()


func hide_actions() -> void:
	battle_hud_v3.set_action_menu_visible(false)
	hide_item_panel()


func refresh_items() -> void:
	_refresh_item_button()


func show_action_menu(allow_attack: bool, allow_item: bool, allow_wait: bool, allow_cancel_move: bool) -> void:
	battle_hud_v3.set_action_menu_visible(true, "行动")
	battle_hud_v3.set_action_enabled(&"attack", allow_attack)
	battle_hud_v3.set_action_enabled(&"martial", true)
	battle_hud_v3.set_action_enabled(&"item", allow_item)
	battle_hud_v3.set_action_enabled(&"wait", allow_wait)
	battle_hud_v3.set_action_enabled(&"cancel_move", allow_cancel_move)


func show_item_panel(entries: Array) -> void:
	var ui_entries: Array[Dictionary] = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var item_data = entry.get("item_data") as ItemData
		var count := int(entry.get("count", 0))
		if item_data == null or count <= 0:
			continue
		ui_entries.append({
			"type": &"item",
			"item_id": item_data.id,
			"label": "%s x%d" % [item_data.name, count],
			"detail": item_data.description,
			"disabled": false,
		})
	battle_hud_v3.set_item_entries(ui_entries)
	battle_hud_v3.show_item_panel()


func hide_item_panel() -> void:
	battle_hud_v3.hide_submenu(&"item")


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


func _refresh_item_button() -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	var entries: Array[Dictionary] = []
	if game_state == null:
		battle_hud_v3.set_item_entries(entries)
		return
	var consumables: Array = game_state.inventory.list_by_category(ItemData.ItemCategory.CONSUMABLE)
	for entry in consumables:
		if not (entry is Dictionary):
			continue
		var item_data = entry.get("item_data") as ItemData
		var count := int(entry.get("count", 0))
		if item_data == null or count <= 0:
			continue
		entries.append({
			"type": &"item",
			"item_id": item_data.id,
			"label": "%s x%d" % [item_data.name, count],
			"detail": item_data.description,
			"disabled": false,
		})
	battle_hud_v3.set_item_entries(entries)


func _on_submenu_closed(kind: StringName) -> void:
	if kind == &"item":
		item_panel_closed.emit()


func get_battle_hud_v3():
	return battle_hud_v3
