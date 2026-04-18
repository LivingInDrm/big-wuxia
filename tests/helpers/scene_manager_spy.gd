extends Node
## SceneManagerSpy — 测试专用，替换 SceneManager autoload 的 script
##
## 通过 set_meta("spy_quit", Callable) / set_meta("spy_change_scene", Callable)
## 把调用转发出去，不会真的退出引擎或切场景。
##
## 仅在 tests/ 下被 test_main_menu.gd 手动注入使用；**不在生产代码中引用**。

var _loading: bool = false


func change_scene_to_file(path: String) -> void:
	var cb: Callable = get_meta("spy_change_scene", Callable())
	if cb.is_valid():
		cb.call(path)


func reload_current_scene() -> void:
	pass


func quit_game() -> void:
	var cb: Callable = get_meta("spy_quit", Callable())
	if cb.is_valid():
		cb.call()
