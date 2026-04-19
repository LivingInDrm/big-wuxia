extends Control
## Preview-only glue script for `battle_hud_preview.tscn`.
##
## Instances `battle_hud_v2.tscn`, builds a `BattleHUDMock`, wires VM signals
## to HUD nodes so the skeleton shows realistic-looking data without any
## runtime BattleController. This script is NOT `battle_hud_v2.gd` and does
## NOT ship with the HUD scene; it only lives in the debug preview scene.

const BattleHUDMockScript = preload("res://scripts/ui/battle_hud_mock.gd")
const BattleHUDScene = preload("res://scenes/battle/battle_hud_v2.tscn")

const SHORTCUTS := {
	"%ActionMove": "M",
	"%ActionAttack": "A",
	"%ActionDefend": "D",
	"%ActionSkill": "S",
	"%ActionEnd": "Space",
}

var hud: Control
var vm: Object
var mock_data: Dictionary


func _ready() -> void:
	hud = BattleHUDScene.instantiate()
	add_child(hud)
	hud.anchor_left = 0.0
	hud.anchor_top = 0.0
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0

	_apply_shortcut_labels()

	mock_data = BattleHUDMockScript.mock_battle()
	vm = mock_data["vm"]

	_connect_vm_signals()
	vm.mock_tick()


func _apply_shortcut_labels() -> void:
	for btn_path in SHORTCUTS.keys():
		var btn := hud.get_node(btn_path) as Button
		if btn == null:
			continue
		var lbl := btn.get_node_or_null("ShortcutLabel") as Label
		if lbl != null:
			lbl.text = SHORTCUTS[btn_path]


func _connect_vm_signals() -> void:
	vm.current_unit_changed.connect(_on_current_unit_changed)
	vm.target_changed.connect(_on_target_changed)
	vm.turn_changed.connect(_on_turn_changed)
	vm.damage_preview_changed.connect(_on_damage_preview_changed)
	vm.action_available_changed.connect(_on_action_available_changed)


func _apply_unit_card(card_node: Node, unit: Object) -> void:
	var name_label := card_node.get_node("HBox/VBox/Name") as Label
	var class_label := card_node.get_node("HBox/VBox/Class") as Label
	var avatar := card_node.get_node("HBox/AvatarFrame/Avatar") as TextureRect
	name_label.text = unit.unit_name
	class_label.text = unit.class_name_label
	avatar.self_modulate = unit.modulate


func _apply_hp_row(row_node: Node, caption_text: String, variation: StringName,
		cur: int, maxv: int) -> void:
	var cap := row_node.get_node("Caption") as Label
	var bar := row_node.get_node("Bar") as Range
	var val := row_node.get_node("Value") as Label
	cap.text = caption_text
	bar.theme_type_variation = variation
	bar.max_value = float(max(maxv, 1))
	bar.value = float(cur)
	val.text = "%d/%d" % [cur, maxv]


func _on_current_unit_changed(unit: Object) -> void:
	if unit == null:
		return
	_apply_unit_card(hud.get_node("%UnitInfoCard"), unit)
	_apply_hp_row(hud.get_node("%HpBarRow"), "HP", &"bar_hp",
			unit.current_hp, unit.max_hp)
	_apply_hp_row(hud.get_node("%MpBarRow"), "MP", &"bar_mp",
			unit.current_mp, unit.max_mp)


func _on_target_changed(unit: Object) -> void:
	var target := hud.get_node("%TargetPreview") as Control
	if unit == null:
		target.visible = false
		return
	target.visible = true
	_apply_unit_card(hud.get_node("%EnemyInfoCard"), unit)
	_apply_hp_row(hud.get_node("%EnemyHpBar"), "HP", &"bar_hp",
			unit.current_hp, unit.max_hp)


func _on_turn_changed(team: String, turn_number: int, day: int) -> void:
	var label := hud.get_node("%TurnIndicator") as Label
	var team_text := "玩家回合" if team == "player" else "敌方回合"
	label.text = "第 %d 天 · %s（回合 %d）" % [day, team_text, turn_number]


func _on_damage_preview_changed(hit: int, crit: int, dmg_min: int, dmg_max: int) -> void:
	var label := hud.get_node("%DamagePreview") as Label
	label.text = "命中 %d%%  ·  暴击 %d%%  ·  伤害 %d-%d" % [hit, crit, dmg_min, dmg_max]


func _on_action_available_changed(available: Dictionary) -> void:
	var pairs := [
		["%ActionMove", "move"],
		["%ActionAttack", "attack"],
		["%ActionDefend", "defend"],
		["%ActionSkill", "skill"],
		["%ActionEnd", "end_turn"],
	]
	for entry in pairs:
		var btn_path: String = entry[0]
		var key: String = entry[1]
		var btn := hud.get_node(btn_path) as Button
		if btn != null:
			btn.disabled = not bool(available.get(key, false))
