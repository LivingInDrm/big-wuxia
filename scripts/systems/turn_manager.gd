extends Node
class_name TurnManager
## TurnManager —— 回合状态机（Sprint 3 简化版）
##
## 职责：维护 current_turn / current_phase，提供玩家↔敌方阶段切换 + 进入下一回合 的 API。
##
## S3 简化：整体 phase 切换，不按单位队列调度（S4/S5 再升级到 02-architecture §7.2 的队列模型）。
##
## Phase 状态：
##   PLAYER_SELECT → PLAYER_MOVE → PLAYER_ACTION → ENEMY_TURN → (下一回合) PLAYER_SELECT
##
## S3 只对外暴露：
##   start_battle()          —— 初始化到第 1 回合 / PLAYER_SELECT
##   _start_player_phase()   —— phase=PLAYER_SELECT，emit phase_changed
##   _start_enemy_phase()    —— phase=ENEMY_TURN，emit phase_changed
##   _next_turn()            —— current_turn += 1，phase=PLAYER_SELECT，emit turn_started + phase_changed
##
## 玩家单位内 MOVE/ACTION 子状态的切换在 S4 由 BattleController 驱动。

enum Phase {
	PLAYER_SELECT,
	PLAYER_MOVE,
	PLAYER_ACTION,
	ENEMY_TURN,
}

var current_turn: int = 1
var current_phase: Phase = Phase.PLAYER_SELECT

signal turn_started(turn_num: int)
signal phase_changed(phase: Phase)


## 战斗开始：回合 1 / 玩家阶段。Controller 在 _ready 末尾调用。
func start_battle() -> void:
	current_turn = 1
	current_phase = Phase.PLAYER_SELECT
	turn_started.emit(current_turn)
	phase_changed.emit(current_phase)


func _start_player_phase() -> void:
	current_phase = Phase.PLAYER_SELECT
	phase_changed.emit(current_phase)


func _start_enemy_phase() -> void:
	current_phase = Phase.ENEMY_TURN
	phase_changed.emit(current_phase)


func _next_turn() -> void:
	current_turn += 1
	current_phase = Phase.PLAYER_SELECT
	turn_started.emit(current_turn)
	phase_changed.emit(current_phase)


## UI 辅助：phase 的中文名称
static func phase_label(phase: Phase) -> String:
	match phase:
		Phase.PLAYER_SELECT: return "玩家阶段"
		Phase.PLAYER_MOVE:   return "移动中"
		Phase.PLAYER_ACTION: return "选择行动"
		Phase.ENEMY_TURN:    return "敌方阶段"
		_: return "未知"
