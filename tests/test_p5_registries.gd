extends SceneTree

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_p5_registries] ==== BEGIN ====")

	var poi_registry = root.get_node_or_null("POIRegistry")
	var npc_registry = root.get_node_or_null("NPCRegistry")
	var dialogue_registry = root.get_node_or_null("DialogueRegistry")
	var game_state = root.get_node_or_null("GameState")

	_assert(poi_registry != null, "T0a /root/POIRegistry 存在")
	_assert(npc_registry != null, "T0b /root/NPCRegistry 存在")
	_assert(dialogue_registry != null, "T0c /root/DialogueRegistry 存在")
	_assert(game_state != null, "T0d /root/GameState 存在")
	if poi_registry == null or npc_registry == null or dialogue_registry == null or game_state == null:
		_finish()
		return

	poi_registry.reload()
	npc_registry.reload()
	dialogue_registry.reload()

	var wudang = poi_registry.get_data("wudang")
	var hong = npc_registry.get_data("hong_xixiang")
	var dialogue = dialogue_registry.get_data("wudang.hong_first_meet")

	_assert(wudang != null, "T1a POIRegistry 可取到 wudang")
	_assert(hong != null, "T1b NPCRegistry 可取到 hong_xixiang")
	_assert(dialogue != null, "T1c DialogueRegistry 可取到 wudang.hong_first_meet")
	_assert("wudang.hong_first_meet" in dialogue_registry.all_ids(), "T1d DialogueRegistry 递归 all_ids 包含样例对话")
	if wudang != null:
		_assert(wudang.display_name == "武当山", "T1e wudang.display_name 正确")
	if hong != null:
		_assert(hong.default_dialogue_id == "wudang.hong_first_meet", "T1f hong_xixiang 默认对话正确")
	if dialogue != null:
		_assert(dialogue.nodes.size() == 2, "T1g 样例对话节点数=2")

	game_state.reset()
	game_state.set_flag("test.x", true)
	_assert(game_state.get_flag("test.x") == true, "T2a set_flag/get_flag 闭环")
	_assert(game_state.has_flag("test.x"), "T2b has_flag 可见 test.x")
	game_state.clear_flag("test.x")
	_assert(not game_state.has_flag("test.x"), "T2c clear_flag 后 has_flag=false")
	_assert(game_state.get_flag("test.x", "fallback") == "fallback", "T2d get_flag 默认值生效")

	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_p5_registries] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
