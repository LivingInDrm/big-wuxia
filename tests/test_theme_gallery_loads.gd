extends SceneTree

func _init() -> void:
	var path := "res://scenes/debug/theme_gallery.tscn"
	var packed := load(path)
	if packed == null:
		push_error("[gallery-check] failed to load %s" % path)
		quit(1)
		return
	if not (packed is PackedScene):
		push_error("[gallery-check] %s is not a PackedScene" % path)
		quit(1)
		return
	var scene := (packed as PackedScene).instantiate()
	if scene == null:
		push_error("[gallery-check] instantiate returned null")
		quit(1)
		return
	print("[gallery-check] OK · root=%s children=%d" % [scene.name, scene.get_child_count()])
	scene.queue_free()
	quit(0)
