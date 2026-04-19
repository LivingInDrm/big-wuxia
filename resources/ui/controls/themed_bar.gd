@tool
class_name ThemedBar
extends Range

# Progress bar that reads its base frame, fill texture, padding and tint from
# the UI Theme (via type variations like "bar/hp", "bar/mp", "bar/exp"). The
# padding constants are expressed in *source-image pixels* and scale with the
# control's rendered size so one theme entry works at any bar dimension.

const FILL_PADDING_LEFT := &"fill_padding_left"
const FILL_PADDING_RIGHT := &"fill_padding_right"
const FILL_PADDING_TOP := &"fill_padding_top"
const FILL_PADDING_BOTTOM := &"fill_padding_bottom"
const BASE_ICON := &"base_texture"
const FILL_ICON := &"fill_texture"
const FILL_TINT := &"fill_tint"

@export var base_texture_override: Texture2D = null:
	set(tex):
		base_texture_override = tex
		queue_redraw()
@export var fill_texture_override: Texture2D = null:
	set(tex):
		fill_texture_override = tex
		queue_redraw()
@export var fill_tint_override: Color = Color(0, 0, 0, 0):
	set(c):
		fill_tint_override = c
		queue_redraw()


func _ready() -> void:
	if not value_changed.is_connected(_on_value_changed):
		value_changed.connect(_on_value_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _on_value_changed(_new_value: float) -> void:
	queue_redraw()


func _draw() -> void:
	var base := _resolve_base_texture()
	if base != null:
		draw_texture_rect(base, Rect2(Vector2.ZERO, size), false)

	var fill := _resolve_fill_texture()
	if fill == null:
		return
	var span := max_value - min_value
	if span <= 0.0:
		return
	var ratio := clampf((value - min_value) / span, 0.0, 1.0)
	if ratio <= 0.0:
		return

	var scale_x := 1.0
	var scale_y := 1.0
	if base != null:
		var bw := float(base.get_width())
		var bh := float(base.get_height())
		if bw > 0.0:
			scale_x = size.x / bw
		if bh > 0.0:
			scale_y = size.y / bh

	var pad_l := _resolve_constant(FILL_PADDING_LEFT) * scale_x
	var pad_r := _resolve_constant(FILL_PADDING_RIGHT) * scale_x
	var pad_t := _resolve_constant(FILL_PADDING_TOP) * scale_y
	var pad_b := _resolve_constant(FILL_PADDING_BOTTOM) * scale_y

	var inner_width := maxf(size.x - pad_l - pad_r, 0.0)
	var inner_height := maxf(size.y - pad_t - pad_b, 0.0)
	if inner_width <= 0.0 or inner_height <= 0.0:
		return

	var fill_rect := Rect2(pad_l, pad_t, inner_width * ratio, inner_height)
	draw_texture_rect(fill, fill_rect, false, _resolve_fill_tint())


func _resolve_base_texture() -> Texture2D:
	if base_texture_override != null:
		return base_texture_override
	if has_theme_icon(BASE_ICON):
		return get_theme_icon(BASE_ICON)
	return null


func _resolve_fill_texture() -> Texture2D:
	if fill_texture_override != null:
		return fill_texture_override
	if has_theme_icon(FILL_ICON):
		return get_theme_icon(FILL_ICON)
	return null


func _resolve_fill_tint() -> Color:
	if fill_tint_override.a > 0.0:
		return fill_tint_override
	if has_theme_color(FILL_TINT):
		return get_theme_color(FILL_TINT)
	return Color(1, 1, 1, 1)


func _resolve_constant(name: StringName) -> float:
	if has_theme_constant(name):
		return float(get_theme_constant(name))
	return 0.0
