extends SceneTree

const INVENTORY_PANEL_SCENE = preload("res://scenes/inventory/inventory_panel.tscn")
const INVENTORY_SCRIPT = preload("res://scripts/core/inventory.gd")

const OUTPUT_DIR := "res://tools/screenshots"
const VIEWPORT_SIZE := Vector2i(1366, 768)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)

	await _capture_state(
		"p2_inventory_empty.png",
		_create_inventory([]),
		0
	)
	await _capture_state(
		"p2_inventory_consumables.png",
		_create_inventory([
			["jinchuang_yao", 3],
			["jiedu_dan", 2],
			["neili_dan", 1],
		]),
		0
	)
	await _capture_state(
		"p2_inventory_equipment.png",
		_create_inventory([
			["iron_blade", 2],
			["leather_armor", 1],
			["jade_pendant", 1],
		]),
		1
	)

	quit()


func _create_inventory(entries: Array) -> Object:
	var inventory = INVENTORY_SCRIPT.new()
	for entry in entries:
		inventory.add(String(entry[0]), int(entry[1]))
	return inventory


func _capture_state(file_name: String, inventory, category_index: int) -> void:
	var panel = INVENTORY_PANEL_SCENE.instantiate()
	panel.set_inventory_source(inventory)
	panel.start_category = category_index
	root.add_child(panel)

	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var err := image.save_png(abs_path)
	if err != OK:
		push_error("[p2_inventory_screenshots] save_png failed %s err=%s" % [abs_path, err])
		quit(1)
		return

	print("[p2_inventory_screenshots] saved %s" % abs_path)
	panel.queue_free()
	await process_frame
