@tool
class_name SimpleBar
extends Control

const DEFAULT_BG := Color("0F0C08")
const DEFAULT_BORDER := Color("7A5A28")
const ARC_SEGMENTS := 6

@export var min_value: float = 0.0:
	set(new_value):
		min_value = new_value
		if max_value < min_value:
			max_value = min_value
		value = clampf(value, min_value, max_value)
		queue_redraw()

@export var max_value: float = 100.0:
	set(new_value):
		max_value = maxf(new_value, min_value)
		value = clampf(value, min_value, max_value)
		queue_redraw()

@export var value: float = 0.0:
	set(new_value):
		value = clampf(new_value, min_value, max_value)
		queue_redraw()

@export var bg_color: Color = DEFAULT_BG:
	set(new_value):
		bg_color = new_value
		queue_redraw()

@export var fill_color: Color = Color("B8883F"):
	set(new_value):
		fill_color = new_value
		queue_redraw()

@export var border_color: Color = DEFAULT_BORDER:
	set(new_value):
		border_color = new_value
		queue_redraw()

@export var border_width: float = 1.0:
	set(new_value):
		border_width = maxf(new_value, 0.0)
		queue_redraw()

@export var corner_radius: float = 0.0:
	set(new_value):
		corner_radius = maxf(new_value, 0.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-0.5)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return

	var radius := _effective_radius(rect)
	_draw_shape(rect, radius, bg_color)

	var ratio := _fill_ratio()
	if ratio > 0.0:
		var fill_width := rect.size.x * ratio
		var fill_rect := Rect2(rect.position, Vector2(fill_width, rect.size.y))
		if fill_rect.size.x > 0.0:
			_draw_shape(fill_rect, minf(radius, fill_rect.size.x * 0.5), fill_color)

	if border_width > 0.0:
		var stroke_points := _build_shape_points(rect, radius)
		if not stroke_points.is_empty():
			stroke_points.append(stroke_points[0])
			draw_polyline(stroke_points, border_color, border_width, true)


func _fill_ratio() -> float:
	var span := max_value - min_value
	if span <= 0.0:
		return 0.0
	return clampf((value - min_value) / span, 0.0, 1.0)


func _effective_radius(rect: Rect2) -> float:
	if corner_radius <= 0.0:
		return 0.0
	return clampf(corner_radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)


func _draw_shape(rect: Rect2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		draw_rect(rect, color, true)
		return
	var points := _build_shape_points(rect, radius)
	if points.size() >= 3:
		draw_colored_polygon(points, color)


func _build_shape_points(rect: Rect2, radius: float) -> PackedVector2Array:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return PackedVector2Array()
	if radius <= 0.0:
		return PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])

	var clamped_radius := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	var points := PackedVector2Array()
	points.append_array(_arc_points(Vector2(rect.end.x - clamped_radius, rect.position.y + clamped_radius), clamped_radius, -PI * 0.5, 0.0))
	points.append_array(_arc_points(Vector2(rect.end.x - clamped_radius, rect.end.y - clamped_radius), clamped_radius, 0.0, PI * 0.5))
	points.append_array(_arc_points(Vector2(rect.position.x + clamped_radius, rect.end.y - clamped_radius), clamped_radius, PI * 0.5, PI))
	points.append_array(_arc_points(Vector2(rect.position.x + clamped_radius, rect.position.y + clamped_radius), clamped_radius, PI, PI * 1.5))
	return points


func _arc_points(center: Vector2, radius: float, start_angle: float, end_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(ARC_SEGMENTS + 1):
		var t := float(i) / float(ARC_SEGMENTS)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
