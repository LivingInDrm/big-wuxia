@tool
class_name WuxiaFrame
extends PanelContainer

const DEFAULT_BG := Color("1F1914")
const DEFAULT_BORDER := Color("B89050")
const STYLE_EMPHASIS := "emphasis"
const STYLE_REGULAR := "regular"
const STYLE_PLAIN := "plain"
const LEGACY_STYLE_HUI_DOUBLE := "hui_double"
const LEGACY_STYLE_HUI_DOUBLE_HOLLOW := "hui_double_hollow"

@export var bg_color: Color = DEFAULT_BG:
	set(value):
		bg_color = value
		queue_redraw()

@export var border_color: Color = DEFAULT_BORDER:
	set(value):
		border_color = value
		queue_redraw()

@export var border_width: float = 1.5:
	set(value):
		border_width = maxf(value, 1.0)
		_refresh_layout()
		queue_redraw()

@export var corner_radius: float = 14.0:
	set(value):
		corner_radius = maxf(value, 2.0)
		_refresh_layout()
		queue_redraw()

@export var notch_size: float = 9.0:
	set(value):
		notch_size = maxf(value, 4.0)
		_refresh_layout()
		queue_redraw()

@export var corner_size: int = 24:
	set(value):
		corner_size = maxi(value, 14)
		_refresh_layout()
		queue_redraw()

@export_enum("emphasis", "regular", "plain")
var corner_style: String = STYLE_REGULAR:
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
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
	if corner_style == STYLE_PLAIN:
		_draw_plain_frame(frame_rect, outline_width)
		return

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
		STYLE_EMPHASIS:
			return STYLE_EMPHASIS
		STYLE_REGULAR:
			return STYLE_REGULAR
		STYLE_PLAIN:
			return STYLE_PLAIN
		LEGACY_STYLE_HUI_DOUBLE:
			return STYLE_EMPHASIS
		LEGACY_STYLE_HUI_DOUBLE_HOLLOW:
			return STYLE_REGULAR
		_:
			return STYLE_REGULAR


func _draw_corner_pattern(anchor: Vector2, direction: Vector2) -> void:
	match corner_style:
		STYLE_EMPHASIS:
			_draw_emphasis_corner(anchor, direction)
		STYLE_PLAIN:
			return
		_:
			_draw_regular_corner(anchor, direction)


func _draw_plain_frame(frame_rect: Rect2, outline_width: float) -> void:
	var fill_points := _build_plain_notched_points(frame_rect, _effective_notch_size(frame_rect))
	if fill_points.size() < 3:
		return
	draw_colored_polygon(fill_points, bg_color)

	var stroke_inset := outline_width * 0.5
	var stroke_rect := frame_rect.grow(-stroke_inset)
	var stroke_points := _build_plain_notched_points(stroke_rect, _effective_notch_size(stroke_rect))
	if stroke_points.is_empty():
		return
	stroke_points.append(stroke_points[0])
	draw_polyline(stroke_points, border_color, outline_width, true)


func _build_plain_notched_points(rect: Rect2, notch: float) -> PackedVector2Array:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return PackedVector2Array()

	var clamped_notch := clampf(notch, 1.0, minf(rect.size.x, rect.size.y) * 0.5 - 0.5)
	if clamped_notch <= 0.0:
		return PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])

	return PackedVector2Array([
		Vector2(rect.position.x + clamped_notch, rect.position.y),
		Vector2(rect.end.x - clamped_notch, rect.position.y),
		Vector2(rect.end.x - clamped_notch, rect.position.y + clamped_notch),
		Vector2(rect.end.x, rect.position.y + clamped_notch),
		Vector2(rect.end.x, rect.end.y - clamped_notch),
		Vector2(rect.end.x - clamped_notch, rect.end.y - clamped_notch),
		Vector2(rect.end.x - clamped_notch, rect.end.y),
		Vector2(rect.position.x + clamped_notch, rect.end.y),
		Vector2(rect.position.x + clamped_notch, rect.end.y - clamped_notch),
		Vector2(rect.position.x, rect.end.y - clamped_notch),
		Vector2(rect.position.x, rect.position.y + clamped_notch),
		Vector2(rect.position.x + clamped_notch, rect.position.y + clamped_notch),
	])


func _draw_emphasis_corner(anchor: Vector2, direction: Vector2) -> void:
	_draw_hui_double_variant(anchor, direction, true)


func _draw_regular_corner(anchor: Vector2, direction: Vector2) -> void:
	_draw_hui_double_variant(anchor, direction, false)


func _draw_hui_double_variant(anchor: Vector2, direction: Vector2, draw_core: bool) -> void:
	var outer := _effective_corner_size()
	var width := _ornament_stroke_width()
	var inner_offset := outer * 0.26
	var inner := outer * 0.56
	var core_offset := outer * 0.53
	var core := outer * 0.19

	_draw_l_shape(anchor, direction, outer, width)
	_draw_l_shape(anchor + direction * Vector2(inner_offset, inner_offset), direction, inner, width)
	if draw_core:
		_draw_square(anchor + direction * Vector2(core_offset, core_offset), direction, core, width)


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


func _effective_corner_radius(rect: Rect2 = Rect2(Vector2.ZERO, size)) -> float:
	var shortest := minf(rect.size.x, rect.size.y)
	return clampf(corner_radius, 2.0, maxf(2.0, shortest * 0.45))


func _effective_notch_size(rect: Rect2 = Rect2(Vector2.ZERO, size)) -> float:
	var shortest := minf(rect.size.x, rect.size.y)
	return clampf(notch_size, 4.0, maxf(4.0, shortest * 0.25))


func _effective_border_width() -> float:
	var shortest := minf(size.x, size.y)
	return clampf(border_width, 1.0, maxf(1.0, shortest * 0.08))


func _ornament_stroke_width() -> float:
	var base := maxf(_effective_border_width() * 0.85, _effective_corner_size() * 0.095)
	return clampf(base, 1.6, 3.6)


func _content_padding() -> float:
	if corner_style == STYLE_PLAIN:
		return _effective_notch_size() + _effective_border_width() + 8.0
	return _effective_corner_size() + _effective_border_width() + 12.0
