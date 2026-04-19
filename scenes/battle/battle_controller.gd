extends Node2D
## BattleController —— 战斗场景主控（Sprint 4）
##
## S3 职责（保留）：
##   - 程序化铺 12×10 grass 地图
##   - 初始化 GridSystem，放置 3 玩家 + 3 敌兵
##   - 驱动 TurnManager + BattleUI
##
## S4 新增：
##   - 玩家输入：点击己方 → 显示 move_range → 点可达格 → 移动 + 显示 attack_range
##     → 点范围内敌方 → 攻击；点自己 / 点外面 = 取消
##   - CombatSystem 伤害结算
##   - EnemyAI 依次执行敌方回合
##   - 所有己方 acted → 自动 _start_enemy_phase；敌方全 acted → _next_turn
##
## 阶段内部状态：
##   IDLE               无选中（等玩家选）
##   UNIT_SELECTED      选中己方，显示 move_range（玩家需点击目的地或取消）
##   MOVED_AWAIT_ACTION 已移动，显示 attack_range（玩家点敌人攻击 或 点空结束回合）
##
## S5 新增：
##   - 技能按钮 / 技能范围 / 施法
##   - 地形命中修正
##   - 胜负判定

const UNIT_SCENE: PackedScene = preload("res://scenes/unit/unit.tscn")
const SKILL_EXECUTOR = preload("res://scripts/systems/skill_executor.gd")
const ITEM_EFFECT_EXECUTOR = preload("res://scripts/systems/item_effect_executor.gd")
const VFX = preload("res://scripts/systems/vfx.gd")
const ItemData = preload("res://scripts/core/item_data.gd")
const LevelData = preload("res://scripts/core/level_data.gd")
const TILE_PX := 64
const TERRAIN_SET_ID := 0
const GRASS_TERRAIN_ID := 0
const DEFAULT_LEVEL_ID := "level_01"
const ITEM_DIR := "res://resources/data/items/"

enum SelectState { IDLE, UNIT_SELECTED, MOVED_AWAIT_ACTION, SKILL_TARGETING, ITEM_TARGETING }

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var range_overlay: RangeOverlay = $RangeOverlay
@onready var units_container: Node2D = $UnitsContainer
@onready var camera: Camera2D = $Camera2D
@onready var turn_manager: TurnManager = $TurnManager
@onready var ui: BattleUI = $UI

var grid: GridSystem
var enemy_ai: EnemyAI
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var current_level_data
var map_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ONE)

var select_state: SelectState = SelectState.IDLE
var selected_unit: Unit = null
var current_move_range: Array[Vector2i] = []
var current_attack_range: Array[Vector2i] = []
var current_skill_range: Array[Vector2i] = []
var current_skill = null
var _skill_return_state: SelectState = SelectState.IDLE
var current_item: ItemData = null
var current_item_range: Array[Vector2i] = []
var _item_return_state: SelectState = SelectState.IDLE
var _pending_finish_after_move: bool = false
var _battle_ended: bool = false


func _ready() -> void:
	print("[BattleController] ready")

	current_level_data = _resolve_level_data()
	_paint_map()

	grid = GridSystem.new()
	add_child(grid)
	grid.init_from_tilemap(terrain_layer)
	print("[BattleController] GridSystem initialized with %d tiles" % grid.tile_count())

	_spawn_units()

	enemy_ai = EnemyAI.new(grid, null)

	_center_camera()

	# 回合信号
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.phase_changed.connect(_on_phase_changed)
	ui.skill_button_pressed.connect(_on_skill_button_pressed)
	ui.item_button_pressed.connect(_on_item_button_pressed)
	ui.item_selected.connect(_on_item_selected)
	ui.item_panel_closed.connect(_on_item_panel_closed)
	turn_manager.start_battle()


func _paint_map() -> void:
	terrain_layer.clear()
	var cells: Array[Vector2i] = []
	if current_level_data != null:
		for coord in current_level_data.map_layout:
			cells.append(coord)
	if cells.is_empty():
		for x in 8:
			for y in 8:
				cells.append(Vector2i(x, y))
	map_bounds = _compute_bounds(cells)
	terrain_layer.set_cells_terrain_connect(cells, TERRAIN_SET_ID, GRASS_TERRAIN_ID, true)
	print("[BattleController] painted %d cells via terrain_connect (grass)" % cells.size())


func _spawn_units() -> void:
	player_units.clear()
	enemy_units.clear()
	if current_level_data == null:
		push_error("[BattleController] LevelData unavailable")
		return
	for entry in current_level_data.player_units:
		_spawn_unit_entry(entry, false)
	for entry in current_level_data.enemy_units:
		_spawn_unit_entry(entry, true)

	print("[BattleController] spawned %d player + %d enemy units" % [
		player_units.size(), enemy_units.size()])


# ============ 输入处理 ============

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _battle_ended:
			return
		# 真实事件顺序里 _unhandled_input 早于 Area2D.input_event。
		# 先用 physics 点查询过滤掉落在 Unit 身上的点击，避免把"点敌兵"
		# 误判成"点空格结束回合"。
		# 用 event.position（视口坐标）→ canvas_transform 逆变换得到世界坐标，
		# 避免依赖 get_global_mouse_position() 的缓存（测试场景下可能为 0）。
		var mb := event as InputEventMouseButton
		var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * mb.position
		var coord := Vector2i(int(world.x / TILE_PX), int(world.y / TILE_PX))
		if select_state == SelectState.SKILL_TARGETING:
			if current_skill != null and current_skill_range.has(coord):
				_on_cell_clicked(coord)
			else:
				_restore_after_skill_cancel()
			get_viewport().set_input_as_handled()
			return
		if select_state == SelectState.ITEM_TARGETING:
			_restore_after_item_cancel()
			get_viewport().set_input_as_handled()
			return
		if _is_click_on_unit(world):
			return
		_on_cell_clicked(coord)


func _on_unit_clicked(unit: Unit) -> void:
	if turn_manager.current_phase == TurnManager.Phase.ENEMY_TURN or _battle_ended:
		return
	if select_state == SelectState.SKILL_TARGETING:
		return
	if select_state == SelectState.ITEM_TARGETING:
		if _can_target_with_item(unit):
			await _execute_item(selected_unit, current_item, unit)
		else:
			_restore_after_item_cancel()
		return
	# 玩家点击单位：
	# - 如果当前选中状态，并且点到范围内敌人 → 攻击
	if select_state == SelectState.MOVED_AWAIT_ACTION and unit.unit_data.is_enemy \
			and current_attack_range.has(unit.current_position):
		await _execute_attack(selected_unit, unit)
		return

	# - 如果 IDLE 且点自己单位 → 选中
	if select_state == SelectState.IDLE and not unit.unit_data.is_enemy and not unit.acted:
		_select_unit(unit)
		return

	# 其他：取消选择
	_cancel_selection()


func _on_cell_clicked(coord: Vector2i) -> void:
	if turn_manager.current_phase == TurnManager.Phase.ENEMY_TURN or _battle_ended:
		return
	match select_state:
		SelectState.UNIT_SELECTED:
			if current_move_range.has(coord):
				await _execute_move(selected_unit, coord)
			else:
				_cancel_selection()
		SelectState.MOVED_AWAIT_ACTION:
			# 点空格 = 结束该单位回合
			_finish_unit_action(selected_unit)
		SelectState.SKILL_TARGETING:
			if current_skill != null and current_skill_range.has(coord):
				await _execute_skill(selected_unit, current_skill, coord)
			else:
				_restore_after_skill_cancel()
		SelectState.ITEM_TARGETING:
			_restore_after_item_cancel()


# ============ 选择 / 移动 / 攻击 ============

func _select_unit(unit: Unit) -> void:
	selected_unit = unit
	select_state = SelectState.UNIT_SELECTED
	unit.set_selected(true)
	current_move_range = grid.get_move_range(unit.current_position, unit.get_current_mov(), true)
	range_overlay.clear()
	range_overlay.show_move_range(current_move_range)
	current_skill = null
	current_skill_range.clear()
	current_item = null
	current_item_range.clear()
	_pending_finish_after_move = false
	ui.show_skills(unit)
	ui.refresh_items()
	ui.set_message("选中 %s — 点击高亮格移动" % unit.unit_data.unit_name)


func _cancel_selection() -> void:
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = null
	select_state = SelectState.IDLE
	current_move_range.clear()
	current_attack_range.clear()
	current_skill_range.clear()
	current_skill = null
	current_item_range.clear()
	current_item = null
	_pending_finish_after_move = false
	range_overlay.clear()
	ui.hide_actions()
	ui.set_message("")


func _execute_move(unit: Unit, target: Vector2i) -> void:
	var from := unit.current_position
	var path := grid.find_path(from, target, true)
	if path.is_empty():
		return
	range_overlay.clear()
	# 更新 occupant（移前清旧，移后设新）
	var from_tile: GridTile = grid.get_tile(from)
	if from_tile != null:
		from_tile.occupant = null
	await unit.move_along_path(path)
	var to_tile: GridTile = grid.get_tile(unit.current_position)
	if to_tile != null:
		to_tile.occupant = unit

	if _pending_finish_after_move:
		unit.clear_temp_buffs()
		_pending_finish_after_move = false
		_finish_unit_action(unit)
		return

	# 显示攻击范围
	current_attack_range = grid.get_attack_range(
		unit.current_position, unit.unit_data.weapon_range)
	range_overlay.show_attack_range(current_attack_range)
	select_state = SelectState.MOVED_AWAIT_ACTION
	ui.show_skills(unit)
	ui.set_message("选择攻击目标或点击空格结束")


func _execute_attack(attacker: Unit, defender: Unit) -> void:
	range_overlay.clear()
	await attacker.play_attack(defender.position)
	var result: Dictionary = CombatSystem.calculate_attack(attacker, defender, grid)
	if result.hit:
		defender.take_damage(result.damage)
		ui.set_message("%s → %s 造成 %d 伤害" % [
			attacker.unit_data.unit_name, defender.unit_data.unit_name, result.damage])
	else:
		var parent_node := defender.get_parent() if defender.get_parent() != null else defender
		VFX.spawn_damage_number(parent_node, defender.global_position + Vector2(0, -40), "MISS", false)
		ui.set_message("%s 的攻击落空" % attacker.unit_data.unit_name)
	_finish_unit_action(attacker)


func _finish_unit_action(unit: Unit) -> void:
	if unit == null:
		_cancel_selection()
		return
	unit.clear_temp_buffs()
	unit.set_acted(true)
	unit.set_selected(false)
	selected_unit = null
	select_state = SelectState.IDLE
	current_move_range.clear()
	current_attack_range.clear()
	current_skill_range.clear()
	current_skill = null
	current_item_range.clear()
	current_item = null
	range_overlay.clear()
	ui.hide_actions()
	ui.set_message("")
	if _check_battle_end():
		return

	# 所有己方 acted → 切敌方
	if _all_acted(player_units):
		await get_tree().create_timer(0.25).timeout
		turn_manager._start_enemy_phase()


# ============ 回合流转 ============

func _on_turn_started(turn_num: int) -> void:
	print("[BattleController] turn_started: %d" % turn_num)
	ui.set_turn(turn_num, TurnManager.phase_label(turn_manager.current_phase))
	if turn_num > 1:
		for u in player_units + enemy_units:
			if u == null or not is_instance_valid(u):
				continue
			u.tick_status_effects()
	# 新回合重置 acted
	for u in player_units + enemy_units:
		u.set_acted(false)
		u.clear_temp_buffs()
		u.tick_cooldowns()
		if turn_num > 1:
			u.restore_mp(u.get_qi_regen_amount())


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	ui.set_turn(turn_manager.current_turn, TurnManager.phase_label(phase))
	if phase == TurnManager.Phase.ENEMY_TURN and not _battle_ended:
		_run_enemy_phase()


func _run_enemy_phase() -> void:
	_cancel_selection()
	for enemy in enemy_units.duplicate():
		if _battle_ended:
			return
		if enemy == null or not is_instance_valid(enemy) or enemy.current_hp <= 0:
			continue
		await enemy_ai.take_turn(enemy, player_units)
		if _check_battle_end():
			return
		await get_tree().create_timer(0.2).timeout
	# 结束敌方回合 → 下一回合
	if not _check_battle_end():
		turn_manager._next_turn()


func _on_unit_died(unit: Unit) -> void:
	var t: GridTile = grid.get_tile(unit.current_position)
	if t != null and t.occupant == unit:
		t.occupant = null
	if unit.unit_data != null and unit.unit_data.is_enemy:
		enemy_units.erase(unit)
	else:
		player_units.erase(unit)
	_check_battle_end()


func _all_acted(units: Array[Unit]) -> bool:
	for u in units:
		if u == null or not is_instance_valid(u):
			continue
		if u.current_hp <= 0:
			continue
		if not u.acted:
			return false
	return true


func _is_click_on_unit(world_pos: Vector2) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_2d().direct_space_state.intersect_point(params)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Area2D and collider.get_parent() is Unit:
			return true
	return false


func _on_skill_button_pressed(idx: int) -> void:
	if selected_unit == null or _battle_ended:
		return
	var skill = selected_unit.get_skill(idx)
	if skill == null or not skill.is_available():
		return
	if skill.effect_type == 2 and select_state != SelectState.UNIT_SELECTED:
		return
	current_item = null
	current_item_range.clear()
	ui.hide_item_panel()
	current_skill = skill
	current_skill_range = SKILL_EXECUTOR.get_targetable_cells(selected_unit, skill, grid)
	_skill_return_state = select_state
	select_state = SelectState.SKILL_TARGETING
	range_overlay.clear()
	range_overlay.show_cells(
		current_skill_range,
		Color(0.35, 0.6, 1.0, 0.35) if skill.effect_type == 1
			or skill.effect_type == 2 else Color(1.0, 0.3, 0.3, 0.35)
	)
	ui.show_skills(selected_unit)
	ui.set_message("选择 %s 的目标格" % skill.skill_name)


func _execute_skill(caster: Unit, skill, target: Vector2i) -> void:
	var affected = await SKILL_EXECUTOR.execute_skill(caster, skill, target, grid, CombatSystem)
	if skill.effect_type == 2 and skill.skill_id == "qing_gong":
		current_skill = null
		current_skill_range.clear()
		_pending_finish_after_move = true
		current_move_range = grid.get_move_range(caster.current_position, caster.get_current_mov(), true)
		range_overlay.clear()
		range_overlay.show_move_range(current_move_range)
		select_state = SelectState.UNIT_SELECTED
		ui.show_skills(caster)
		ui.set_message("轻功发动 — 选择新的落点")
		return
	range_overlay.clear()
	if skill.effect_type == 0:
		ui.set_message("%s 命中 %d 个目标" % [skill.skill_name, affected.size()])
	else:
		ui.set_message("%s 生效" % skill.skill_name)
	_finish_unit_action(caster)


func _restore_after_skill_cancel() -> void:
	current_skill = null
	current_skill_range.clear()
	range_overlay.clear()
	if _skill_return_state == SelectState.MOVED_AWAIT_ACTION:
		range_overlay.show_attack_range(current_attack_range)
	else:
		range_overlay.show_move_range(current_move_range)
	select_state = _skill_return_state
	ui.show_skills(selected_unit)
	ui.refresh_items()


func _on_item_button_pressed() -> void:
	if selected_unit == null or _battle_ended:
		return
	var consumables := _get_available_consumables()
	if consumables.is_empty():
		ui.refresh_items()
		ui.set_message("没有可用消耗品")
		return
	ui.show_item_panel(consumables)
	ui.set_message("选择一个消耗品")


func _on_item_selected(item_id: String) -> void:
	if selected_unit == null or _battle_ended:
		return
	var item := _load_item_data(item_id)
	if item == null:
		return
	current_skill = null
	current_skill_range.clear()
	current_item = item
	current_item_range = _get_item_target_positions(selected_unit, item)
	_item_return_state = select_state
	select_state = SelectState.ITEM_TARGETING
	range_overlay.clear()
	range_overlay.show_cells(current_item_range, Color(0.25, 0.85, 0.45, 0.35))
	ui.hide_item_panel()
	ui.show_skills(selected_unit)
	ui.set_message("选择 %s 的目标单位" % item.name)


func _on_item_panel_closed() -> void:
	if select_state == SelectState.ITEM_TARGETING:
		return
	ui.refresh_items()


func _execute_item(caster: Unit, item: ItemData, target: Unit) -> void:
	if caster == null or item == null or target == null:
		_restore_after_item_cancel()
		return
	var applied: bool = ITEM_EFFECT_EXECUTOR.apply_effect(item, target, caster)
	if not applied:
		ui.set_message("%s 未生效" % item.name)
		_restore_after_item_cancel()
		return
	var game_state: Node = _game_state()
	if game_state == null or not game_state.inventory.remove(item.id, 1):
		push_warning("[BattleController] failed to remove item %s from inventory" % item.id)
		_restore_after_item_cancel()
		return
	ui.refresh_items()
	ui.set_message("%s 对 %s 生效" % [item.name, target.unit_data.unit_name])
	_finish_unit_action(caster)


func _restore_after_item_cancel() -> void:
	current_item = null
	current_item_range.clear()
	range_overlay.clear()
	if _item_return_state == SelectState.MOVED_AWAIT_ACTION:
		range_overlay.show_attack_range(current_attack_range)
	else:
		range_overlay.show_move_range(current_move_range)
	select_state = _item_return_state
	ui.show_skills(selected_unit)
	ui.refresh_items()


func _can_target_with_item(unit: Unit) -> bool:
	if current_item == null or unit == null or selected_unit == null:
		return false
	if unit.current_hp <= 0:
		return false
	if unit.unit_data.is_enemy != selected_unit.unit_data.is_enemy:
		return false
	return current_item_range.has(unit.current_position)


func _get_available_consumables() -> Array:
	var results: Array = []
	var game_state: Node = _game_state()
	if game_state == null:
		return results
	var consumables: Array = game_state.inventory.list_by_category(ItemData.ItemCategory.CONSUMABLE)
	for entry in consumables:
		if not (entry is Dictionary):
			continue
		if int(entry.get("count", 0)) <= 0:
			continue
		results.append(entry)
	return results


func _get_item_target_positions(caster: Unit, item: ItemData) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if caster == null or item == null:
		return positions
	for unit in player_units + enemy_units:
		if unit == null or not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if unit.unit_data.is_enemy != caster.unit_data.is_enemy:
			continue
		positions.append(unit.current_position)
	return positions


func _check_battle_end() -> bool:
	if _battle_ended:
		return true
	if _is_victory_reached():
		_battle_ended = true
		trigger_victory()
		return true
	var player_alive := 0
	for unit in player_units:
		if unit != null and is_instance_valid(unit) and unit.current_hp > 0:
			player_alive += 1
	if player_alive == 0:
		_battle_ended = true
		trigger_defeat()
		return true
	return false


func trigger_victory() -> void:
	_grant_level_rewards()
	var scene_manager: Node = _scene_manager()
	if scene_manager != null:
		scene_manager.change_scene_to_file("res://scenes/victory/victory.tscn")


func trigger_defeat() -> void:
	var scene_manager: Node = _scene_manager()
	if scene_manager != null:
		scene_manager.change_scene_to_file("res://scenes/defeat/defeat.tscn")


# ============ 测试访问 API ============

func get_grid() -> GridSystem:
	return grid


func get_turn_manager() -> TurnManager:
	return turn_manager


func get_player_units() -> Array[Unit]:
	return player_units


func get_enemy_units() -> Array[Unit]:
	return enemy_units


func get_enemy_ai() -> EnemyAI:
	return enemy_ai


func get_level_data():
	return current_level_data


func get_map_bounds() -> Rect2i:
	return map_bounds


## 测试辅助：强制选中一个己方单位（不经过 input）
func debug_select(unit: Unit) -> void:
	_select_unit(unit)


func debug_move(unit: Unit, target: Vector2i) -> void:
	selected_unit = unit
	select_state = SelectState.UNIT_SELECTED
	current_move_range = grid.get_move_range(unit.current_position, unit.get_current_mov(), true)
	await _execute_move(unit, target)


func debug_attack(attacker: Unit, defender: Unit) -> void:
	await _execute_attack(attacker, defender)


func _load_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	var path := "res://resources/data/items/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ItemData


func _resolve_level_data():
	var game_state: Node = _game_state()
	var game_balance: Node = _game_balance()
	var level_id: String = game_state.current_level if game_state != null else ""
	if level_id == "":
		level_id = DEFAULT_LEVEL_ID
		if game_state != null:
			game_state.start_level(level_id)
	var level = game_balance.get_level_data(level_id) if game_balance != null else null
	if level == null:
		push_error("[BattleController] Missing LevelData: %s" % level_id)
	return level


func _grant_level_rewards() -> void:
	var level_data := current_level_data as LevelData
	if level_data == null or level_data.rewards.is_empty():
		return

	var reward_texts: Array[String] = []
	for reward in level_data.rewards:
		if not (reward is Dictionary):
			continue
		var item_id := String(reward.get("item_id", ""))
		var count := int(reward.get("count", 0))
		if item_id.is_empty() or count <= 0:
			continue
		var game_state: Node = _game_state()
		if game_state == null:
			return
		game_state.inventory.add(item_id, count)
		reward_texts.append("%s x%d" % [_get_item_name(item_id), count])

	if not reward_texts.is_empty():
		print("%s 通关奖励: %s" % [level_data.level_name, ", ".join(reward_texts)])


func _spawn_unit_entry(entry: Dictionary, is_enemy: bool) -> void:
	var unit_id := String(entry.get("unit_id", ""))
	var spawn_coord = entry.get("spawn_coord", Vector2i.ZERO)
	if unit_id == "" or not (spawn_coord is Vector2i):
		push_error("[BattleController] Invalid unit entry: %s" % [entry])
		return
	var game_balance: Node = _game_balance()
	var data := game_balance.get_unit_data(unit_id) as UnitData if game_balance != null else null
	if data == null:
		push_error("[BattleController] UnitData load failed: %s" % unit_id)
		return

	var unit: Unit = UNIT_SCENE.instantiate()
	unit.setup(data, spawn_coord)
	units_container.add_child(unit)
	unit.unit_selected.connect(_on_unit_clicked)
	unit.unit_died.connect(_on_unit_died)

	var tile: GridTile = grid.get_tile(spawn_coord) if grid != null else null
	if tile != null:
		tile.occupant = unit

	if is_enemy:
		enemy_units.append(unit)
	else:
		player_units.append(unit)


func _center_camera() -> void:
	var center_x := (float(map_bounds.position.x) + float(map_bounds.size.x) / 2.0) * TILE_PX
	var center_y := (float(map_bounds.position.y) + float(map_bounds.size.y) / 2.0) * TILE_PX
	camera.position = Vector2(center_x, center_y)


func _compute_bounds(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i.ONE)
	var min_x := cells[0].x
	var min_y := cells[0].y
	var max_x := cells[0].x
	var max_y := cells[0].y
	for coord in cells:
		min_x = mini(min_x, coord.x)
		min_y = mini(min_y, coord.y)
		max_x = maxi(max_x, coord.x)
		max_y = maxi(max_y, coord.y)
	return Rect2i(
		Vector2i(min_x, min_y),
		Vector2i(max_x - min_x + 1, max_y - min_y + 1)
	)


func _is_victory_reached() -> bool:
	if current_level_data == null:
		return false
	if current_level_data.victory_condition == "kill_boss":
		return not _is_boss_alive()
	for unit in enemy_units:
		if unit != null and is_instance_valid(unit) and unit.current_hp > 0:
			return false
	return true


func _is_boss_alive() -> bool:
	if current_level_data == null or current_level_data.boss_id == "":
		return false
	for unit in enemy_units:
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.current_hp <= 0 or unit.unit_data == null:
			continue
		if unit.unit_data.unit_id == current_level_data.boss_id:
			return true
	return false


func _get_item_name(item_id: String) -> String:
	var path := "%s%s.tres" % [ITEM_DIR, item_id]
	if not ResourceLoader.exists(path):
		return item_id
	var item := load(path) as ItemData
	if item == null or item.name.is_empty():
		return item_id
	return item.name


func _game_state():
	return get_node_or_null("/root/GameState")


func _game_balance():
	return get_node_or_null("/root/GameBalance")


func _scene_manager():
	return get_node_or_null("/root/SceneManager")
