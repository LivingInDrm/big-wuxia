@tool
class_name WuxiaButton
extends Button

const HOVER_BG := Color("EAE3D0")
const PRESSED_BORDER_FACTOR := 0.7
const DEFAULT_ICON_COLOR := Color("2C241C")

@export_enum("回字", "云", "折角", "竹节") var pattern_style: String = "回字":
	set(value):
		pattern_style = value
		queue_redraw()

@export var corner_size: int = 18:
	set(value):
		corner_size = max(value, 10)
		_refresh_layout()
		queue_redraw()

@export var bg_color: Color = Color("F2EDE0"):
	set(value):
		bg_color = value
		queue_redraw()

@export var border_color: Color = Color("1A1A1A"):
	set(value):
		border_color = value
		queue_redraw()

@export var pattern_color: Color = Color("1A1A1A"):
	set(value):
		pattern_color = value
		queue_redraw()

@export var icon_texture: Texture2D = null:
	set(value):
		icon_texture = value
		_refresh_icon()

var _content_margin: MarginContainer
var _content_row: HBoxContainer
var _icon_holder: Control
var _icon_placeholder: ColorRect
var _icon_texture_rect: TextureRect
var _text_label: Label
var _is_hovered := false
var _is_pressed_visual := false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = false


func _ready() -> void:
	_ensure_content()
	_refresh_layout()
	_refresh_icon()
	_sync_text()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout()
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		_apply_text_theme()
		queue_redraw()


func _draw() -> void:
	_ensure_content()
	_sync_text()

	var rect := Rect2(Vector2.ZERO, size)
	var fill := _resolve_background_color()
	var border_width := 3.0 if _is_pressed_visual else 2.0
	var stroke_width := _corner_stroke_width()
	var corner_inset := maxf(border_width, stroke_width * 0.5) + 1.0
	var effective_border := _resolve_pressed_color(border_color) if _is_pressed_visual else border_color
	var effective_pattern := _resolve_pressed_color(pattern_color) if _is_pressed_visual else pattern_color

	draw_rect(rect, fill, true, -1.0, true)
	draw_rect(rect.grow(-border_width * 0.5), effective_border, false, border_width, true)

	_draw_corner_pattern(Vector2(corner_inset, corner_inset), Vector2(1, 1), effective_pattern)
	_draw_corner_pattern(Vector2(size.x - corner_inset, corner_inset), Vector2(-1, 1), effective_pattern)
	_draw_corner_pattern(Vector2(corner_inset, size.y - corner_inset), Vector2(1, -1), effective_pattern)
	_draw_corner_pattern(Vector2(size.x - corner_inset, size.y - corner_inset), Vector2(-1, -1), effective_pattern)


func _ensure_content() -> void:
	if is_instance_valid(_content_margin):
		return

	_content_margin = MarginContainer.new()
	_content_margin.name = "ContentMargin"
	_content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content_margin)

	_content_row = HBoxContainer.new()
	_content_row.name = "ContentRow"
	_content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_row.add_theme_constant_override("separation", 8)
	_content_margin.add_child(_content_row)

	_icon_holder = Control.new()
	_icon_holder.name = "IconHolder"
	_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_row.add_child(_icon_holder)

	_icon_placeholder = ColorRect.new()
	_icon_placeholder.name = "IconPlaceholder"
	_icon_placeholder.color = DEFAULT_ICON_COLOR
	_icon_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_holder.add_child(_icon_placeholder)

	_icon_texture_rect = TextureRect.new()
	_icon_texture_rect.name = "IconTexture"
	_icon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_holder.add_child(_icon_texture_rect)

	_text_label = Label.new()
	_text_label.name = "TextLabel"
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_row.add_child(_text_label)

	_apply_text_theme()


func _refresh_layout() -> void:
	if not is_instance_valid(_content_margin):
		return

	var icon_size: int = _icon_size()
	var horizontal_pad: int = maxi(int(ceil(_effective_corner_size())) + 14, 24)
	var vertical_pad: int = clampi(int((size.y - icon_size) * 0.5), 4, 18)

	_content_margin.add_theme_constant_override("margin_left", horizontal_pad)
	_content_margin.add_theme_constant_override("margin_right", horizontal_pad)
	_content_margin.add_theme_constant_override("margin_top", vertical_pad)
	_content_margin.add_theme_constant_override("margin_bottom", vertical_pad)

	_icon_holder.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon_holder.size = Vector2(icon_size, icon_size)

	var icon_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(icon_size, icon_size))
	_icon_placeholder.position = icon_rect.position
	_icon_placeholder.size = icon_rect.size
	_icon_texture_rect.position = icon_rect.position
	_icon_texture_rect.custom_minimum_size = icon_rect.size
	_icon_texture_rect.size = icon_rect.size

	_apply_text_theme()


func _refresh_icon() -> void:
	if not is_instance_valid(_icon_texture_rect):
		return
	_icon_texture_rect.texture = icon_texture
	var show_texture: bool = icon_texture != null
	_icon_texture_rect.visible = show_texture
	_icon_placeholder.visible = not show_texture


func _apply_text_theme() -> void:
	if not is_instance_valid(_text_label):
		return
	var font_size: int = clampi(int(size.y * 0.42), 18, 32)
	_text_label.add_theme_font_size_override("font_size", font_size)
	_text_label.add_theme_color_override("font_color", Color("1E1913"))


func _sync_text() -> void:
	if is_instance_valid(_text_label) and _text_label.text != text:
		_text_label.text = text


func _resolve_background_color() -> Color:
	if _is_pressed_visual:
		return bg_color.darkened(0.06)
	if _is_hovered:
		return HOVER_BG
	return bg_color


func _resolve_pressed_color(base: Color) -> Color:
	return base.darkened(1.0 - PRESSED_BORDER_FACTOR)


func _icon_size() -> int:
	return min(32, max(20, int(size.y) - 8))


func _draw_corner_pattern(anchor: Vector2, direction: Vector2, color: Color) -> void:
	match pattern_style:
		"云":
			_draw_cloud_corner(anchor, direction, color)
		"折角":
			_draw_ink_corner(anchor, direction, color)
		"竹节":
			_draw_bamboo_corner(anchor, direction, color)
		_:
			_draw_hui_corner(anchor, direction, color)


func _draw_hui_corner(anchor: Vector2, direction: Vector2, color: Color) -> void:
	var outer := _effective_corner_size()
	var inner_offset := outer * 0.28
	var inner := outer * 0.52
	var notch := inner * 0.42
	var width := _corner_stroke_width()

	_draw_segment(anchor, direction * Vector2(outer, 0.0), color, width)
	_draw_segment(anchor, direction * Vector2(0.0, outer), color, width)

	var inner_corner: Vector2 = anchor + direction * Vector2(inner_offset, inner_offset)
	_draw_segment(inner_corner, direction * Vector2(inner, 0.0), color, width)
	_draw_segment(inner_corner, direction * Vector2(0.0, inner), color, width)

	var notch_corner: Vector2 = anchor + direction * Vector2(inner_offset + notch, inner_offset + notch)
	_draw_segment(notch_corner, direction * Vector2(inner - notch, 0.0), color, width)
	_draw_segment(notch_corner, direction * Vector2(0.0, inner - notch), color, width)
	_draw_segment(
		anchor + direction * Vector2(inner_offset, inner_offset + inner),
		direction * Vector2(notch, 0.0),
		color,
		width
	)
	_draw_segment(
		anchor + direction * Vector2(inner_offset + inner, inner_offset),
		direction * Vector2(0.0, notch),
		color,
		width
	)


func _draw_cloud_corner(anchor: Vector2, direction: Vector2, color: Color) -> void:
	var outer := _effective_corner_size()
	var width := _corner_stroke_width()
	var center := anchor + direction * Vector2(outer * 0.72, outer * 0.72)
	var outer_radius := outer * 0.68
	var bump_radius := outer * 0.15
	var bump_start := anchor + direction * Vector2(outer * 0.28, outer * 0.20)
	var bump_step := outer * 0.18
	var bump_lift := outer * 0.06

	# 如意云头: 外侧大弧 + 三个内侧云头凸起，避免旧版两段弧线的拼凑感。
	draw_arc(center, outer_radius, PI, PI * 1.5, 24, color, width, true)

	for index in 3:
		var bump_center := bump_start + direction * Vector2(bump_step * float(index), -bump_lift * float(abs(index - 1) - 1))
		draw_arc(bump_center, bump_radius, PI, TAU, 12, color, width, true)

	var tail_center := anchor + direction * Vector2(outer * 0.62, outer * 0.34)
	draw_arc(tail_center, outer * 0.2, PI * 0.95, PI * 1.78, 16, color, width, true)


func _draw_ink_corner(anchor: Vector2, direction: Vector2, color: Color) -> void:
	var length := _effective_corner_size()
	var width := _corner_stroke_width()
	var dot_offset := length * 0.58
	var dot_radius := clampf(length * 0.17, 2.2, 4.0)
	var splash_offset := length * 0.26
	_draw_segment(anchor, direction * Vector2(length, 0.0), color, width)
	_draw_segment(anchor, direction * Vector2(0.0, length), color, width)
	draw_circle(anchor + direction * Vector2(dot_offset, dot_offset), dot_radius, color)
	draw_circle(anchor + direction * Vector2(splash_offset, length - 2.0), dot_radius * 0.5, color)


func _draw_bamboo_corner(anchor: Vector2, direction: Vector2, color: Color) -> void:
	var corner := _effective_corner_size()
	var width := _corner_stroke_width()
	var stem := corner * 0.94
	var inset := corner * 0.24
	var node_spacing := corner * 0.28
	var node_width := maxf(6.0, corner * 0.33)
	_draw_segment(anchor, direction * Vector2(stem, 0.0), color, width)
	_draw_segment(anchor + direction * Vector2(inset, 0.0), direction * Vector2(0.0, stem), color, width)
	_draw_segment(anchor + direction * Vector2(inset - node_width * 0.5, node_spacing), direction * Vector2(node_width, 0.0), color, width)
	_draw_segment(anchor + direction * Vector2(inset - node_width * 0.5, node_spacing * 1.9), direction * Vector2(node_width, 0.0), color, width)


func _draw_segment(from: Vector2, delta: Vector2, color: Color, width: float) -> void:
	draw_line(from, from + delta, color, width, true)


func _effective_corner_size() -> float:
	return clampf(float(corner_size), 16.0, size.y * 0.7)


func _corner_stroke_width() -> float:
	return maxf(2.0, _effective_corner_size() * 0.12)


func _on_mouse_entered() -> void:
	_is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_is_pressed_visual = false
	queue_redraw()


func _on_button_down() -> void:
	_is_pressed_visual = true
	queue_redraw()


func _on_button_up() -> void:
	_is_pressed_visual = false
	queue_redraw()
