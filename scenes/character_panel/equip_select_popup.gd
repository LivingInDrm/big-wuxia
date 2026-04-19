extends Control
class_name EquipSelectPopup

const ItemInstance = preload("res://scripts/core/item_instance.gd")
const UI_FONT: FontFile = preload("res://resources/fonts/NotoSerifCJKsc-Regular.otf")

signal equip_selected(instance_id: int)
signal unequip_selected()
signal popup_closed()

@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var option_list: ItemList = %OptionList
@onready var close_button: Button = %CloseButton

var _actions: Array[Dictionary] = []


func _ready() -> void:
	option_list.item_selected.connect(_on_option_selected)
	option_list.item_activated.connect(_on_option_activated)
	close_button.pressed.connect(_on_close_pressed)
	hide_popup()


func configure(slot_name: String, items: Array[ItemInstance], can_unequip: bool) -> void:
	title_label.text = "更换%s" % slot_name
	option_list.clear()
	_actions.clear()

	if can_unequip:
		option_list.add_item("卸下当前装备")
		_actions.append({"type": "unequip"})

	for item_instance in items:
		if item_instance == null or item_instance.item_data == null:
			continue
		var item_data := item_instance.item_data
		var label := "%s  %s" % [item_data.name, _format_modifier_preview(item_data.stat_modifiers)]
		option_list.add_item(label, item_data.icon)
		option_list.set_item_tooltip(option_list.item_count - 1, item_data.description)
		_actions.append({
			"type": "equip",
			"instance_id": item_instance.instance_id,
		})

	if _actions.is_empty():
		option_list.add_item("无可装备物品")
		option_list.set_item_disabled(0, true)
		hint_label.text = "当前栏位没有可用装备。"
	else:
		hint_label.text = "双击或单击条目即可装备。"


func show_popup() -> void:
	visible = true


func hide_popup() -> void:
	visible = false


func _format_modifier_preview(stat_modifiers: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["attack", "defense", "qinggong", "qi_speed", "max_hp", "max_mp"]:
		var value := int(stat_modifiers.get(key, 0))
		if value == 0:
			continue
		parts.append("%+d %s" % [value, _stat_label(key)])
	if parts.is_empty():
		return "无修正"
	return " / ".join(parts)


func _stat_label(key: String) -> String:
	match key:
		"attack":
			return "攻击"
		"defense":
			return "防御"
		"qinggong":
			return "轻功"
		"qi_speed":
			return "集气"
		"max_hp":
			return "气血"
		"max_mp":
			return "内力"
		_:
			return key


func _on_option_selected(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return

	var action := _actions[index]
	match String(action.get("type", "")):
		"equip":
			equip_selected.emit(int(action.get("instance_id", -1)))
			hide_popup()
		"unequip":
			unequip_selected.emit()
			hide_popup()


func _on_option_activated(index: int) -> void:
	_on_option_selected(index)


func _on_close_pressed() -> void:
	popup_closed.emit()
	hide_popup()
