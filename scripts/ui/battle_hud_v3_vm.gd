class_name BattleHUDV3VM
extends Node

const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")

const DEFAULT_PORTRAIT := "res://resources/ui/portraits/half/li_chungang.png"
const PORTRAIT_DIR := "res://resources/ui/portraits/half/"
const LEVEL_DEFAULT := 1
const LEVEL_MAX_DEFAULT := 100
const EXP_DEFAULT := 0
const EXP_MAX_DEFAULT := 1

var turn: int = 1
var char_name: String = "李淳罡"
var portrait_path: String = DEFAULT_PORTRAIT
var exp: int = EXP_DEFAULT
var exp_max: int = EXP_MAX_DEFAULT
var level: int = LEVEL_DEFAULT
var level_max: int = LEVEL_MAX_DEFAULT
var hp: int = 0
var hp_max: int = 1
var mp: int = 0
var mp_max: int = 1
var qinggong: int = 0
var buffs: Array[Dictionary] = []

var current_unit: Node = null
var current_controller: Node = null
var _warned_progress_ids: Dictionary = {}


func refresh(unit: Node, controller: Node) -> void:
	current_unit = unit
	current_controller = controller

	turn = _resolve_turn(controller)
	char_name = _resolve_char_name(unit)
	portrait_path = _resolve_portrait_path(unit)
	exp = EXP_DEFAULT
	exp_max = EXP_MAX_DEFAULT
	level = LEVEL_DEFAULT
	level_max = LEVEL_MAX_DEFAULT
	hp = 0
	hp_max = 1
	mp = 0
	mp_max = 1
	qinggong = 0
	buffs.clear()

	if unit == null:
		return

	hp = int(unit.get("current_hp"))
	hp_max = max(int(unit.get("max_hp")), 1)
	mp = int(unit.get("current_mp"))
	mp_max = max(int(unit.get("max_mp")), 1)
	qinggong = _resolve_qinggong(unit)
	buffs = _resolve_buffs(unit)
	_warn_missing_progress(unit)


func _resolve_turn(controller: Node) -> int:
	if controller == null:
		push_warning("[BattleHUDV3VM] missing BattleController, using turn=1")
		return 1
	var tm: Object = controller.get("turn_manager")
	if tm == null:
		push_warning("[BattleHUDV3VM] missing turn_manager, using turn=1")
		return 1
	return max(int(tm.get("current_turn")), 1)


func _resolve_char_name(unit: Node) -> String:
	if unit == null:
		return "未选择"
	var unit_data: Object = unit.get("unit_data")
	if unit_data != null:
		var unit_name := String(unit_data.get("unit_name"))
		if not unit_name.is_empty():
			return unit_name
	var fallback_name := String(unit.get("display_name"))
	if not fallback_name.is_empty():
		return fallback_name
	push_warning("[BattleHUDV3VM] missing unit name, using placeholder")
	return "未知角色"


func _resolve_portrait_path(unit: Node) -> String:
	if unit == null:
		return DEFAULT_PORTRAIT
	var unit_data: Object = unit.get("unit_data")
	var char_id := ""
	var display_name := ""
	if unit_data != null:
		char_id = String(unit_data.get("unit_id"))
		display_name = String(unit_data.get("unit_name"))
	if char_id.is_empty():
		char_id = String(unit.get("character_id"))
	if char_id.is_empty():
		char_id = _map_display_name_to_id(display_name)
	if char_id.is_empty():
		push_warning("[BattleHUDV3VM] missing character_id/display_name for portrait, using default")
		return DEFAULT_PORTRAIT
	var candidate := "%s%s.png" % [PORTRAIT_DIR, char_id]
	if ResourceLoader.exists(candidate):
		return candidate
	push_warning("[BattleHUDV3VM] portrait not found for '%s', using default" % char_id)
	return DEFAULT_PORTRAIT


func _resolve_qinggong(unit: Node) -> int:
	if unit == null:
		return 0
	return int(AttributeResolver.get_qinggong(unit).get("total", 0))


func _resolve_buffs(unit: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if unit == null:
		return result
	var effects = unit.get("status_effects")
	if effects is Array:
		for effect in effects:
			if effect == null:
				continue
			var turns := int(effect.get("remaining_turns"))
			var label := String(effect.get("source"))
			if label.is_empty():
				label = "状态"
			if turns > 0:
				label = "%s %dT" % [label, turns]
			result.append({
				"icon": "●",
				"icon_color": Color("#D68B2A"),
				"text": label,
			})
	return result


func _warn_missing_progress(unit: Node) -> void:
	if unit == null:
		return
	var unit_id := ""
	var unit_data: Object = unit.get("unit_data")
	if unit_data != null:
		unit_id = String(unit_data.get("unit_id"))
	if unit_id.is_empty():
		unit_id = char_name
	if _warned_progress_ids.has(unit_id):
		return
	_warned_progress_ids[unit_id] = true
	push_warning("[BattleHUDV3VM] level/exp data unavailable for %s, using defaults" % char_name)


func _map_display_name_to_id(display_name: String) -> String:
	match display_name:
		"李淳罡":
			return "li_chungang"
		"徐凤年":
			return "xu_fengnian"
		"姜泥":
			return "jiang_ni"
		_:
			return ""
