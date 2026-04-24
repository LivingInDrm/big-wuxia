extends Node
class_name EnemyAI
## EnemyAI —— S4 简易敌方 AI（Sprint 4）
##
## 策略（每个敌兵独立一轮决策）：
##   1. 找所有玩家单位，挑 Manhattan 距离最近的一个
##   2. 如果该玩家在我的攻击范围内 → 直接攻击
##   3. 否则计算我的移动范围，选一个"离目标最近"的格子移过去
##      - 如果走完还能攻击 → 攻击
##      - 否则结束行动
##
## S4 不做：
##   - 目标选择优先级（威胁、低血）
##   - 协同/包围
##   - 技能

var grid: GridSystem
var combat_system: CombatSystem


func _init(p_grid: GridSystem, p_combat: CombatSystem) -> void:
	grid = p_grid
	combat_system = p_combat


## 执行一个敌方单位的回合（Coroutine）。
## 返回 void，调用方 await 之后才继续下一个。
func take_turn(enemy: Unit, player_units: Array[Unit]) -> void:
	if enemy == null or enemy.current_hp <= 0 or player_units.is_empty():
		return

	# 过滤活着的玩家
	var alive_players: Array[Unit] = []
	for p in player_units:
		if p != null and p.current_hp > 0:
			alive_players.append(p)
	if alive_players.is_empty():
		return

	var from: Vector2i = enemy.current_position

	# 1. 找最近玩家
	var target: Unit = _nearest_unit(from, alive_players)
	if target == null:
		return

	# 2. 如果在攻击范围内，直接打
	var atk_range: Array[Vector2i] = grid.get_attack_range(from, enemy.unit_data.weapon_range)
	if atk_range.has(target.current_position):
		await _attack(enemy, target)
		return

	# 3. 否则移动：选离目标最近的可达格子
	var move_cells: Array[Vector2i] = grid.get_move_range(from, enemy.get_current_mov(), true)
	if move_cells.is_empty():
		return
	var best: Vector2i = _closest_to(target.current_position, move_cells)
	var path: Array[Vector2i] = grid.find_path(from, best, true)
	if path.is_empty():
		return

	# 更新 occupant
	grid.get_tile(from).occupant = null
	await enemy.move_along_path(path)
	var landed: Vector2i = enemy.current_position
	var landed_tile: GridTile = grid.get_tile(landed)
	if landed_tile != null:
		landed_tile.occupant = enemy

	# 4. 走完再看能不能攻击
	var atk_after: Array[Vector2i] = grid.get_attack_range(landed, enemy.unit_data.weapon_range)
	if atk_after.has(target.current_position):
		await _attack(enemy, target)


func _nearest_unit(from: Vector2i, candidates: Array[Unit]) -> Unit:
	var best: Unit = null
	var best_d: int = 9999
	for u in candidates:
		var d: int = abs(u.current_position.x - from.x) + abs(u.current_position.y - from.y)
		if d < best_d:
			best_d = d
			best = u
	return best


func _closest_to(target: Vector2i, cells: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = cells[0]
	var best_d: int = 9999
	for c in cells:
		var d: int = abs(c.x - target.x) + abs(c.y - target.y)
		if d < best_d:
			best_d = d
			best = c
	return best


func _attack(enemy: Unit, target: Unit) -> void:
	await enemy.play_attack(target.current_position)
	CombatSystem.resolve_attack(enemy, target, grid)
