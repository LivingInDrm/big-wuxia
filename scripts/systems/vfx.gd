extends RefCounted
class_name VFX


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
	var label := Label.new()
	label.top_level = true
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.global_position = world_pos
	label.modulate = Color(0.5, 1.0, 0.6, 1.0) if is_heal else (
		Color(0.72, 0.72, 0.72, 1.0) if str(amount) == "MISS" else Color(1.0, 0.42, 0.42, 1.0)
	)
	parent.add_child(label)

	var tw := label.create_tween()
	tw.tween_property(label, "global_position:y", world_pos.y - 40.0, 0.8)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tw.finished.connect(label.queue_free, CONNECT_ONE_SHOT)
	return label
