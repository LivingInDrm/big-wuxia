class_name BattleHUDMock
extends RefCounted
## Mock data source for `scenes/debug/battle_hud_preview.tscn`.
##
## Builds a representative state (3 players + 2 enemies, current = 徐凤年,
## target = 山贼 A, damage preview 12-18 / hit 85%) and returns a populated
## `BattleHUDVM` plus the stub units so the preview scene can wire them to
## the HUD nodes.

const BattleHUDVMScript = preload("res://scripts/ui/battle_hud_vm.gd")


class MockUnit extends RefCounted:
	var unit_name: String = ""
	var class_name_label: String = ""
	var modulate: Color = Color(1, 1, 1, 1)
	var current_hp: int = 0
	var max_hp: int = 1
	var current_mp: int = 0
	var max_mp: int = 1
	var is_enemy: bool = false

	func _init(p_name: String, p_class: String, p_modulate: Color,
			p_hp: int, p_max_hp: int, p_mp: int, p_max_mp: int,
			p_is_enemy: bool = false) -> void:
		unit_name = p_name
		class_name_label = p_class
		modulate = p_modulate
		current_hp = p_hp
		max_hp = p_max_hp
		current_mp = p_mp
		max_mp = p_max_mp
		is_enemy = p_is_enemy


static func mock_battle() -> Dictionary:
	var players: Array[MockUnit] = [
		MockUnit.new("徐凤年", "刀客", Color(0.55, 0.75, 1.0), 60, 100, 8, 30, false),
		MockUnit.new("姜泥",   "医修", Color(1.0, 0.72, 0.85), 80, 80, 25, 40, false),
		MockUnit.new("李淳罡", "剑圣", Color(0.9, 0.85, 0.55), 95, 100, 12, 50, false),
	]
	var enemies: Array[MockUnit] = [
		MockUnit.new("山贼 A", "山贼", Color(0.85, 0.45, 0.45), 24, 40, 0, 1, true),
		MockUnit.new("射手 B", "射手", Color(0.7, 0.55, 0.35), 40, 40, 0, 1, true),
	]

	var vm := BattleHUDVMScript.new()
	vm.set_current_unit(players[0])
	vm.set_target_unit(enemies[0])
	vm.set_turn("player", 1, 1)
	vm.set_damage_preview(85, 15, 12, 18)
	vm.set_action_availability({
		"move": true,
		"attack": true,
		"defend": false,
		"skill": true,
		"end_turn": true,
	})

	return {
		"vm": vm,
		"players": players,
		"enemies": enemies,
		"current": players[0],
		"target": enemies[0],
	}
