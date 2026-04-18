extends SceneTree
## test_main_menu — S1 主菜单输入事件测试（独立 runner，无需 GUT）
##
## 用法：
##   godot --headless --path . --script tests/test_main_menu.gd
##
## 覆盖场景：
##   T1  按钮节点存在且可 press（StartButton / QuitButton）
##   T2  点击"退出江湖" → SceneManager.quit_game() 被调用（通过拦截 get_tree().quit 捕获）
##   T3  点击"开始游戏" → SceneManager.change_scene_to_file 被调用，目标路径为 CharacterSelect
##       (S1 阶段 CharacterSelect 场景不存在，SceneManager 会 push_warning 并保持原场景，不崩溃)
##
## 退出码：0 = 全部通过，1 = 有失败
##
## 策略说明：
## - 用 Button.emit_signal("pressed") 模拟点击（真实输入事件等价物；gdUnit4/GUT 默认做法）
## - 通过 monkey-patch SceneManager 捕获调用（记录调用参数），而非真正退出引擎

const SCENE_PATH := "res://scenes/main_menu/main_menu.tscn"
const EXPECTED_TARGET_SCENE := "res://scenes/battle/battle.tscn"  # S2 改指向 Battle（原 CharacterSelect 推迟到 S3）

var _pass: int = 0
var _fail: int = 0
var _quit_called: bool = false
var _change_scene_calls: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_main_menu] ==== BEGIN ====")

	# autoload 在 `--script SceneTree` 模式下也会被实例化为 /root/<Name>（见 godot-dev skill）
	var scene_manager: Node = root.get_node_or_null("SceneManager")
	if scene_manager == null:
		_fail_test("Autoload SceneManager 未找到在 /root/SceneManager")
		_finish()
		return

	# Monkey-patch SceneManager 的 script，通过 meta Callable 捕获调用
	scene_manager.set_script(load("res://tests/helpers/scene_manager_spy.gd"))
	scene_manager.set_meta("spy_quit", Callable(self, "_spy_on_quit"))
	scene_manager.set_meta("spy_change_scene", Callable(self, "_spy_on_change_scene"))

	# 加载主菜单场景
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail_test("Load scene failed: %s" % SCENE_PATH)
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# T1: 按钮节点存在
	var start_btn := scene.get_node_or_null("ButtonContainer/StartButton") as Button
	var quit_btn := scene.get_node_or_null("ButtonContainer/QuitButton") as Button
	_assert(start_btn != null, "T1a StartButton 存在")
	_assert(quit_btn != null, "T1b QuitButton 存在")
	_assert(start_btn != null and start_btn.text == "开始游戏", "T1c StartButton 文本为 '开始游戏'")
	_assert(quit_btn != null and quit_btn.text == "退出江湖", "T1d QuitButton 文本为 '退出江湖'")

	# T2: 点"退出江湖" → SceneManager.quit_game() 被调用
	if quit_btn != null:
		_quit_called = false
		quit_btn.pressed.emit()
		await process_frame
		_assert(_quit_called, "T2 点击 QuitButton 触发 SceneManager.quit_game()")

	# T3: 点"开始游戏" → SceneManager.change_scene_to_file(CharacterSelect)
	if start_btn != null:
		_change_scene_calls.clear()
		start_btn.pressed.emit()
		await process_frame
		_assert(_change_scene_calls.size() == 1, "T3a 点击 StartButton 触发 1 次 change_scene_to_file")
		if _change_scene_calls.size() >= 1:
			_assert(_change_scene_calls[0] == EXPECTED_TARGET_SCENE,
				"T3b change_scene_to_file 参数为 %s（实际=%s）" % [EXPECTED_TARGET_SCENE, _change_scene_calls[0]])

	_finish()


func _spy_on_quit() -> void:
	_quit_called = true


func _spy_on_change_scene(path: String) -> void:
	_change_scene_calls.append(path)


func _assert(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] %s" % label)
	else:
		_fail += 1
		push_error("[FAIL] %s" % label)


func _fail_test(msg: String) -> void:
	_fail += 1
	push_error("[FAIL] %s" % msg)


func _finish() -> void:
	print("[test_main_menu] ==== END ==== pass=%d fail=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
