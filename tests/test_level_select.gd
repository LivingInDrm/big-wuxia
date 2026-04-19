extends SceneTree

const SCENE_PATH := "res://scenes/level_select/level_select.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

var _pass: int = 0
var _fail: int = 0
var _change_scene_calls: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_level_select] ==== BEGIN ====")

	var scene_manager := root.get_node_or_null("SceneManager")
	var state := root.get_node_or_null("GameState")
	_assert(scene_manager != null, "T0a /root/SceneManager 存在")
	_assert(state != null, "T0b /root/GameState 存在")
	if scene_manager == null or state == null:
		_finish()
		return

	scene_manager.set_script(load("res://tests/helpers/scene_manager_spy.gd"))
	scene_manager.set_meta("spy_change_scene", Callable(self, "_spy_on_change_scene"))

	var packed := load(SCENE_PATH) as PackedScene
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var levels_container := scene.get_node_or_null("Center/Card/Margin/VBox/LevelsContainer") as VBoxContainer
	var back_button := scene.get_node_or_null("Center/Card/Margin/VBox/BackButton") as Button
	_assert(levels_container != null, "T1a LevelsContainer 存在")
	_assert(back_button != null, "T1b BackButton 存在")
	if levels_container != null:
		_assert(levels_container.get_child_count() == 2, "T1c 共渲染 2 个关卡按钮")
		var level_button := levels_container.get_child(1) as Button
		if level_button != null:
			_change_scene_calls.clear()
			level_button.pressed.emit()
			await process_frame
			_assert(state.current_level == "level_02", "T2a 点击第二关后 current_level=level_02")
			_assert(_change_scene_calls.size() == 1 and _change_scene_calls[0] == BATTLE_SCENE,
				"T2b 点击关卡后切到 Battle")

	if back_button != null:
		_change_scene_calls.clear()
		back_button.pressed.emit()
		await process_frame
		_assert(_change_scene_calls.size() == 1 and _change_scene_calls[0] == MAIN_MENU_SCENE,
			"T3 点击返回后切到 MainMenu")

	_finish()


func _spy_on_change_scene(path: String) -> void:
	_change_scene_calls.append(path)


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_level_select] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
