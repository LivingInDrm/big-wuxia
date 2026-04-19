class_name BattleHUDVM
extends Node
## Battle HUD view-model.
##
## Holds the state that `battle_hud_v2.tscn` renders. Does not touch the scene
## directly; the HUD script (to be added later) is responsible for subscribing
## to these signals and updating nodes.
##
## In real play a `BattleHUDVM` is owned by the BattleController (or HUD root)
## and receives updates via `set_current_unit()` / `set_target_unit()` etc.
##
## In the mock preview scene a `BattleHUDMock` instantiates one VM and pushes
## fake data through the same setters.

signal current_unit_changed(unit)
signal target_changed(unit)
signal turn_changed(team: String, turn_number: int, day: int)
signal damage_preview_changed(hit: int, crit: int, dmg_min: int, dmg_max: int)
signal action_available_changed(available: Dictionary)
signal action_requested(action_name: String)

const ACTIONS := ["move", "attack", "defend", "skill", "end_turn"]

var current_unit: Object = null
var target_unit: Object = null
var current_team: String = "player"
var turn_number: int = 1
var day_number: int = 1
var hit_chance: int = 0
var crit_chance: int = 0
var damage_min: int = 0
var damage_max: int = 0
var available_actions: Dictionary = {
	"move": true,
	"attack": false,
	"defend": false,
	"skill": false,
	"end_turn": true,
}


func set_current_unit(unit: Object) -> void:
	if current_unit == unit:
		return
	current_unit = unit
	current_unit_changed.emit(unit)


func set_target_unit(unit: Object) -> void:
	if target_unit == unit:
		return
	target_unit = unit
	target_changed.emit(unit)


func set_turn(team: String, turn_number_value: int, day: int = -1) -> void:
	current_team = team
	turn_number = turn_number_value
	if day > 0:
		day_number = day
	turn_changed.emit(current_team, turn_number, day_number)


func set_damage_preview(hit: int, crit: int, dmg_min: int, dmg_max: int) -> void:
	hit_chance = hit
	crit_chance = crit
	damage_min = dmg_min
	damage_max = dmg_max
	damage_preview_changed.emit(hit_chance, crit_chance, damage_min, damage_max)


func set_action_availability(dict: Dictionary) -> void:
	for key in dict.keys():
		available_actions[key] = bool(dict[key])
	action_available_changed.emit(available_actions.duplicate(true))


func emit_action(action_name: String) -> void:
	if action_name not in ACTIONS:
		push_warning("BattleHUDVM: unknown action '%s'" % action_name)
		return
	action_requested.emit(action_name)


func mock_tick() -> void:
	# Fires a representative burst of signals so listeners can verify wiring.
	current_unit_changed.emit(current_unit)
	target_changed.emit(target_unit)
	turn_changed.emit(current_team, turn_number, day_number)
	damage_preview_changed.emit(hit_chance, crit_chance, damage_min, damage_max)
	action_available_changed.emit(available_actions.duplicate(true))
