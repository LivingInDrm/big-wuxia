extends SceneTree

const HUD_SCENE := preload("res://scenes/battle/battle_hud_v3.tscn")
const HUD_MOCK := preload("res://scripts/ui/battle_hud_v3_mock.gd")
const OUT_DIR := "tools/screenshots"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1366, 768))

	var states := [
		{
			"name": "hud_v3_action_menu_clean.png",
			"submenu": &"",
			"entries": [],
			"scroll": 0,
		},
		{
			"name": "hud_v3_martial_replaces_menu.png",
			"submenu": &"skill",
			"entries": _skill_entries(2),
			"scroll": 0,
		},
		{
			"name": "hud_v3_martial_scroll.png",
			"submenu": &"skill",
			"entries": _skill_entries(6),
			"scroll": 0,
		},
	]

	for state in states:
		await _capture_state(state)

	print("[battle_hud_v3_ui_shots] saved 3 screenshots")
	quit(0)


func _capture_state(state: Dictionary) -> void:
	var scene := Control.new()
	scene.name = "BattleHUDV3Shot"
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#1D1712")
	scene.add_child(background)

	var hud := HUD_SCENE.instantiate()
	scene.add_child(hud)
	hud.apply_mock(HUD_MOCK.mock_state())
	hud.set_action_menu_visible(true)
	hud.set_character_card_visible(true, false)

	var submenu_kind: StringName = state.get("submenu", &"")
	var entries: Array[Dictionary] = []
	for entry in state.get("entries", []):
		entries.append(entry)
	if submenu_kind == &"skill":
		hud.set_skill_entries(entries)
		hud.show_skill_panel()
	elif submenu_kind == &"item":
		hud.set_item_entries(entries)
		hud.show_item_panel()
	else:
		hud.hide_submenu()

	await process_frame
	await process_frame

	if submenu_kind != &"":
		hud._submenu_scroll.scroll_vertical = int(state.get("scroll", 0))
		await process_frame

	var out_path := "%s/%s" % [OUT_DIR, String(state.get("name", "shot.png"))]
	var abs_path := ProjectSettings.globalize_path("res://%s" % out_path)
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("[battle_hud_v3_ui_shots] save_png failed err=%s out=%s" % [err, abs_path])
		quit(1)
		return
	print("[battle_hud_v3_ui_shots] saved %s" % abs_path)

	scene.queue_free()
	await process_frame
	await process_frame


func _skill_entries(count: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in count:
		entries.append({
			"type": &"skill",
			"index": i,
			"label": "武功 %d" % [i + 1],
			"key": str(i + 1),
			"detail": "用于截图验证滚动容器",
		})
	return entries
