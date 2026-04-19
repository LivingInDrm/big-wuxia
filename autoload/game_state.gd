extends Node
## GameState — 游戏全局状态（Autoload）
##
## 职责：管理当前关卡、角色选择、通关进度。
## 依赖：无。
## 参考：docs/design/02-architecture.md §3.1

const Inventory = preload("res://scripts/core/inventory.gd")

signal level_completed(level_name: String)

var current_level: String = ""
var selected_characters: Array[String] = []
var completed_levels: Array[String] = []
var inventory: Inventory = Inventory.new()


func start_level(level_name: String) -> void:
	current_level = level_name


func complete_level(level_name: String) -> void:
	if level_name not in completed_levels:
		completed_levels.append(level_name)
	level_completed.emit(level_name)


func is_level_completed(level_name: String) -> bool:
	return level_name in completed_levels


func reset() -> void:
	current_level = ""
	selected_characters = []
	completed_levels = []
	inventory = Inventory.new()
