extends SceneTree

var _steps: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[p5_s2_dialogue_smoke] ==== BEGIN ====")

	var dialogue_system = root.get_node_or_null("DialogueSystem")
	var dialogue_registry = root.get_node_or_null("DialogueRegistry")
	var game_state = root.get_node_or_null("GameState")
	if dialogue_system == null or dialogue_registry == null or game_state == null:
		push_error("[p5_s2_dialogue_smoke] missing autoload(s)")
		quit(1)
		return

	dialogue_registry.reload()
	game_state.reset()
	dialogue_system.char_speed = 1

	if not dialogue_system.start("wudang_hong_first_meet"):
		push_error("[p5_s2_dialogue_smoke] start failed")
		quit(1)
		return

	while dialogue_system.current_node != null and _steps < 8:
		print("[p5_s2_dialogue_smoke] step=%d node=%s" % [_steps, dialogue_system.current_node.node_id])
		dialogue_system.advance()
		await process_frame
		if dialogue_system.current_node != null and dialogue_system.current_node.node_id == "start":
			dialogue_system.select_choice(0)
			await process_frame
		_steps += 1

	print("[p5_s2_dialogue_smoke] finished current_node=%s flag=%s" % [str(dialogue_system.current_node), str(game_state.get_flag("wudang.met_hong", false))])
	dialogue_system.end(false)
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	quit(0 if dialogue_system.current_node == null else 1)
