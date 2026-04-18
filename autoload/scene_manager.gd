extends Node
## SceneManager — 场景切换管理器（Autoload）
##
## 职责：统一管理场景切换（带可选淡入淡出动画）。
## 依赖：无。
## 参考：docs/design/02-architecture.md §3.3
##
## S1 说明：S1 阶段只需提供切场景接口，主菜单 "开始游戏" 按钮暂时不接后续场景
## （CharacterSelect 场景 S6 才实现），仅在 main_menu.gd 里留 TODO 注释。

var _loading: bool = false


func change_scene_to_file(path: String) -> void:
	if _loading:
		return
	if not ResourceLoader.exists(path):
		push_warning("[SceneManager] Target scene does not exist yet: %s" % path)
		return
	_loading = true

	var tree := get_tree()
	var fade_layer := CanvasLayer.new()
	var fade_rect := ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
	tree.root.add_child(fade_layer)

	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.25)
	await tween_out.finished

	tree.change_scene_to_file(path)
	await tree.process_frame

	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.25)
	await tween_in.finished

	fade_layer.queue_free()
	_loading = false


func reload_current_scene() -> void:
	var tree := get_tree()
	if tree.current_scene and tree.current_scene.scene_file_path != "":
		change_scene_to_file(tree.current_scene.scene_file_path)


## 统一的退出入口，方便单元测试 mock（直接调 get_tree().quit() 也可）。
func quit_game() -> void:
	get_tree().quit()
