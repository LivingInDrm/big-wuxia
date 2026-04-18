extends Control
## MainMenu — 主菜单场景
##
## 职责：显示游戏标题 + 开始游戏 / 退出 按钮。
## 依赖：Autoload SceneManager（切场景）/ GameState（重置）。
## 参考：docs/design/06-sprint-plan.md §Sprint 1
##
## S1 约定：S2 起才有 CharacterSelect 场景；此阶段点击"开始游戏"会 push_warning
## 并保持在主菜单，不崩溃。

const CHARACTER_SELECT_SCENE := "res://scenes/character_select/character_select.tscn"

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	# S1 阶段：CharacterSelect 场景尚未存在，SceneManager 会 push_warning 并保持在主菜单
	GameState.reset()
	SceneManager.change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_quit_pressed() -> void:
	SceneManager.quit_game()
