extends Control
class_name BattleHUDV3
signal emit_menu_action(action: StringName)

const UIColors := preload("res://resources/ui/colors.gd")
const PORTRAIT_LI_PATH := "res://resources/ui/portraits/half/li_chungang.png"

const HP_FILL := Color("#A84036")
const BAR_BG := Color("#D7CEBC")
const CARD_BG := Color(0.95, 0.92, 0.86, 0.92)
const CARD_BORDER := Color(0.29, 0.23, 0.17, 0.7)
const OVERLAY_BG := Color(0.94, 0.91, 0.84, 0.84)
const BUFF_TEXT := Color("#D7A33D")

const TOP_HINTS := [
	{"keys": ["Esc"], "desc": "菜单"},
	{"keys": ["Q", "E"], "desc": "快速选择人物"},
	{"keys": ["ASD"], "desc": "移动光标"},
	{"keys": ["Alt"], "desc": "查看详情"},
	{"keys": ["Tab"], "desc": "显示血量和移动顺序"},
]

const RIGHT_ACTIONS := [
	{"key": "V", "icon": Color("#8B5C32"), "label": "武功"},
	{"key": "B", "icon": Color("#7A6A46"), "label": "道具"},
	{"key": "Z", "icon": Color("#A84036"), "label": "原地打坐"},
	{"key": "Ctrl", "icon": Color("#4A6B7A"), "label": "自动战斗"},
	{"key": "R", "icon": Color("#6D4B3A"), "label": "逃跑"},
]

var _turn_number_label: Label
var _hint_label: Label
var _portrait_rect: TextureRect
var _buffs_box: VBoxContainer
var _name_label: Label
var _exp_label: Label
var _level_label: Label
var _hp_bar: ProgressBar
var _hp_value_label: Label
var _qg_label: Label
var _mp_bar: ProgressBar
var _mp_value_label: Label
var _vm = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func apply_mock(data: Dictionary) -> void:
	if _turn_number_label == null:
		return

	_apply_state(data)


func bind_vm(vm) -> void:
	_vm = vm


func refresh() -> void:
	if _vm == null:
		push_warning("[BattleHUDV3] refresh called without VM")
		return
	_apply_state({
		"turn": _vm.turn,
		"char_name": _vm.char_name,
		"portrait_path": _vm.portrait_path,
		"exp": _vm.exp,
		"exp_max": _vm.exp_max,
		"level": _vm.level,
		"level_max": _vm.level_max,
		"hp": _vm.hp,
		"hp_max": _vm.hp_max,
		"mp": _vm.mp,
		"mp_max": _vm.mp_max,
		"qinggong": _vm.qinggong,
		"buffs": _vm.buffs,
	})


func _apply_state(data: Dictionary) -> void:
	_turn_number_label.text = str(data.get("turn", 1))
	_name_label.text = str(data.get("char_name", data.get("name", "李淳罡")))
	_exp_label.text = "经验  %s/%s" % [data.get("exp", data.get("exp_current", 0)), data.get("exp_max", 1)]
	_level_label.text = "等级  ·  %s/%s" % [data.get("level", 1), data.get("level_max", 100)]

	var hp_current: int = int(data.get("hp", data.get("hp_current", 1)))
	var hp_max: int = max(int(data.get("hp_max", 1)), 1)
	_hp_bar.max_value = float(hp_max)
	_hp_bar.value = float(hp_current)
	_hp_value_label.text = "%s/%s" % [hp_current, hp_max]

	_qg_label.text = "轻功  %s" % [data.get("qinggong", 0)]

	var mp_current: int = int(data.get("mp", data.get("mp_current", 1)))
	var mp_max: int = max(int(data.get("mp_max", 1)), 1)
	_mp_bar.max_value = float(mp_max)
	_mp_bar.value = float(mp_current)
	_mp_value_label.text = "%s/%s" % [mp_current, mp_max]

	var portrait_input: Variant = data.get("portrait_path", data.get("portrait", PORTRAIT_LI_PATH))
	var portrait: Texture2D = _coerce_texture(portrait_input)
	_portrait_rect.texture = portrait

	var buffs: Array = data.get("buffs", [])
	for child in _buffs_box.get_children():
		child.queue_free()
	for buff in buffs:
		_buffs_box.add_child(_build_buff_tag(buff))


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	add_child(_build_top_bar())
	add_child(_build_right_menu())
	add_child(_build_character_card())
	add_child(_build_bottom_hint())


func _build_top_bar() -> Control:
	var shell := PanelContainer.new()
	shell.name = "TopBar"
	shell.theme_type_variation = &"tooltip"
	shell.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shell.offset_left = 22.0
	shell.offset_top = 14.0
	shell.offset_right = -22.0
	shell.offset_bottom = 122.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 18)
	shell.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var turn_box := VBoxContainer.new()
	turn_box.custom_minimum_size = Vector2(112, 62)
	turn_box.add_theme_constant_override("separation", -8)
	row.add_child(turn_box)

	var turn_caption := _label("回合", &"caption")
	turn_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_box.add_child(turn_caption)

	_turn_number_label = _label("1", &"title")
	_turn_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_box.add_child(_turn_number_label)

	var hints := HBoxContainer.new()
	hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints.add_theme_constant_override("separation", 10)
	row.add_child(hints)

	for hint_data in TOP_HINTS:
		hints.add_child(_build_top_hint_item(hint_data["keys"], hint_data["desc"]))

	return shell


func _build_top_hint_item(keys: Array, desc: String) -> Control:
	var item := PanelContainer.new()
	item.theme_type_variation = &"tooltip"
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.custom_minimum_size = Vector2(0, 72)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	item.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	for i in range(keys.size()):
		if i > 0:
			var dot := _label("·", &"caption")
			row.add_child(dot)
		row.add_child(_build_key_box(str(keys[i])))

	var text := _label(desc, &"caption")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	return item


func _build_right_menu() -> Control:
	var box := VBoxContainer.new()
	box.name = "RightMenu"
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -320.0
	box.offset_top = 138.0
	box.offset_right = -28.0
	box.offset_bottom = 620.0
	box.add_theme_constant_override("separation", 12)

	for action in RIGHT_ACTIONS:
		box.add_child(_build_action_item(action))

	return box


func _build_action_item(action: Dictionary) -> Control:
	var item := PanelContainer.new()
	item.theme_type_variation = &"tooltip"
	item.custom_minimum_size = Vector2(292, 80)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	item.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	row.add_child(_build_key_box(str(action.get("key", ""))))

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(18, 18)
	icon.color = action.get("icon", UIColors.OCHRE)
	row.add_child(icon)

	var label := _label(str(action.get("label", "")), &"body")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return item


func _build_character_card() -> Control:
	var root := Control.new()
	root.name = "CharacterCard"
	root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	root.offset_left = 24.0
	root.offset_top = -546.0
	root.offset_right = 612.0
	root.offset_bottom = -24.0

	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "Portrait"
	_portrait_rect.texture = _load_texture(PORTRAIT_LI_PATH)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.position = Vector2(0, 0)
	_portrait_rect.custom_minimum_size = Vector2(380, 380)
	_portrait_rect.size = Vector2(380, 380)
	root.add_child(_portrait_rect)

	_buffs_box = VBoxContainer.new()
	_buffs_box.name = "Buffs"
	_buffs_box.position = Vector2(12, 272)
	_buffs_box.custom_minimum_size = Vector2(236, 74)
	_buffs_box.add_theme_constant_override("separation", 6)
	root.add_child(_buffs_box)

	var name_bar := PanelContainer.new()
	name_bar.position = Vector2(0, 360)
	name_bar.custom_minimum_size = Vector2(548, 64)
	name_bar.size = Vector2(548, 64)
	name_bar.add_theme_stylebox_override("panel", _flat_style(CARD_BG, CARD_BORDER, 2, 4))
	root.add_child(name_bar)

	var name_margin := MarginContainer.new()
	name_margin.add_theme_constant_override("margin_left", 18)
	name_margin.add_theme_constant_override("margin_top", 10)
	name_margin.add_theme_constant_override("margin_right", 18)
	name_margin.add_theme_constant_override("margin_bottom", 10)
	name_bar.add_child(name_margin)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 14)
	name_margin.add_child(name_row)

	_name_label = _label("李淳罡", &"body")
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)

	_exp_label = _label("经验  5/8050", &"caption")
	_exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_exp_label)

	_level_label = _label("等级  ·  54/100", &"caption")
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_level_label)

	var stats_panel := PanelContainer.new()
	stats_panel.position = Vector2(0, 432)
	stats_panel.custom_minimum_size = Vector2(560, 92)
	stats_panel.size = Vector2(560, 92)
	stats_panel.add_theme_stylebox_override("panel", _flat_style(CARD_BG, CARD_BORDER, 2, 4))
	root.add_child(stats_panel)

	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 16)
	stats_margin.add_theme_constant_override("margin_top", 12)
	stats_margin.add_theme_constant_override("margin_right", 16)
	stats_margin.add_theme_constant_override("margin_bottom", 12)
	stats_panel.add_child(stats_margin)

	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 10)
	stats_margin.add_child(stats_box)

	var hp_row := _build_stat_row("气血", HP_FILL, true)
	stats_box.add_child(hp_row)

	var mp_row := _build_stat_row("内力", UIColors.JADE_MUTED, false)
	stats_box.add_child(mp_row)

	return root


func _build_stat_row(label_text: String, fill_color: Color, with_side_stat: bool) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.add_theme_constant_override("separation", 10)

	var caption := _label(label_text, &"caption")
	caption.custom_minimum_size = Vector2(38, 0)
	row.add_child(caption)

	var bar_host := Control.new()
	bar_host.custom_minimum_size = Vector2(0, 24)
	bar_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar_host)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 0.0
	bar.offset_top = 0.0
	bar.offset_right = 0.0
	bar.offset_bottom = 0.0
	bar.add_theme_stylebox_override("background", _flat_style(BAR_BG, CARD_BORDER, 1, 3))
	bar.add_theme_stylebox_override("fill", _flat_style(fill_color, fill_color, 1, 2))
	bar_host.add_child(bar)

	var value_label := _label("0/0", &"micro")
	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.offset_left = 10.0
	value_label.offset_top = 2.0
	value_label.offset_right = -10.0
	value_label.offset_bottom = -2.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_host.add_child(value_label)

	if with_side_stat:
		var side := _label("轻功  398", &"caption")
		side.custom_minimum_size = Vector2(96, 0)
		side.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(side)
		_hp_bar = bar
		_hp_value_label = value_label
		_qg_label = side
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(96, 0)
		row.add_child(spacer)
		_mp_bar = bar
		_mp_value_label = value_label

	return row


func _build_bottom_hint() -> Control:
	_hint_label = _label("鼠标左键长按角色查看详细信息", &"micro")
	_hint_label.name = "BottomHint"
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_left = 0.0
	_hint_label.offset_top = -30.0
	_hint_label.offset_right = -26.0
	_hint_label.offset_bottom = -8.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.modulate = Color(1, 1, 1, 0.7)
	return _hint_label


func _build_buff_tag(buff: Dictionary) -> Control:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(220, 28)
	shell.add_theme_stylebox_override("panel", _flat_style(OVERLAY_BG, Color(0.0, 0.0, 0.0, 0.0), 0, 3))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	shell.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon := _label(str(buff.get("icon", "●")), &"caption")
	icon.add_theme_color_override("font_color", buff.get("icon_color", UIColors.OCHRE))
	row.add_child(icon)

	var text := _label(str(buff.get("text", "")), &"caption")
	text.add_theme_color_override("font_color", BUFF_TEXT)
	row.add_child(text)

	return shell


func _build_key_box(text: String) -> Control:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(max(34, 18 + text.length() * 12), 34)
	shell.add_theme_stylebox_override("panel", _flat_style(Color(0.97, 0.95, 0.9, 0.95), CARD_BORDER, 1, 4))

	var label := _label(text, &"micro")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shell.add_child(label)
	return shell


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UIColors.INK_BLACK)
	return label


func _flat_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style


func _coerce_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D
	if value is String:
		return load(value) as Texture2D
	return _load_texture(PORTRAIT_LI_PATH)


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
