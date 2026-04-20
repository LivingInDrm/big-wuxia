class_name ReturnToMenuHelper
extends RefCounted

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const DIALOG_SCENE := preload("res://scenes/ui/return_to_menu_dialog.tscn")


static func request(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var dialog := _ensure_dialog(tree)
	if dialog == null:
		return false
	dialog.open()
	return true


static func is_open(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var dialog := tree.root.get_node_or_null("ReturnToMenuDialog")
	return dialog != null and dialog.visible


static func _ensure_dialog(tree: SceneTree) -> CanvasLayer:
	var existing := tree.root.get_node_or_null("ReturnToMenuDialog") as CanvasLayer
	if existing != null:
		return existing
	var dialog := DIALOG_SCENE.instantiate() as CanvasLayer
	tree.root.add_child(dialog)
	dialog.confirmed.connect(_on_confirmed.bind(dialog))
	return dialog


static func _on_confirmed(dialog: CanvasLayer) -> void:
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var game_state := tree.root.get_node_or_null("GameState")
	if game_state != null:
		game_state.return_context = {}
		game_state.location = ""
	var dialogue_system := tree.root.get_node_or_null("DialogueSystem")
	if dialogue_system != null:
		dialogue_system.end(false)
	var scene_manager := tree.root.get_node_or_null("SceneManager")
	if scene_manager != null:
		scene_manager.change_scene_to_file(MAIN_MENU_SCENE)
