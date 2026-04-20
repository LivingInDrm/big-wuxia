extends Control
## MainMenu — 主菜单场景
##
## 职责：显示游戏标题 + 开始游戏 / 退出 按钮。
## 依赖：Autoload SceneManager（切场景）/ GameState（重置）。
## 参考：docs/design/06-sprint-plan.md §Sprint 1 / §Sprint 2
##
## S2 变更：
##   "开始游戏"目标由 CharacterSelect（尚未实现）改为 Battle（S2 已实现）。
##   CharacterSelect 会在 S3 引入 Unit 后加回来，届时再插回菜单链路。

const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select/level_select.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_panel.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_menu.tscn"

@onready var start_button: Button = %StartButton
@onready var debug_level_select_button: Button = %DebugLevelSelectButton
@onready var inventory_button: Button = %InventoryButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	debug_level_select_button.pressed.connect(_on_debug_level_select_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	GameState.reset()
	SceneManager.change_scene_to_file(OVERWORLD_SCENE)


func _on_debug_level_select_pressed() -> void:
	SceneManager.change_scene_to_file(LEVEL_SELECT_SCENE)


func _on_inventory_pressed() -> void:
	SceneManager.change_scene_to_file(INVENTORY_SCENE)


func _on_settings_pressed() -> void:
	SceneManager.change_scene_to_file(SETTINGS_SCENE)


func _on_quit_pressed() -> void:
	SceneManager.quit_game()
