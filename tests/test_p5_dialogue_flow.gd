extends SceneTree

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_p5_dialogue_flow] ==== BEGIN ====")

	var dialogue_system = root.get_node_or_null("DialogueSystem")
	var dialogue_registry = root.get_node_or_null("DialogueRegistry")
	var game_state = root.get_node_or_null("GameState")

	_assert(dialogue_system != null, "T0a /root/DialogueSystem 存在")
	_assert(dialogue_registry != null, "T0b /root/DialogueRegistry 存在")
	_assert(game_state != null, "T0c /root/GameState 存在")
	if dialogue_system == null or dialogue_registry == null or game_state == null:
		_finish()
		return

	dialogue_registry.reload()
	game_state.reset()
	dialogue_system.char_speed = 1

	var started: bool = dialogue_system.start("wudang_hong_first_meet")
	_assert(started, "T1a start(wudang_hong_first_meet) 成功")
	_assert(dialogue_system.current_node != null, "T1b 能获取第一个节点")
	if dialogue_system.current_node != null:
		_assert(dialogue_system.current_node.node_id == "start", "T1c 当前节点为 start")
	_assert(game_state.get_flag("wudang.met_hong", false) == true, "T1d set_flag on_enter 已执行")

	dialogue_system.advance()
	await process_frame
	_assert(dialogue_system.current_node != null and dialogue_system.current_node.node_id == "start", "T2a 第一次 advance 仅跳过逐字显示")

	dialogue_system.select_choice(0)
	await process_frame
	_assert(dialogue_system.current_node != null and dialogue_system.current_node.node_id == "reply", "T3a select_choice(0) 跳到 reply")

	dialogue_system.end(false)
	await process_frame
	_assert(dialogue_system.current_node == null, "T3b end(false) 清空当前节点")

	game_state.reset()
	dialogue_system.char_speed = 1
	var started_required: bool = dialogue_system.start("tests.p5_required_flags")
	_assert(started_required, "T4a required_flags 测试对话可启动")
	_assert(dialogue_system.current_node != null and dialogue_system.current_node.node_id == "filtered_choice", "T4b required_flags 不满足时跳过节点")

	dialogue_system.advance()
	await process_frame
	dialogue_system.select_choice(0)
	await process_frame
	_assert(dialogue_system.current_node != null and dialogue_system.current_node.node_id == "choice_ok", "T4c 过滤后剩余选项仍可跳转")

	dialogue_system.end(false)
	await process_frame
	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_p5_dialogue_flow] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
