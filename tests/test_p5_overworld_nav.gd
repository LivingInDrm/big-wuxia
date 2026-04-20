extends SceneTree

const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"

var _pass: int = 0
var _fail: int = 0
var _change_scene_calls: Array[String] = []
var _entered_poi_id: String = ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_p5_overworld_nav] ==== BEGIN ====")

	var scene_manager: Node = root.get_node_or_null("SceneManager")
	var game_state: Node = root.get_node_or_null("GameState")
	var poi_registry: Node = root.get_node_or_null("POIRegistry")
	var npc_registry: Node = root.get_node_or_null("NPCRegistry")
	var dialogue_registry: Node = root.get_node_or_null("DialogueRegistry")
	_assert(scene_manager != null, "T0a /root/SceneManager 存在")
	_assert(game_state != null, "T0b /root/GameState 存在")
	_assert(poi_registry != null, "T0c /root/POIRegistry 存在")
	_assert(npc_registry != null, "T0d /root/NPCRegistry 存在")
	_assert(dialogue_registry != null, "T0e /root/DialogueRegistry 存在")
	if scene_manager == null or game_state == null or poi_registry == null or npc_registry == null or dialogue_registry == null:
		_finish()
		return

	scene_manager.set_script(load("res://tests/helpers/scene_manager_spy.gd"))
	scene_manager.set_meta("spy_change_scene", Callable(self, "_spy_on_change_scene"))

	game_state.reset()
	poi_registry.reload()
	npc_registry.reload()
	dialogue_registry.reload()

	var packed := load(OVERWORLD_SCENE) as PackedScene
	_assert(packed != null, "T1a overworld 场景可加载")
	if packed == null:
		_finish()
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var qingliang_marker := scene.get_node("POINodes/POI_Qingliang")
	_assert(qingliang_marker.visible == false, "T1b qingliang 初始隐藏")

	var wudang_marker := scene.get_node("POINodes/POI_Wudang")
	_entered_poi_id = ""
	wudang_marker.player_entered.connect(func(poi_id: String) -> void:
		_entered_poi_id = poi_id
	)

	var player_area := scene.get_node("Player/PlayerInteractionArea") as Area2D
	wudang_marker._on_area_entered(player_area)
	await process_frame
	_assert(_entered_poi_id == "wudang", "T2a 模拟进入 wudang 范围会发 player_entered")

	var e_event := InputEventKey.new()
	e_event.keycode = KEY_E
	e_event.pressed = true
	scene._unhandled_input(e_event)
	await process_frame
	_assert(_change_scene_calls.size() == 1, "T2b 按 E 触发 1 次切场")
	if _change_scene_calls.size() >= 1:
		_assert(_change_scene_calls[0] == "res://scenes/overworld/poi_map_wudang.tscn", "T2c 切到 wudang POI")
	_assert(game_state.overworld_player_position == scene.get_node("Player").global_position, "T2d 进入 POI 前保存 overworld_player_position")

	root.remove_child(scene)
	scene.queue_free()
	await process_frame

	game_state.set_flag("qingliang.unlocked", true)
	var scene_reloaded := packed.instantiate()
	root.add_child(scene_reloaded)
	await process_frame
	await process_frame
	var qingliang_visible: bool = scene_reloaded.get_node("POINodes/POI_Qingliang").visible
	_assert(qingliang_visible == true, "T3a 解锁 flag 后 qingliang 可见")

	game_state.overworld_player_position = Vector2(777, 333)
	root.remove_child(scene_reloaded)
	scene_reloaded.queue_free()
	await process_frame

	var scene_restored := packed.instantiate()
	root.add_child(scene_restored)
	await process_frame
	await process_frame
	var restored_position: Vector2 = scene_restored.get_node("Player").global_position
	_assert(restored_position == Vector2(777, 333), "T3b overworld_player_position 可恢复")

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
	print("[test_p5_overworld_nav] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
