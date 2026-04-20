@tool
class_name WuxiaFrame
extends PanelContainer

const DEFAULT_BG := Color("1F1914")
const DEFAULT_BORDER := Color("B89050")
const STYLE_HUI_DOUBLE := "hui_double"
const STYLE_HUI_GRID := "hui_grid"
const STYLE_HUI_STRIPES := "hui_stripes"
const STYLE_CORNER_SCROLL := "corner_scroll"
const STYLE_LOTUS_PETAL := "lotus_petal"

@export var bg_color: Color = DEFAULT_BG:
	set(value):
		bg_color = value
		queue_redraw()

@export var border_color: Color = DEFAULT_BORDER:
	set(value):
		border_color = value
		queue_redraw()

@export var border_width: float = 2.0:
	set(value):
		border_width = maxf(value, 1.0)
		_refresh_layout()
		queue_redraw()

@export var corner_size: int = 24:
	set(value):
		corner_size = maxi(value, 14)
		_refresh_layout()
		queue_redraw()

@export_enum("hui_double", "hui_grid", "hui_stripes", "corner_scroll", "lotus_petal")
var corner_style: String = STYLE_HUI_DOUBLE:
	set(value):
		corner_style = _normalize_corner_style(value)
		queue_redraw()

@export var corner_color: Color = DEFAULT_BORDER:
	set(value):
		corner_color = value
		queue_redraw()

var _last_content_pad: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_refresh_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout()
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return

	var frame_rect := rect.grow(-0.5)
	var outline_width := _effective_border_width()
	var outline_half := outline_width * 0.5
	var ornament_width := _ornament_stroke_width()
	var ornament_inset := maxf(outline_width, ornament_width * 0.6) + 1.0
	var outline_rect := frame_rect.grow(-outline_half - 0.25)

	draw_rect(frame_rect, bg_color, true, -1.0, true)
	draw_rect(outline_rect, border_color, false, outline_width, true)

	_draw_corner_pattern(Vector2(ornament_inset, ornament_inset), Vector2(1.0, 1.0))
	_draw_corner_pattern(Vector2(size.x - ornament_inset, ornament_inset), Vector2(-1.0, 1.0))
	_draw_corner_pattern(Vector2(ornament_inset, size.y - ornament_inset), Vector2(1.0, -1.0))
	_draw_corner_pattern(Vector2(size.x - ornament_inset, size.y - ornament_inset), Vector2(-1.0, -1.0))


func _refresh_layout() -> void:
	var pad := int(ceil(_content_padding()))
	if pad == _last_content_pad:
		return
	_last_content_pad = pad
	add_theme_constant_override("margin_left", pad)
	add_theme_constant_override("margin_top", pad)
	add_theme_constant_override("margin_right", pad)
	add_theme_constant_override("margin_bottom", pad)


func _normalize_corner_style(value: String) -> String:
	match value:
		STYLE_HUI_DOUBLE, STYLE_HUI_GRID, STYLE_HUI_STRIPES, STYLE_CORNER_SCROLL, STYLE_LOTUS_PETAL:
			return value
		_:
			return STYLE_HUI_DOUBLE


func _draw_corner_pattern(anchor: Vector2, direction: Vector2) -> void:
	match corner_style:
		STYLE_HUI_GRID:
			_draw_hui_grid(anchor, direction)
		STYLE_HUI_STRIPES:
			_draw_hui_stripes(anchor, direction)
		STYLE_CORNER_SCROLL:
			_draw_corner_scroll(anchor, direction)
		STYLE_LOTUS_PETAL:
			_draw_lotus_petal(anchor, direction)
		_:
			_draw_hui_double(anchor, direction)


func _draw_hui_double(anchor: Vector2, direction: Vector2) -> void:
	var outer := _effective_corner_size()
	var width := _ornament_stroke_width()
	var inner_offset := outer * 0.26
	var inner := outer * 0.56
	var core_offset := outer * 0.53
	var core := outer * 0.19

	_draw_l_shape(anchor, direction, outer, width)
	_draw_l_shape(anchor + direction * Vector2(inner_offset, inner_offset), direction, inner, width)
	_draw_square(anchor + direction * Vector2(core_offset, core_offset), direction, core, width)


func _draw_hui_grid(anchor: Vector2, direction: Vector2) -> void:
	var outer := _effective_corner_size()
	var width := _ornament_stroke_width()
	var frame_offset := outer * 0.17
	var frame_size := outer * 0.62
	var cell := frame_size / 3.0

	_draw_l_shape(anchor, direction, outer, width)
	_draw_square(anchor + direction * Vector2(frame_offset, frame_offset), direction, frame_size, width)

	for index in 2:
		var split := cell * float(index + 1)
		_draw_segment(
			anchor + direction * Vector2(frame_offset + split, frame_offset),
			direction * Vector2(0.0, frame_size),
			corner_color,
			width * 0.82
		)
		_draw_segment(
			anchor + direction * Vector2(frame_offset, frame_offset + split),
			direction * Vector2(frame_size, 0.0),
			corner_color,
			width * 0.82
		)


func _draw_hui_stripes(anchor: Vector2, direction: Vector2) -> void:
	var outer := _effective_corner_size()
	var width := _ornament_stroke_width()
	var frame_offset := outer * 0.16
	var frame_size := outer * 0.62
	var stripe_top := frame_offset + outer * 0.08
	var stripe_height := outer * 0.34
	var stripe_spacing := frame_size * 0.28

	_draw_l_shape(anchor, direction, outer, width)
	_draw_square(anchor + direction * Vector2(frame_offset, frame_offset), direction, frame_size, width)

	for index in 3:
		var x_pos := frame_offset + outer * 0.12 + stripe_spacing * float(index)
		_draw_segment(
			anchor + direction * Vector2(x_pos, stripe_top),
			direction * Vector2(0.0, stripe_height),
			corner_color,
			width * 0.92
		)


func _draw_corner_scroll(anchor: Vector2, direction: Vector2) -> void:
	var outer := _effective_corner_size()
	var width := _ornament_stroke_width()
	var length := outer * 0.88
	var scroll_radius := outer * 0.14
	var joint_offset := outer * 0.56
	var cap_radius := maxf(width * 0.42, outer * 0.05)

	_draw_segment(anchor, direction * Vector2(length, 0.0), corner_color, width)
	_draw_segment(anchor, direction * Vector2(0.0, length), corner_color, width)

	var horiz_center := anchor + direction * Vector2(length, 0.0)
	var vert_center := anchor + direction * Vector2(0.0, length)
	_draw_quarter_arc(horiz_center, scroll_radius, direction, false, width)
	_draw_quarter_arc(vert_center, scroll_radius, direction, true, width)

	draw_circle(anchor + direction * Vector2(joint_offset, 0.0), cap_radius, corner_color)
	draw_circle(anchor + direction * Vector2(0.0, joint_offset), cap_radius, corner_color)
	draw_circle(anchor + direction * Vector2(joint_offset * 0.74, joint_offset * 0.74), cap_radius * 0.9, corner_color)
	_draw_segment(
		anchor + direction * Vector2(outer * 0.28, outer * 0.28),
		direction * Vector2(outer * 0.22, outer * 0.22),
		corner_color,
		width * 0.72
	)


func _draw_lotus_petal(anchor: Vector2, direction: Vector2) -> void:
	var outer := _effective_corner_size()
	var width := _ornament_stroke_width() * 0.84
	var petal_offset := outer * 0.33
	var petal_radius := outer * 0.24
	var center_radius := outer * 0.12

	_draw_l_shape(anchor, direction, outer * 0.62, width)
	_draw_petal(anchor + direction * Vector2(petal_offset, petal_offset * 0.08), petal_radius, direction, 0.0, width)
	_draw_petal(anchor + direction * Vector2(petal_offset * 0.16, petal_offset), petal_radius, direction, PI * 0.5, width)
	_draw_petal(anchor + direction * Vector2(petal_offset * 0.82, petal_offset * 0.82), petal_radius * 1.04, direction, PI * 0.25, width)
	draw_circle(anchor + direction * Vector2(center_radius * 1.9, center_radius * 1.9), center_radius * 0.32, corner_color)


func _draw_petal(center: Vector2, radius: float, direction: Vector2, base_angle: float, width: float) -> void:
	var start := base_angle - PI * 0.52
	var finish := base_angle + PI * 0.52
	draw_arc(center, radius, start, finish, 18, corner_color, width, true)
	draw_arc(center + direction * Vector2(radius * 0.28, radius * 0.28), radius * 0.74, start, finish, 16, corner_color, width * 0.8, true)


func _draw_quarter_arc(center: Vector2, radius: float, direction: Vector2, vertical: bool, width: float) -> void:
	var start := 0.0
	var finish := 0.0

	if direction.x > 0.0 and direction.y > 0.0:
		if vertical:
			start = PI * 1.5
			finish = TAU
		else:
			start = PI
			finish = PI * 1.5
	elif direction.x < 0.0 and direction.y > 0.0:
		if vertical:
			start = PI
			finish = PI * 1.5
		else:
			start = PI * 1.5
			finish = TAU
	elif direction.x > 0.0 and direction.y < 0.0:
		if vertical:
			start = 0.0
			finish = PI * 0.5
		else:
			start = PI * 0.5
			finish = PI
	else:
		if vertical:
			start = PI * 0.5
			finish = PI
		else:
			start = 0.0
			finish = PI * 0.5

	draw_arc(center, radius, start, finish, 16, corner_color, width, true)


func _draw_l_shape(anchor: Vector2, direction: Vector2, length: float, width: float) -> void:
	_draw_segment(anchor, direction * Vector2(length, 0.0), corner_color, width)
	_draw_segment(anchor, direction * Vector2(0.0, length), corner_color, width)


func _draw_square(anchor: Vector2, direction: Vector2, side: float, width: float) -> void:
	var tl := anchor
	var tr := anchor + direction * Vector2(side, 0.0)
	var bl := anchor + direction * Vector2(0.0, side)
	var br := anchor + direction * Vector2(side, side)
	_draw_segment(tl, tr - tl, corner_color, width)
	_draw_segment(tl, bl - tl, corner_color, width)
	_draw_segment(tr, br - tr, corner_color, width)
	_draw_segment(bl, br - bl, corner_color, width)


func _draw_segment(from: Vector2, delta: Vector2, color: Color, width: float) -> void:
	draw_line(from, from + delta, color, width, true)


func _effective_corner_size() -> float:
	var shortest := minf(size.x, size.y)
	return clampf(float(corner_size), 16.0, shortest * 0.42)


func _effective_border_width() -> float:
	var shortest := minf(size.x, size.y)
	return clampf(border_width, 1.0, maxf(1.0, shortest * 0.08))


func _ornament_stroke_width() -> float:
	var base := maxf(_effective_border_width() * 0.85, _effective_corner_size() * 0.095)
	return clampf(base, 1.6, 3.6)


func _content_padding() -> float:
	return _effective_corner_size() + _effective_border_width() + 12.0
