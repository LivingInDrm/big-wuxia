extends Control
class_name BattleHUDV3
signal emit_menu_action(action: StringName)
signal skill_selected(skill_index: int)
signal item_selected(item_id: String)
signal submenu_closed(kind: StringName)

const UIColors := preload("res://resources/ui/colors.gd")
const CHARACTER_STATUS_PANEL := preload("res://scenes/ui/character_status_panel.tscn")

const CARD_BG := Color(0.95, 0.92, 0.86, 0.92)
const CARD_BORDER := Color(0.29, 0.23, 0.17, 0.7)

const ACTION_SPECS := [
	{"id": &"attack", "key": "A", "icon": Color("#A84036"), "label": "攻击"},
	{"id": &"martial", "key": "V", "icon": Color("#8B5C32"), "label": "武功"},
	{"id": &"item", "key": "B", "icon": Color("#7A6A46"), "label": "道具"},
	{"id": &"wait", "key": "Z", "icon": Color("#5E6C43"), "label": "待机"},
	{"id": &"cancel_move", "key": "Esc", "icon": Color("#4A6B7A"), "label": "取消移动"},
]
const RIGHT_MENU_WIDTH := 360.0
const RIGHT_MENU_RIGHT_MARGIN := 28.0
const RIGHT_MENU_BOTTOM_MARGIN := 28.0
const RIGHT_MENU_TOP_MARGIN := 48.0
const ACTION_BUTTON_WIDTH := 332.0
const SUBMENU_PANEL_WIDTH := 332.0
const SUBMENU_MAX_HEIGHT := 280.0
const WUXIA_BUTTON_MIN_SIZE := Vector2(120, 32)

var _hint_label: Label
var _character_card_container: Control
var _action_menu_container: Control
var _action_menu_box: VBoxContainer
var _submenu_panel: Control
var _submenu_scroll: ScrollContainer
var _submenu_list: VBoxContainer
var _character_status_panel: Node = null
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
	if _character_status_panel == null:
		return

	_apply_panel_data(data)


func bind_vm(vm) -> void:
	_vm = vm


func refresh() -> void:
	if _vm == null:
		push_warning("[BattleHUDV3] refresh called without VM")
		return
	_refresh_character_panel()


func _refresh_character_panel() -> void:
	if _character_status_panel == null or _vm == null:
		return

	var unit: Node = _vm.current_unit
	if unit == null:
		return

	var unit_data: Object = unit.get("unit_data")
	if unit_data != null and bool(unit_data.get("is_enemy")):
		return

	var unit_id := ""
	var character_name := ""
	if unit_data != null:
		unit_id = String(unit_data.get("unit_id"))
		character_name = String(unit_data.get("unit_name"))
	if character_name.is_empty():
		character_name = String(unit.get("display_name"))
	if character_name.is_empty():
		character_name = unit_id

	var hp_cur: int = int(unit.get("current_hp"))
	var hp_max: int = max(int(unit.get("max_hp")), 1)
	var mp_cur: int = int(unit.get("current_mp"))
	var mp_max: int = max(int(unit.get("max_mp")), 1)

	_apply_panel_data({
		"character_name": character_name,
		"level": 54,
		"exp_cur": 5,
		"exp_max": 8050,
		"hp_cur": hp_cur,
		"hp_max": hp_max,
		"mp_cur": mp_cur,
		"mp_max": mp_max,
		"qinggong": 398,
		"portrait_texture": _portrait_for_unit(unit_id),
		"buffs": [],
	})


func _apply_panel_data(data: Dictionary) -> void:
	if _character_status_panel == null:
		return
	var buffs: Array = data.get("buffs", [])
	_character_status_panel.set("character_name", String(data.get("character_name", "未知角色")))
	_character_status_panel.set("level", int(data.get("level", 54)))
	_character_status_panel.set("exp_cur", int(data.get("exp_cur", 5)))
	_character_status_panel.set("exp_max", max(int(data.get("exp_max", 8050)), 1))
	_character_status_panel.set("hp_cur", int(data.get("hp_cur", 0)))
	_character_status_panel.set("hp_max", max(int(data.get("hp_max", 1)), 1))
	_character_status_panel.set("mp_cur", int(data.get("mp_cur", 0)))
	_character_status_panel.set("mp_max", max(int(data.get("mp_max", 1)), 1))
	_character_status_panel.set("qinggong", int(data.get("qinggong", 398)))
	_character_status_panel.set("portrait_texture", data.get("portrait_texture", null))
	_character_status_panel.set("buffs", buffs)
	var buffs_box := _character_status_panel.get_node_or_null("BottomAnchor/PanelRoot/BuffsBox")
	if buffs_box is CanvasItem:
		(buffs_box as CanvasItem).visible = not buffs.is_empty()


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
	_action_menu_container.offset_left = -RIGHT_MENU_WIDTH - RIGHT_MENU_RIGHT_MARGIN
	_action_menu_container.offset_top = -(768.0 - RIGHT_MENU_TOP_MARGIN - RIGHT_MENU_BOTTOM_MARGIN)
	_action_menu_container.offset_right = -RIGHT_MENU_RIGHT_MARGIN
	_action_menu_container.offset_bottom = -RIGHT_MENU_BOTTOM_MARGIN

	var shell := VBoxContainer.new()
	shell.name = "MenuStack"
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 10)
	_action_menu_container.add_child(shell)

	_action_menu_box = VBoxContainer.new()
	_action_menu_box.add_theme_constant_override("separation", 8)
	shell.add_child(_action_menu_box)

	for action in ACTION_SPECS:
		_action_menu_box.add_child(_build_action_item(action))

	_submenu_panel = Control.new()
	_submenu_panel.custom_minimum_size = Vector2(SUBMENU_PANEL_WIDTH, 0)
	_submenu_panel.visible = false
	shell.add_child(_submenu_panel)

	_submenu_scroll = ScrollContainer.new()
	_submenu_scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_submenu_scroll.custom_minimum_size = Vector2(SUBMENU_PANEL_WIDTH, SUBMENU_MAX_HEIGHT)
	_submenu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_submenu_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_submenu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_submenu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_submenu_scroll.clip_contents = true
	_submenu_panel.add_child(_submenu_scroll)

	_submenu_list = VBoxContainer.new()
	_submenu_list.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_submenu_list.offset_right = SUBMENU_PANEL_WIDTH
	_submenu_list.add_theme_constant_override("separation", 6)
	_submenu_scroll.add_child(_submenu_list)

	return _action_menu_container


func _build_action_item(action: Dictionary) -> Control:
	var item := _create_wuxia_button(
		_build_button_text(String(action.get("label", "")), String(action.get("key", ""))),
		Vector2(maxf(ACTION_BUTTON_WIDTH, WUXIA_BUTTON_MIN_SIZE.x), 70)
	)
	var action_id: StringName = action.get("id", &"")
	_action_buttons[action_id] = item
	item.pressed.connect(_on_action_button_pressed.bind(action_id))
	return item


func _build_character_card() -> Control:
	_character_card_container = Control.new()
	_character_card_container.name = "CharacterCardContainer"
	_character_card_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_character_card_container.offset_left = 24.0
	_character_card_container.offset_top = -240.0
	_character_card_container.offset_right = 960.0
	_character_card_container.offset_bottom = -24.0
	_character_card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_status_panel = CHARACTER_STATUS_PANEL.instantiate()
	_character_card_container.add_child(_character_status_panel)
	return _character_card_container


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
	if not is_visible:
		hide_submenu()


func set_action_enabled(action: StringName, enabled: bool) -> void:
	var button = _action_buttons.get(action)
	if button is WuxiaButton:
		_set_wuxia_button_enabled(button as WuxiaButton, enabled)


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
	if _action_menu_box != null:
		_action_menu_box.visible = true
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


func _portrait_for_unit(unit_id: String) -> Texture2D:
	if unit_id.is_empty():
		return null
	var path := "res://resources/ui/portraits/half/%s.png" % unit_id
	if ResourceLoader.exists(path):
		return load(path)
	return null


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
			entries = _skill_entries
		&"item":
			entries = _item_entries
		_:
			_submenu_panel.visible = false
			if _action_menu_box != null:
				_action_menu_box.visible = true
			return
	for entry in entries:
		_submenu_list.add_child(_build_submenu_button(entry))
	if _action_menu_box != null:
		_action_menu_box.visible = false
	var button_count: int = maxi(entries.size(), 1)
	var content_height: float = button_count * 58.0 + maxi(button_count - 1, 0) * 6.0
	var panel_height: float = minf(content_height, SUBMENU_MAX_HEIGHT)
	_submenu_scroll.custom_minimum_size = Vector2(SUBMENU_PANEL_WIDTH, panel_height)
	_submenu_scroll.size = Vector2(SUBMENU_PANEL_WIDTH, panel_height)
	_submenu_panel.custom_minimum_size = Vector2(SUBMENU_PANEL_WIDTH, panel_height)
	_submenu_panel.visible = true


func _build_submenu_button(entry: Dictionary) -> Control:
	var key_text := String(entry.get("key", ""))
	var label_text := String(entry.get("label", ""))
	var detail_text := String(entry.get("detail", ""))
	var button := _create_wuxia_button(
		_build_button_text(label_text, key_text),
		Vector2(maxf(SUBMENU_PANEL_WIDTH - 28.0, WUXIA_BUTTON_MIN_SIZE.x), 58)
	)
	button.tooltip_text = detail_text
	_set_wuxia_button_enabled(button, not bool(entry.get("disabled", false)))
	if entry.get("type") == &"skill":
		button.pressed.connect(_on_skill_entry_pressed.bind(int(entry.get("index", -1))))
	else:
		button.pressed.connect(_on_item_entry_pressed.bind(String(entry.get("item_id", ""))))
	return button


func _create_wuxia_button(text: String, minimum_size: Vector2) -> WuxiaButton:
	var button := WuxiaButton.new()
	button.set_meta("retain_mouse_filter", true)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(
		maxf(minimum_size.x, WUXIA_BUTTON_MIN_SIZE.x),
		maxf(minimum_size.y, WUXIA_BUTTON_MIN_SIZE.y)
	)
	button.bg_color = CARD_BG
	button.border_color = CARD_BORDER
	button.pattern_color = CARD_BORDER
	button.text = text
	return button


func _build_button_text(label_text: String, key_text: String = "") -> String:
	if key_text.is_empty():
		return label_text
	return "%s  [%s]" % [label_text, key_text]


func _set_wuxia_button_enabled(button: WuxiaButton, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate = Color(1, 1, 1, 1) if enabled else Color(0.74, 0.72, 0.68, 0.78)


func _on_action_button_pressed(action: StringName) -> void:
	trigger_menu_action(action)


func _on_skill_entry_pressed(skill_index: int) -> void:
	hide_submenu(&"skill")
	skill_selected.emit(skill_index)


func _on_item_entry_pressed(item_id: String) -> void:
	hide_submenu(&"item")
	item_selected.emit(item_id)


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
