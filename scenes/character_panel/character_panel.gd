extends Control

class PreviewUnit:
	extends Node

	var unit_data: UnitData = null


const LEVEL_SELECT_SCENE := "res://scenes/level_select/level_select.tscn"
const ItemData = preload("res://scripts/core/item_data.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")
const UnitData = preload("res://scripts/core/unit_data.gd")
const WeaponTypes = preload("res://scripts/core/weapon_types.gd")
const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")
const UI_FONT: FontFile = preload("res://resources/fonts/NotoSerifCJKsc-Regular.otf")
const XU_FENGNIAN = preload("res://resources/data/units/xu_fengnian.tres")
const JIANG_NI = preload("res://resources/data/units/jiang_ni.tres")
const LI_CHUNGANG = preload("res://resources/data/units/li_chungang.tres")

const CHARACTER_ORDER: Array[UnitData] = [
	XU_FENGNIAN,
	JIANG_NI,
	LI_CHUNGANG,
]

const SLOT_ORDER := [
	ItemData.EquipSlot.WEAPON,
	ItemData.EquipSlot.ARMOR,
	ItemData.EquipSlot.ACCESSORY_1,
	ItemData.EquipSlot.ACCESSORY_2,
]

const BASIC_STATS := [
	{"key": "max_hp", "label": "气血上限"},
	{"key": "max_mp", "label": "内力上限"},
	{"key": "attack", "label": "攻击"},
	{"key": "defense", "label": "防御"},
	{"key": "qinggong", "label": "轻功"},
	{"key": "qi_speed", "label": "集气"},
]

const SPECIALTY_STATS := [
	{"key": "spec_blade", "label": "刀法"},
	{"key": "spec_sword", "label": "剑法"},
	{"key": "spec_fist", "label": "拳掌"},
	{"key": "spec_medicine", "label": "医术"},
	{"key": "spec_poison", "label": "毒术"},
]

@onready var return_button: Button = %ReturnButton
@onready var character_buttons: VBoxContainer = %CharacterButtons
@onready var current_character_label: Label = %CurrentCharacterLabel
@onready var equipment_slots: VBoxContainer = %EquipmentSlots
@onready var basic_stats_container: VBoxContainer = %BasicStatsContainer
@onready var specialty_stats_container: VBoxContainer = %SpecialtyStatsContainer
@onready var equip_popup = %EquipSelectPopup

var return_scene_path: String = LEVEL_SELECT_SCENE

var _character_buttons_by_id: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _slot_name_labels: Dictionary = {}
var _slot_preview_labels: Dictionary = {}
var _slot_icon_nodes: Dictionary = {}
var _basic_value_labels: Dictionary = {}
var _specialty_value_labels: Dictionary = {}
var _active_slot: int = ItemData.EquipSlot.NONE
var _current_character_id: String = ""
var _preview_unit: PreviewUnit = null


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	equip_popup.equip_selected.connect(_on_equip_selected)
	equip_popup.unequip_selected.connect(_on_unequip_selected)
	equip_popup.popup_closed.connect(_on_popup_closed)
	_build_character_buttons()
	_build_equipment_slots()
	_build_basic_stats()
	_build_specialty_stats()
	_create_preview_unit()
	_connect_game_state()
	_select_character(XU_FENGNIAN.unit_id)


func _exit_tree() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.equipment_changed.is_connected(_on_equipment_changed):
		game_state.equipment_changed.disconnect(_on_equipment_changed)


func _build_character_buttons() -> void:
	for child in character_buttons.get_children():
		child.queue_free()
	_character_buttons_by_id.clear()

	for unit_data in CHARACTER_ORDER:
		if unit_data == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 76)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.text = unit_data.unit_name
		button.name = "%sButton" % unit_data.unit_id.capitalize()
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", Color(0.16, 0.1, 0.08, 1.0))
		button.set_meta("char_id", unit_data.unit_id)
		button.pressed.connect(_on_character_button_pressed.bind(unit_data.unit_id))
		character_buttons.add_child(button)
		_character_buttons_by_id[unit_data.unit_id] = button


func _build_equipment_slots() -> void:
	for child in equipment_slots.get_children():
		child.queue_free()
	_slot_buttons.clear()
	_slot_name_labels.clear()
	_slot_preview_labels.clear()
	_slot_icon_nodes.clear()

	for slot in SLOT_ORDER:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 112)
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", UI_FONT)
		button.add_theme_font_size_override("font_size", 18)
		button.set_meta("slot", slot)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		equipment_slots.add_child(button)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		button.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 12)
		margin.add_child(hbox)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		hbox.add_child(vbox)

		var title := Label.new()
		title.text = _slot_label(slot)
		title.add_theme_font_override("font", UI_FONT)
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(0.38, 0.24, 0.16, 1.0))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(title)

		var name_label := Label.new()
		name_label.add_theme_font_override("font", UI_FONT)
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Color(0.16, 0.1, 0.08, 1.0))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(name_label)

		var preview := Label.new()
		preview.add_theme_font_override("font", UI_FONT)
		preview.add_theme_font_size_override("font_size", 17)
		preview.add_theme_color_override("font_color", Color(0.34, 0.22, 0.16, 1.0))
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(preview)

		_slot_buttons[slot] = button
		_slot_icon_nodes[slot] = icon
		_slot_name_labels[slot] = name_label
		_slot_preview_labels[slot] = preview
		button.name = "%sButton" % _slot_key(slot).capitalize()
		name_label.name = "%sNameLabel" % _slot_key(slot).capitalize()
		preview.name = "%sPreviewLabel" % _slot_key(slot).capitalize()


func _build_basic_stats() -> void:
	for child in basic_stats_container.get_children():
		child.queue_free()
	_basic_value_labels.clear()

	for stat in BASIC_STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		basic_stats_container.add_child(row)

		var label := Label.new()
		label.text = "%s" % stat["label"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_override("font", UI_FONT)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.16, 0.1, 0.08, 1.0))
		row.add_child(label)

		var value := Label.new()
		value.add_theme_font_override("font", UI_FONT)
		value.add_theme_font_size_override("font_size", 22)
		value.add_theme_color_override("font_color", Color(0.22, 0.14, 0.1, 1.0))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_basic_value_labels[stat["key"]] = value


func _build_specialty_stats() -> void:
	for child in specialty_stats_container.get_children():
		child.queue_free()
	_specialty_value_labels.clear()

	for stat in SPECIALTY_STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		specialty_stats_container.add_child(row)

		var label := Label.new()
		label.text = "%s" % stat["label"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_override("font", UI_FONT)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.16, 0.1, 0.08, 1.0))
		row.add_child(label)

		var value := Label.new()
		value.add_theme_font_override("font", UI_FONT)
		value.add_theme_font_size_override("font_size", 22)
		value.add_theme_color_override("font_color", Color(0.22, 0.14, 0.1, 1.0))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_specialty_value_labels[stat["key"]] = value


func _create_preview_unit() -> void:
	_preview_unit = PreviewUnit.new()
	_preview_unit.name = "PreviewUnit"
	add_child(_preview_unit)


func _connect_game_state() -> void:
	var game_state := _get_game_state()
	if game_state != null and not game_state.equipment_changed.is_connected(_on_equipment_changed):
		game_state.equipment_changed.connect(_on_equipment_changed)


func _select_character(char_id: String) -> void:
	_current_character_id = char_id
	for button_id in _character_buttons_by_id.keys():
		var button := _character_buttons_by_id[button_id] as Button
		if button != null:
			button.button_pressed = button_id == char_id
	_refresh_view()


func _refresh_view() -> void:
	var unit_data := _get_current_unit_data()
	if unit_data == null or _preview_unit == null:
		return

	_preview_unit.unit_data = unit_data
	current_character_label.text = "%s · 装备与属性" % unit_data.unit_name
	_refresh_slots()
	_refresh_basic_stats(unit_data)
	_refresh_specialties(unit_data)


func _refresh_slots() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	var equipped_items: Dictionary = game_state.get_equipped_items(_current_character_id)
	for slot in SLOT_ORDER:
		var item_instance := equipped_items.get(slot) as ItemInstance
		var icon := _slot_icon_nodes.get(slot) as TextureRect
		var name_label := _slot_name_labels.get(slot) as Label
		var preview_label := _slot_preview_labels.get(slot) as Label
		if item_instance == null or item_instance.item_data == null:
			if icon != null:
				icon.texture = null
			if name_label != null:
				name_label.text = "—"
			if preview_label != null:
				preview_label.text = "点击选择装备"
			continue

		if icon != null:
			icon.texture = item_instance.item_data.icon
		if name_label != null:
			name_label.text = item_instance.item_data.name
		if preview_label != null:
			preview_label.text = _format_modifier_preview(item_instance.item_data.stat_modifiers)


func _refresh_basic_stats(_unit_data: UnitData) -> void:
	var preview := {
		"max_hp": AttributeResolver.get_max_hp(_preview_unit),
		"max_mp": AttributeResolver.get_max_mp(_preview_unit),
		"attack": AttributeResolver.get_attack(_preview_unit),
		"defense": AttributeResolver.get_defense(_preview_unit),
		"qinggong": AttributeResolver.get_qinggong(_preview_unit),
		"qi_speed": AttributeResolver.get_qi_speed(_preview_unit),
	}
	for stat in BASIC_STATS:
		var key := String(stat["key"])
		var value_label := _basic_value_labels.get(key) as Label
		if value_label == null:
			continue
		var result: Dictionary = preview.get(key, {})
		var total := int(result.get("total", 0))
		var equipment := int(result.get("sources", {}).get("equipment", 0))
		value_label.text = "%d（装备 %+d）" % [total, equipment]


func _refresh_specialties(unit_data: UnitData) -> void:
	if unit_data.attributes == null:
		return
	for stat in SPECIALTY_STATS:
		var key := String(stat["key"])
		var value_label := _specialty_value_labels.get(key) as Label
		if value_label != null:
			value_label.text = "Lv.%d" % int(unit_data.attributes.get(key))


func _on_character_button_pressed(char_id: String) -> void:
	_select_character(char_id)


func _on_slot_pressed(slot: int) -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	_active_slot = slot
	var candidates := _collect_candidates(slot)
	var equipped_items: Dictionary = game_state.get_equipped_items(_current_character_id)
	var has_equipped := equipped_items.get(slot) != null
	equip_popup.configure(_slot_label(slot), candidates, has_equipped)
	equip_popup.show_popup()


func _collect_candidates(slot: int) -> Array[ItemInstance]:
	var candidates: Array[ItemInstance] = []
	var game_state := _get_game_state()
	if game_state == null:
		return candidates
	for entry in game_state.inventory.unique_items:
		var item_instance := entry as ItemInstance
		if item_instance == null or item_instance.item_data == null:
			continue
		if item_instance.item_data.equip_slot != slot:
			continue
		if slot == ItemData.EquipSlot.WEAPON and not _weapon_type_matches(item_instance.item_data):
			continue
		candidates.append(item_instance)
	candidates.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return a.item_data.name < b.item_data.name
	)
	return candidates


func _weapon_type_matches(item_data: ItemData) -> bool:
	var unit_data := _get_current_unit_data()
	if unit_data == null:
		return false
	return _weapon_type_to_string(unit_data.weapon_type) == item_data.weapon_type.to_lower()


func _on_equip_selected(instance_id: int) -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	var item_instance := _find_inventory_instance(instance_id)
	if item_instance == null:
		return
	game_state.equip(_current_character_id, _active_slot, item_instance)
	_refresh_view()


func _on_unequip_selected() -> void:
	var game_state := _get_game_state()
	if game_state == null:
		return
	game_state.unequip(_current_character_id, _active_slot)
	_refresh_view()


func _on_popup_closed() -> void:
	_active_slot = ItemData.EquipSlot.NONE


func _on_equipment_changed(char_id: String) -> void:
	if char_id != _current_character_id:
		return
	_refresh_view()


func _on_return_pressed() -> void:
	var scene_manager := get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.change_scene_to_file(return_scene_path)


func _find_inventory_instance(instance_id: int) -> ItemInstance:
	var game_state := _get_game_state()
	if game_state == null:
		return null
	for entry in game_state.inventory.unique_items:
		var item_instance := entry as ItemInstance
		if item_instance != null and item_instance.instance_id == instance_id:
			return item_instance
	return null


func get_basic_stat_text(key: String) -> String:
	var value_label := _basic_value_labels.get(key) as Label
	return "" if value_label == null else value_label.text


func get_slot_item_name(slot: int) -> String:
	var name_label := _slot_name_labels.get(slot) as Label
	return "" if name_label == null else name_label.text


func get_character_button(char_id: String) -> Button:
	return _character_buttons_by_id.get(char_id) as Button


func get_slot_button(slot: int) -> Button:
	return _slot_buttons.get(slot) as Button


func _get_current_unit_data() -> UnitData:
	for unit_data in CHARACTER_ORDER:
		if unit_data != null and unit_data.unit_id == _current_character_id:
			return unit_data
	return null


func _slot_label(slot: int) -> String:
	match slot:
		ItemData.EquipSlot.WEAPON:
			return "WEAPON"
		ItemData.EquipSlot.ARMOR:
			return "ARMOR"
		ItemData.EquipSlot.ACCESSORY_1:
			return "ACC_1"
		ItemData.EquipSlot.ACCESSORY_2:
			return "ACC_2"
		_:
			return "UNKNOWN"


func _slot_key(slot: int) -> String:
	match slot:
		ItemData.EquipSlot.WEAPON:
			return "weapon"
		ItemData.EquipSlot.ARMOR:
			return "armor"
		ItemData.EquipSlot.ACCESSORY_1:
			return "acc1"
		ItemData.EquipSlot.ACCESSORY_2:
			return "acc2"
		_:
			return "slot"


func _format_modifier_preview(stat_modifiers: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["attack", "defense", "qinggong", "qi_speed", "max_hp", "max_mp"]:
		var value := int(stat_modifiers.get(key, 0))
		if value == 0:
			continue
		lines.append("%+d %s" % [value, _stat_label(key)])
	if lines.is_empty():
		return "无修正"
	return " / ".join(lines)


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


func _weapon_type_to_string(weapon_type: int) -> String:
	match weapon_type:
		WeaponTypes.Type.BLADE:
			return "blade"
		WeaponTypes.Type.SWORD:
			return "sword"
		WeaponTypes.Type.FIST:
			return "fist"
		WeaponTypes.Type.INNER:
			return "inner"
		_:
			return ""


func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")
