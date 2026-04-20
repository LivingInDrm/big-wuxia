extends SceneTree

const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"
const VALIDATE_SCRIPT := "res://tools/validate_dialogues.gd"

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_p5_polish] ==== BEGIN ====")
	await _test_char_speed_zero_is_instant()
	await _test_overworld_escape_opens_confirm()
	await _test_poi_name_label_distance_visibility()
	_test_validate_dialogues_returns_clean()
	_finish()


func _test_char_speed_zero_is_instant() -> void:
	var dialogue_system = root.get_node_or_null("DialogueSystem")
	var dialogue_registry = root.get_node_or_null("DialogueRegistry")
	var game_state = root.get_node_or_null("GameState")
	_assert(dialogue_system != null, "T1a /root/DialogueSystem 存在")
	_assert(dialogue_registry != null, "T1b /root/DialogueRegistry 存在")
	_assert(game_state != null, "T1c /root/GameState 存在")
	if dialogue_system == null or dialogue_registry == null or game_state == null:
		return

	dialogue_registry.reload()
	game_state.reset()
	dialogue_system.char_speed = 0
	dialogue_system.instant_mode = false
	var started: bool = dialogue_system.start("wudang.hong_first_meet")
	await process_frame
	_assert(started, "T1d char_speed=0 时对话仍可启动")
	_assert(dialogue_system.current_node != null, "T1e char_speed=0 有当前节点")
	_assert(dialogue_system._text_fully_visible == true, "T1f char_speed=0 等同 instant，首节点直接全显")
	dialogue_system.end(false)
	await process_frame


func _test_overworld_escape_opens_confirm() -> void:
	_cleanup_return_dialog()
	var packed := load(OVERWORLD_SCENE) as PackedScene
	_assert(packed != null, "T2a overworld 场景可加载")
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var esc_event := InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_event.pressed = true
	scene._unhandled_input(esc_event)
	await process_frame

	var dialog := root.get_node_or_null("ReturnToMenuDialog")
	_assert(dialog != null, "T2b overworld ESC 会实例化确认框")
	_assert(dialog != null and dialog.visible, "T2c overworld ESC 会显示确认框")

	root.remove_child(scene)
	scene.queue_free()
	_cleanup_return_dialog()
	await process_frame


func _test_poi_name_label_distance_visibility() -> void:
	var packed := load(OVERWORLD_SCENE) as PackedScene
	_assert(packed != null, "T3a overworld 场景可加载")
	if packed == null:
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player := scene.get_node("Player") as Node2D
	var marker := scene.get_node("POINodes/POI_Wudang") as Node2D
	var label := scene.get_node("UILayer/PoiNameLabel") as Label
	player.global_position = marker.global_position + Vector2(120.0, 0.0)
	scene._process(0.2)
	await process_frame
	_assert(label.visible, "T3b 距离 < 150 时 PoiNameLabel 可见")
	_assert(label.text == "武当山", "T3c PoiNameLabel 显示最近 POI 名")

	player.global_position = marker.global_position + Vector2(220.0, 0.0)
	scene._process(0.2)
	await process_frame
	_assert(label.visible == false, "T3d 距离 >= 150 时 PoiNameLabel 隐藏")

	root.remove_child(scene)
	scene.queue_free()
	await process_frame


func _test_validate_dialogues_returns_clean() -> void:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			VALIDATE_SCRIPT,
		],
		output,
		true
	)
	var joined_output := "\n".join(PackedStringArray(output))
	_assert(exit_code == 0, "T4a validate_dialogues 返回码为 0")
	_assert(joined_output.contains("0 errors 0 warnings"), "T4b validate_dialogues 输出 0 errors 0 warnings")


func _cleanup_return_dialog() -> void:
	var dialog := root.get_node_or_null("ReturnToMenuDialog")
	if dialog != null:
		dialog.queue_free()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_p5_polish] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
