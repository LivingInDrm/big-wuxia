extends Control
class_name BattleHUDV3
signal emit_menu_action(action: StringName)
signal skill_selected(skill_index: int)
signal item_selected(item_id: String)
signal submenu_closed(kind: StringName)

const UIColors := preload("res://resources/ui/colors.gd")
const PORTRAIT_LI_PATH := "res://resources/ui/portraits/half/li_chungang.png"

const HP_FILL := Color("#A84036")
const BAR_BG := Color("#D7CEBC")
const CARD_BG := Color(0.95, 0.92, 0.86, 0.92)
const CARD_BORDER := Color(0.29, 0.23, 0.17, 0.7)
const OVERLAY_BG := Color(0.94, 0.91, 0.84, 0.84)
const BUFF_TEXT := Color("#D7A33D")

const ACTION_SPECS := [
	{"id": &"attack", "key": "A", "icon": Color("#A84036"), "label": "攻击"},
	{"id": &"martial", "key": "V", "icon": Color("#8B5C32"), "label": "武功"},
	{"id": &"item", "key": "B", "icon": Color("#7A6A46"), "label": "道具"},
	{"id": &"wait", "key": "Z", "icon": Color("#5E6C43"), "label": "待机"},
	{"id": &"cancel_move", "key": "Esc", "icon": Color("#4A6B7A"), "label": "取消移动"},
]

var _hint_label: Label
var _character_card_container: Control
var _action_menu_container: Control
var _action_menu_title: Label
var _action_menu_box: VBoxContainer
var _submenu_panel: PanelContainer
var _submenu_title: Label
var _submenu_list: VBoxContainer
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
var _character_card_tween: Tween
var _character_card_target_visible: bool = false
var _action_buttons: Dictionary = {}
var _skill_entries: Array[Dictionary] = []
var _item_entries: Array[Dictionary] = []
var _submenu_kind: StringName = &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func apply_mock(data: Dictionary) -> void:
	if _name_label == null:
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

	add_child(_build_right_menu())
	add_child(_build_character_card())
	add_child(_build_bottom_hint())
	_apply_mouse_passthrough(self)
	set_character_card_visible(false, false)
	set_action_menu_visible(false)
	hide_submenu()


func _build_right_menu() -> Control:
	_action_menu_container = Control.new()
	_action_menu_container.name = "RightMenu"
	_action_menu_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_menu_container.offset_left = -344.0
	_action_menu_container.offset_top = -428.0
	_action_menu_container.offset_right = -28.0
	_action_menu_container.offset_bottom = -28.0

	var shell := VBoxContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 10)
	_action_menu_container.add_child(shell)

	var title_panel := PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(0, 42)
	title_panel.add_theme_stylebox_override("panel", _flat_style(CARD_BG, CARD_BORDER, 2, 4))
	shell.add_child(title_panel)

	_action_menu_title = _label("战术指令", &"caption")
	_action_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_panel.add_child(_action_menu_title)

	_action_menu_box = VBoxContainer.new()
	_action_menu_box.add_theme_constant_override("separation", 8)
	shell.add_child(_action_menu_box)

	for action in ACTION_SPECS:
		_action_menu_box.add_child(_build_action_item(action))

	_submenu_panel = PanelContainer.new()
	_submenu_panel.custom_minimum_size = Vector2(0, 132)
	_submenu_panel.visible = false
	_submenu_panel.add_theme_stylebox_override("panel", _flat_style(CARD_BG, CARD_BORDER, 2, 4))
	shell.add_child(_submenu_panel)

	var submenu_margin := MarginContainer.new()
	submenu_margin.add_theme_constant_override("margin_left", 14)
	submenu_margin.add_theme_constant_override("margin_top", 12)
	submenu_margin.add_theme_constant_override("margin_right", 14)
	submenu_margin.add_theme_constant_override("margin_bottom", 12)
	_submenu_panel.add_child(submenu_margin)

	var submenu_box := VBoxContainer.new()
	submenu_box.add_theme_constant_override("separation", 8)
	submenu_margin.add_child(submenu_box)

	_submenu_title = _label("子面板", &"caption")
	submenu_box.add_child(_submenu_title)

	_submenu_list = VBoxContainer.new()
	_submenu_list.add_theme_constant_override("separation", 6)
	submenu_box.add_child(_submenu_list)

	return _action_menu_container


func _build_action_item(action: Dictionary) -> Control:
	var item := Button.new()
	item.set_meta("retain_mouse_filter", true)
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.custom_minimum_size = Vector2(292, 70)
	item.flat = true
	item.add_theme_stylebox_override("normal", _flat_style(CARD_BG, CARD_BORDER, 2, 4))
	item.add_theme_stylebox_override("hover", _flat_style(Color(0.98, 0.95, 0.88, 0.98), CARD_BORDER, 2, 4))
	item.add_theme_stylebox_override("pressed", _flat_style(Color(0.9, 0.86, 0.77, 0.98), CARD_BORDER, 2, 4))
	item.add_theme_stylebox_override("disabled", _flat_style(Color(0.84, 0.82, 0.78, 0.86), CARD_BORDER, 1, 4))
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.focus_mode = Control.FOCUS_NONE

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
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
	var action_id: StringName = action.get("id", &"")
	_action_buttons[action_id] = item
	item.pressed.connect(_on_action_button_pressed.bind(action_id))
	return item


func _build_character_card() -> Control:
	_character_card_container = Control.new()
	_character_card_container.name = "CharacterCardContainer"
	_character_card_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_character_card_container.offset_left = 24.0
	_character_card_container.offset_top = -546.0
	_character_card_container.offset_right = 612.0
	_character_card_container.offset_bottom = -24.0

	var root := Control.new()
	root.name = "CharacterCard"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_character_card_container.add_child(root)

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
	_name_label.name = "NameLabel"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)

	_exp_label = _label("经验  5/8050", &"caption")
	_exp_label.name = "ExpLabel"
	_exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_exp_label)

	_level_label = _label("等级  ·  54/100", &"caption")
	_level_label.name = "LevelLabel"
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

	return _character_card_container


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
	value_label.name = "HPValueLabel" if with_side_stat else "MPValueLabel"
	value_label.offset_left = 10.0
	value_label.offset_top = 2.0
	value_label.offset_right = -10.0
	value_label.offset_bottom = -2.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_host.add_child(value_label)

	if with_side_stat:
		var side := _label("轻功  398", &"caption")
		side.name = "QinggongLabel"
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


func set_hint_text(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


func set_action_menu_visible(is_visible: bool, title: String = "战术指令") -> void:
	if _action_menu_container == null:
		return
	_action_menu_container.visible = is_visible
	if _action_menu_title != null:
		_action_menu_title.text = title
	if not is_visible:
		hide_submenu()


func set_action_enabled(action: StringName, enabled: bool) -> void:
	var button = _action_buttons.get(action)
	if button is Button:
		(button as Button).disabled = not enabled


func set_skill_entries(entries: Array[Dictionary]) -> void:
	_skill_entries = entries.duplicate(true)
	if _submenu_kind == &"skill":
		_rebuild_submenu()


func set_item_entries(entries: Array[Dictionary]) -> void:
	_item_entries = entries.duplicate(true)
	if _submenu_kind == &"item":
		_rebuild_submenu()


func show_skill_panel() -> void:
	_submenu_kind = &"skill"
	_rebuild_submenu()


func show_item_panel() -> void:
	_submenu_kind = &"item"
	_rebuild_submenu()


func trigger_menu_action(action: StringName) -> void:
	emit_menu_action.emit(action)


func hide_submenu(expected_kind: StringName = &"") -> void:
	if _submenu_panel == null:
		return
	if expected_kind != &"" and _submenu_kind != expected_kind:
		return
	var previous_kind := _submenu_kind
	_submenu_kind = &""
	_submenu_panel.visible = false
	for child in _submenu_list.get_children():
		child.queue_free()
	if previous_kind != &"":
		submenu_closed.emit(previous_kind)


func is_submenu_open(kind: StringName = &"") -> bool:
	if _submenu_panel == null or not _submenu_panel.visible:
		return false
	return kind == &"" or _submenu_kind == kind


func set_character_card_visible(is_visible: bool, animate: bool = true) -> void:
	if _character_card_container == null:
		return
	if _character_card_tween != null and _character_card_tween.is_valid():
		_character_card_tween.kill()
	var state_unchanged := _character_card_target_visible == is_visible \
		and _character_card_container.visible == is_visible
	_character_card_target_visible = is_visible
	if not animate:
		_character_card_container.visible = is_visible
		_character_card_container.modulate.a = 1.0 if is_visible else 0.0
		return
	if state_unchanged:
		_character_card_container.modulate.a = 1.0 if is_visible else 0.0
		return
	if is_visible:
		_character_card_container.visible = true
		_character_card_container.modulate.a = minf(_character_card_container.modulate.a, 1.0)
		_character_card_tween = create_tween()
		_character_card_tween.tween_property(_character_card_container, "modulate:a", 1.0, 0.2)
		return
	_character_card_tween = create_tween()
	_character_card_tween.tween_property(_character_card_container, "modulate:a", 0.0, 0.2)
	_character_card_tween.finished.connect(func() -> void:
		if is_instance_valid(_character_card_container):
			_character_card_container.visible = false
	)


func is_character_card_visible() -> bool:
	return _character_card_container != null and _character_card_container.visible


func _apply_mouse_passthrough(node: Node) -> void:
	if node is Control:
		var control := node as Control
		# v3 HUD is display-only for now. Future clickable controls can opt out
		# by setting `retain_mouse_filter` before this runs.
		if not bool(control.get_meta("retain_mouse_filter", false)):
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_apply_mouse_passthrough(child)


func _rebuild_submenu() -> void:
	if _submenu_panel == null:
		return
	for child in _submenu_list.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = []
	match _submenu_kind:
		&"skill":
			_submenu_title.text = "武功"
			entries = _skill_entries
		&"item":
			_submenu_title.text = "道具"
			entries = _item_entries
		_:
			_submenu_panel.visible = false
			return
	for entry in entries:
		_submenu_list.add_child(_build_submenu_button(entry))
	_submenu_panel.visible = true


func _build_submenu_button(entry: Dictionary) -> Control:
	var button := Button.new()
	button.set_meta("retain_mouse_filter", true)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 46)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = bool(entry.get("disabled", false))
	button.add_theme_stylebox_override("normal", _flat_style(Color(0.98, 0.95, 0.9, 0.92), CARD_BORDER, 1, 3))
	button.add_theme_stylebox_override("hover", _flat_style(Color(1.0, 0.97, 0.9, 0.98), CARD_BORDER, 1, 3))
	button.add_theme_stylebox_override("pressed", _flat_style(Color(0.9, 0.86, 0.77, 0.98), CARD_BORDER, 1, 3))
	button.add_theme_stylebox_override("disabled", _flat_style(Color(0.84, 0.82, 0.78, 0.86), CARD_BORDER, 1, 3))
	var key_text := String(entry.get("key", ""))
	var label_text := String(entry.get("label", ""))
	var detail_text := String(entry.get("detail", ""))
	button.text = "%s  %s" % [key_text, label_text] if not key_text.is_empty() else label_text
	if not detail_text.is_empty():
		button.text += "    %s" % detail_text
	if entry.get("type") == &"skill":
		button.pressed.connect(_on_skill_entry_pressed.bind(int(entry.get("index", -1))))
	else:
		button.pressed.connect(_on_item_entry_pressed.bind(String(entry.get("item_id", ""))))
	return button


func _on_action_button_pressed(action: StringName) -> void:
	trigger_menu_action(action)


func _on_skill_entry_pressed(skill_index: int) -> void:
	hide_submenu(&"skill")
	skill_selected.emit(skill_index)


func _on_item_entry_pressed(item_id: String) -> void:
	hide_submenu(&"item")
	item_selected.emit(item_id)


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
