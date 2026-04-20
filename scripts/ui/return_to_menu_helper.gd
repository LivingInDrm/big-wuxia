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
	GameState.return_context = {}
	GameState.location = ""
	DialogueSystem.end(false)
	SceneManager.change_scene_to_file(MAIN_MENU_SCENE)
