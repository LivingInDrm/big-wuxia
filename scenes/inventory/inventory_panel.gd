extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const ItemData = preload("res://scripts/core/item_data.gd")
const Inventory = preload("res://scripts/core/inventory.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")
const UI_FONT: FontFile = preload("res://resources/fonts/NotoSerifCJKsc-Regular.otf")

const TAB_ORDER := [
	ItemData.ItemCategory.CONSUMABLE,
	ItemData.ItemCategory.EQUIPMENT,
	ItemData.ItemCategory.MANUAL,
	ItemData.ItemCategory.QUEST,
	ItemData.ItemCategory.MISC,
]

const CATEGORY_LABELS := {
	ItemData.ItemCategory.CONSUMABLE: "消耗品",
	ItemData.ItemCategory.EQUIPMENT: "装备",
	ItemData.ItemCategory.MANUAL: "秘籍",
	ItemData.ItemCategory.QUEST: "任务",
	ItemData.ItemCategory.MISC: "其他",
}

const STAT_LABELS := {
	"attack": "攻击",
	"defense": "防御",
	"qinggong": "轻功",
	"qi_speed": "集气",
	"max_hp": "气血",
	"max_mp": "内力",
}

const SPECIALTY_LABELS := {
	"blade": "刀法",
	"medicine": "医术",
}

@onready var return_button: Button = %ReturnButton
@onready var item_grid: GridContainer = %ItemGrid
@onready var items_scroll: ScrollContainer = %ItemsScroll
@onready var empty_label: Label = %EmptyLabel
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name_label: Label = %DetailNameLabel
@onready var detail_category_label: Label = %DetailCategoryLabel
@onready var detail_description_label: Label = %DetailDescriptionLabel
@onready var detail_stats_label: Label = %DetailStatsLabel

@onready var tab_buttons: Array[Button] = [
	%ConsumableTab,
	%EquipmentTab,
	%ManualTab,
	%QuestTab,
	%MiscTab,
]

var inventory_override: Inventory = null
var return_scene_path: String = MAIN_MENU_SCENE
var start_category: ItemData.ItemCategory = ItemData.ItemCategory.CONSUMABLE

var _selected_category: ItemData.ItemCategory = ItemData.ItemCategory.CONSUMABLE
var _selected_entry_key: String = ""


func _ready() -> void:
	_selected_category = start_category
	return_button.pressed.connect(_on_return_pressed)

	for index in range(tab_buttons.size()):
		var button := tab_buttons[index]
		button.pressed.connect(_on_tab_pressed.bind(TAB_ORDER[index]))
		button.focus_mode = Control.FOCUS_NONE

	refresh_view()


func set_inventory_source(inventory: Inventory) -> void:
	inventory_override = inventory
	if is_inside_tree():
		refresh_view()


func select_category(category: ItemData.ItemCategory) -> void:
	_selected_category = category
	_selected_entry_key = ""
	if is_inside_tree():
		refresh_view()


func refresh_view() -> void:
	_refresh_tab_styles()
	_render_items()


func _render_items() -> void:
	for child in item_grid.get_children():
		child.free()

	var entries := _resolve_inventory().list_by_category(_selected_category)
	entries.sort_custom(_sort_entries)

	if entries.is_empty():
		items_scroll.visible = false
		empty_label.visible = true
		_show_entry_details(null)
		return

	items_scroll.visible = true
	empty_label.visible = false

	var has_selected := false
	for entry in entries:
		var item_button := _build_item_button(entry)
		item_grid.add_child(item_button)
		if _entry_key(entry) == _selected_entry_key:
			has_selected = true

	if not has_selected:
		_selected_entry_key = _entry_key(entries[0])

	_show_entry_details(_find_entry_by_key(entries, _selected_entry_key))
	_refresh_item_selection()


func _build_item_button(entry) -> Button:
	var item_data := _entry_item_data(entry)
	var button := Button.new()
	button.custom_minimum_size = Vector2(220, 144)
	button.clip_contents = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _make_item_style(false))
	button.add_theme_stylebox_override("hover", _make_item_style(true))
	button.add_theme_stylebox_override("pressed", _make_item_style(true))
	button.add_theme_stylebox_override("focus", _make_item_style(true))
	button.set_meta("entry_key", _entry_key(entry))
	button.pressed.connect(_on_item_pressed.bind(_entry_key(entry)))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(54, 54)
	icon.texture = item_data.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = item_data.name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_override("font", UI_FONT)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var count_label := Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_override("font", UI_FONT)
	count_label.add_theme_font_size_override("font_size", 17)
	count_label.add_theme_color_override("font_color", Color(0.38, 0.24, 0.16, 1.0))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.text = "x%d" % _entry_count(entry) if item_data.stackable and _entry_count(entry) > 1 else ""
	vbox.add_child(count_label)

	return button


func _refresh_item_selection() -> void:
	for child in item_grid.get_children():
		var button := child as Button
		if button == null:
			continue
		var is_selected := String(button.get_meta("entry_key", "")) == _selected_entry_key
		button.add_theme_stylebox_override("normal", _make_item_style(is_selected))
		button.add_theme_stylebox_override("hover", _make_item_style(true))
		button.add_theme_stylebox_override("pressed", _make_item_style(true))
		button.add_theme_stylebox_override("focus", _make_item_style(true))


func _show_entry_details(entry) -> void:
	if entry == null:
		detail_icon.texture = null
		detail_name_label.text = "未选择物品"
		detail_category_label.text = CATEGORY_LABELS.get(_selected_category, "物品")
		detail_description_label.text = "当前分类无物品。"
		detail_stats_label.text = ""
		return

	var item_data := _entry_item_data(entry)
	detail_icon.texture = item_data.icon
	detail_name_label.text = item_data.name
	detail_category_label.text = CATEGORY_LABELS.get(item_data.category, "其他")
	detail_description_label.text = item_data.description

	var lines: Array[String] = []
	if item_data.stackable and _entry_count(entry) > 1:
		lines.append("数量：x%d" % _entry_count(entry))
	for line in _build_detail_lines(item_data):
		lines.append(line)
	detail_stats_label.text = "\n".join(lines)


func _build_detail_lines(item_data: ItemData) -> Array[String]:
	var lines: Array[String] = []
	match item_data.category:
		ItemData.ItemCategory.CONSUMABLE:
			lines.append("效果：%s" % _consumable_effect_text(item_data))
		ItemData.ItemCategory.EQUIPMENT:
			if item_data.equip_slot != ItemData.EquipSlot.NONE:
				lines.append("部位：%s" % _equip_slot_text(item_data.equip_slot))
			if not item_data.weapon_type.is_empty():
				lines.append("武器类型：%s" % _specialty_label(item_data.weapon_type))
			var stat_keys := item_data.stat_modifiers.keys()
			stat_keys.sort()
			for key in stat_keys:
				lines.append("%s：%s" % [_stat_label(String(key)), _stringify_stat_value(item_data.stat_modifiers[key])])
		ItemData.ItemCategory.MANUAL:
			lines.append("传授：%s +%d" % [_specialty_label(item_data.teaches_specialty), item_data.teaches_level])
		ItemData.ItemCategory.QUEST:
			lines.append("剧情标记：%s" % item_data.quest_flag)
			lines.append("状态：不可丢弃" if not item_data.droppable else "状态：可丢弃")
		ItemData.ItemCategory.MISC:
			lines.append("说明：杂项物品")
	return lines


func _consumable_effect_text(item_data: ItemData) -> String:
	match item_data.effect_type:
		ItemData.ConsumableEffectType.HEAL_HP:
			return "恢复 %d 点气血" % int(item_data.effect_value)
		ItemData.ConsumableEffectType.HEAL_MP:
			return "恢复 %d 点内力" % int(item_data.effect_value)
		ItemData.ConsumableEffectType.BUFF:
			return "提升 %s %d 回合" % [_stat_label(item_data.effect_target_stat), item_data.effect_duration]
		ItemData.ConsumableEffectType.DISPEL:
			return "驱散 %s" % item_data.effect_target_stat
	return "未知效果"


func _equip_slot_text(slot: int) -> String:
	match slot:
		ItemData.EquipSlot.WEAPON:
			return "武器"
		ItemData.EquipSlot.ARMOR:
			return "护甲"
		ItemData.EquipSlot.ACCESSORY_1:
			return "饰品一"
		ItemData.EquipSlot.ACCESSORY_2:
			return "饰品二"
	return "无"


func _specialty_label(key: String) -> String:
	return SPECIALTY_LABELS.get(key, key)


func _stat_label(key: String) -> String:
	return STAT_LABELS.get(key, key)


func _stringify_stat_value(value) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return str(int(value)) if is_equal_approx(fmod(float(value), 1.0), 0.0) else str(value)
		TYPE_INT:
			return str(value)
		_:
			return str(value)


func _entry_item_data(entry) -> ItemData:
	if entry is Dictionary:
		return entry.get("item_data") as ItemData
	return (entry as ItemInstance).item_data


func _entry_count(entry) -> int:
	if entry is Dictionary:
		return int(entry.get("count", 0))
	return 1


func _entry_key(entry) -> String:
	var item_data := _entry_item_data(entry)
	if item_data == null:
		return ""
	if entry is Dictionary:
		return "stack:%s" % item_data.id
	var instance := entry as ItemInstance
	return "unique:%d" % instance.instance_id


func _find_entry_by_key(entries: Array, entry_key: String):
	for entry in entries:
		if _entry_key(entry) == entry_key:
			return entry
	return null


func _sort_entries(a, b) -> bool:
	var item_a := _entry_item_data(a)
	var item_b := _entry_item_data(b)
	if item_a == null or item_b == null:
		return false
	return item_a.name.naturalnocasecmp_to(item_b.name) < 0


func _make_item_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.bg_color = Color(0.98, 0.94, 0.84, 0.94) if selected else Color(1.0, 0.98, 0.92, 0.86)
	style.border_color = Color(0.68, 0.42, 0.18, 1.0) if selected else Color(0.54, 0.36, 0.2, 0.9)
	return style


func _make_tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 20
	style.content_margin_top = 10
	style.content_margin_right = 20
	style.content_margin_bottom = 12
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.bg_color = Color(0.95, 0.9, 0.78, 0.95) if active else Color(0.82, 0.72, 0.56, 0.8)
	style.border_color = Color(0.56, 0.35, 0.18, 1.0) if active else Color(0.34, 0.22, 0.14, 0.9)
	return style


func _refresh_tab_styles() -> void:
	for index in range(tab_buttons.size()):
		var button := tab_buttons[index]
		var active: bool = TAB_ORDER[index] == _selected_category
		button.button_pressed = active
		button.add_theme_stylebox_override("normal", _make_tab_style(active))
		button.add_theme_stylebox_override("hover", _make_tab_style(true))
		button.add_theme_stylebox_override("pressed", _make_tab_style(true))
		button.add_theme_stylebox_override("focus", _make_tab_style(true))


func _resolve_inventory() -> Inventory:
	if inventory_override != null:
		return inventory_override
	var game_state := get_tree().root.get_node_or_null("GameState")
	if game_state != null and game_state.inventory is Inventory:
		return game_state.inventory
	return Inventory.new()


func _on_tab_pressed(category: ItemData.ItemCategory) -> void:
	select_category(category)


func _on_item_pressed(entry_key: String) -> void:
	_selected_entry_key = entry_key
	var entry: Variant = _find_entry_by_key(_resolve_inventory().list_by_category(_selected_category), _selected_entry_key)
	_show_entry_details(entry)
	_refresh_item_selection()


func _on_return_pressed() -> void:
	var scene_manager := get_tree().root.get_node_or_null("SceneManager")
	if scene_manager != null:
		scene_manager.change_scene_to_file(return_scene_path)
