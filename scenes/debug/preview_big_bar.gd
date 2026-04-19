extends Control

@export var base_texture: Texture2D
@export var fill_texture: Texture2D
@export_range(0.0, 100.0, 0.1) var max_value := 100.0
@export_range(0.0, 100.0, 0.1) var value := 70.0:
	set(next_value):
		value = clampf(next_value, 0.0, max_value)
		queue_redraw()

@export var fill_padding_left := 61.0
@export var fill_padding_right := 61.0


func _ready() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if base_texture != null:
		draw_texture_rect(base_texture, Rect2(Vector2.ZERO, size), false)

	if fill_texture == null or max_value <= 0.0:
		return

	var ratio := clampf(value / max_value, 0.0, 1.0)
	if ratio <= 0.0:
		return

	var inner_width := maxf(size.x - fill_padding_left - fill_padding_right, 0.0)
	if inner_width <= 0.0:
		return

	var fill_rect := Rect2(fill_padding_left, 0.0, inner_width * ratio, size.y)
	draw_texture_rect(fill_texture, fill_rect, false)
