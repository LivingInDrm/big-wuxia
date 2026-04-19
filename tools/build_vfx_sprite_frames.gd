extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_build_single_sheet(
		"res://resources/sprites/vfx/dust/Dust_01.png",
		"res://resources/sprites/vfx/dust.tres",
		Vector2i(64, 64),
		8,
		15.0,
		false
	)
	_build_multi_sheet(
		[
			"res://resources/sprites/vfx/fire/Fire_01.png",
			"res://resources/sprites/vfx/fire/Fire_02.png",
			"res://resources/sprites/vfx/fire/Fire_03.png",
		],
		"res://resources/sprites/vfx/fire.tres",
		Vector2i(64, 64),
		[8, 10, 12],
		12.0,
		true
	)
	_build_single_sheet(
		"res://resources/sprites/vfx/explosion/Explosion_01.png",
		"res://resources/sprites/vfx/explosion.tres",
		Vector2i(192, 192),
		8,
		15.0,
		false
	)
	_build_single_sheet(
		"res://resources/sprites/vfx/heal/Heal_Effect.png",
		"res://resources/sprites/vfx/heal.tres",
		Vector2i(192, 192),
		11,
		10.0,
		false
	)
	quit()


func _build_single_sheet(texture_path: String, out_path: String, frame_size: Vector2i,
		frame_count: int, fps: float, loop: bool) -> void:
	_build_multi_sheet([texture_path], out_path, frame_size, [frame_count], fps, loop)


func _build_multi_sheet(texture_paths: Array[String], out_path: String, frame_size: Vector2i,
		frame_counts: Array[int], fps: float, loop: bool) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", loop)

	for i in texture_paths.size():
		var image := Image.load_from_file(ProjectSettings.globalize_path(texture_paths[i]))
		if image == null:
			push_error("Missing texture: %s" % texture_paths[i])
			continue
		var texture := ImageTexture.create_from_image(image)
		for frame_idx in frame_counts[i]:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame_idx * frame_size.x, 0, frame_size.x, frame_size.y)
			frames.add_frame("default", atlas)

	var err := ResourceSaver.save(frames, out_path)
	if err != OK:
		push_error("Failed to save SpriteFrames: %s err=%d" % [out_path, err])
