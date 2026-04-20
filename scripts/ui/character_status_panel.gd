extends Control

const UIColors := preload("res://resources/ui/colors.gd")

@export var character_name: String = "李淳罡":
	set(value):
		character_name = value
		_refresh_ui()

@export var level: int = 54:
	set(value):
		level = value
		_refresh_ui()

@export var exp_cur: int = 5:
	set(value):
		exp_cur = value
		_refresh_ui()

@export var exp_max: int = 8050:
	set(value):
		exp_max = max(value, 1)
		_refresh_ui()

@export var hp_cur: int = 2877:
	set(value):
		hp_cur = value
		_refresh_ui()

@export var hp_max: int = 2877:
	set(value):
		hp_max = max(value, 1)
		_refresh_ui()

@export var mp_cur: int = 3765:
	set(value):
		mp_cur = value
		_refresh_ui()

@export var mp_max: int = 3765:
	set(value):
		mp_max = max(value, 1)
		_refresh_ui()

@export var qinggong: int = 398:
	set(value):
		qinggong = value
		_refresh_ui()

@export var portrait_texture: Texture2D = preload("res://resources/ui/portraits/half/li_chungang.png"):
	set(value):
		portrait_texture = value
		_refresh_ui()

@export var buffs: Array[Dictionary] = [
	{"text": "连击 +10%", "color": Color("D2B06A")},
	{"text": "自动回血 +5%", "color": Color("D2B06A")}
]:
	set(value):
		buffs = value
		_refresh_buffs()

@onready var _name_label: Label = %NameLabel
@onready var _exp_label: Label = %ExpLabel
@onready var _level_label: Label = %LevelLabel
@onready var _exp_bar: Control = %ExpBar
@onready var _portrait_rect: TextureRect = %PortraitRect
@onready var _hp_bar: Control = %HpBar
@onready var _hp_value_label: Label = %HpValueLabel
@onready var _mp_bar: Control = %MpBar
@onready var _mp_value_label: Label = %MpValueLabel
@onready var _qinggong_value_label: Label = %QinggongValueLabel
@onready var _buffs_box: VBoxContainer = %BuffsBox


func _ready() -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	if not is_node_ready():
		return

	_name_label.text = character_name
	_exp_label.text = "经验 %d/%d" % [exp_cur, exp_max]
	_level_label.text = "等级 %d/100" % level

	_exp_bar.min_value = 0.0
	_exp_bar.max_value = float(exp_max)
	_exp_bar.value = clampf(float(exp_cur), 0.0, float(exp_max))

	_hp_bar.min_value = 0.0
	_hp_bar.max_value = float(hp_max)
	_hp_bar.value = clampf(float(hp_cur), 0.0, float(hp_max))
	_hp_value_label.text = "%d/%d" % [hp_cur, hp_max]

	_mp_bar.min_value = 0.0
	_mp_bar.max_value = float(mp_max)
	_mp_bar.value = clampf(float(mp_cur), 0.0, float(mp_max))
	_mp_value_label.text = "%d/%d" % [mp_cur, mp_max]

	_qinggong_value_label.text = str(qinggong)
	_portrait_rect.texture = portrait_texture

	_refresh_buffs()


func _refresh_buffs() -> void:
	if not is_node_ready():
		return

	for child in _buffs_box.get_children():
		child.queue_free()

	for buff in buffs:
		_buffs_box.add_child(_build_buff_entry(buff))


func _build_buff_entry(buff: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.color = Color(0.74, 0.58, 0.28, 0.92)
	row.add_child(dot)

	var label := Label.new()
	label.text = str(buff.get("text", ""))
	label.theme_type_variation = &"caption"
	label.add_theme_color_override("font_color", buff.get("color", UIColors.OCHRE))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	return row
