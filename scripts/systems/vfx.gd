extends RefCounted
class_name VFX

const DAMAGE_NUMBER_FONT_SIZE := 28
const DAMAGE_NUMBER_OUTLINE := 2
const DAMAGE_NUMBER_TRAVEL := 60.0
const DAMAGE_NUMBER_DURATION := 0.8


static func spawn_at(parent: Node, sprite_frames: SpriteFrames, world_pos: Vector2,
		scale: float = 1.0) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sprite_frames
	sprite.animation = &"default"
	sprite.global_position = world_pos
	sprite.scale = Vector2.ONE * scale
	parent.add_child(sprite)
	sprite.play()
	if not sprite_frames.get_animation_loop(&"default"):
		sprite.animation_finished.connect(sprite.queue_free, CONNECT_ONE_SHOT)
	return sprite


static func spawn_damage_number(parent: Node, world_pos: Vector2, amount: Variant,
		is_heal: bool = false) -> Label:
	var viewport := parent.get_viewport()
	var tree := parent.get_tree()
	var screen_pos: Vector2 = viewport.get_canvas_transform() * world_pos
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	tree.root.add_child(overlay)

	var label := Label.new()
	label.text = _format_damage_text(amount, is_heal)
	label.position = screen_pos + Vector2(-72, -36)
	label.size = Vector2(144, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 100
	label.add_theme_font_size_override("font_size", DAMAGE_NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", DAMAGE_NUMBER_OUTLINE)
	label.modulate = Color(0.3, 1.0, 0.3, 1.0) if is_heal else (
		Color(0.7, 0.7, 0.7, 1.0) if str(amount) == "MISS" else Color(1.0, 0.2, 0.2, 1.0)
	)
	overlay.add_child(label)

	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - DAMAGE_NUMBER_TRAVEL, DAMAGE_NUMBER_DURATION)
	tw.parallel().tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_DURATION)
	tw.finished.connect(overlay.queue_free, CONNECT_ONE_SHOT)
	return label


static func _format_damage_text(amount: Variant, is_heal: bool) -> String:
	if str(amount) == "MISS":
		return "MISS"
	var value := int(amount)
	if is_heal:
		return "+%d" % value
	return "-%d" % value
