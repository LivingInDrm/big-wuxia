extends Node
class_name GridSystem
## GridSystem —— 战斗网格系统
##
## 职责：
##   - 从 TileMapLayer 读取每格的 tile_id（Custom Data Layer），匹配 TerrainTileData .tres
##   - 维护 tiles: Dictionary[Vector2i, GridTile]
##   - 基础查询：get_tile / is_walkable / is_occupied / get_all_coords
##   - S4 算法：get_move_range (Dijkstra) / get_attack_range (Chebyshev 环) / get_path (A*)
##
## 使用：
##   var grid := GridSystem.new()
##   grid.init_from_tilemap(tilemap_layer)
##   var reachable := grid.get_move_range(from, mov_budget)
##   var targets := grid.get_attack_range(pos, 1)
##   var path := grid.get_path(from, to)
##
## 参考：docs/design/04-tech-stack.md §1 & §4

const TERRAIN_DIR := "res://resources/data/tiles/"
const TERRAIN_IDS := ["grass", "forest", "mountain", "water", "road", "bridge"]

var tiles: Dictionary = {}          # Vector2i → GridTile
var _terrain_library: Dictionary = {}  # String (tile_id) → TerrainTileData


func _ready() -> void:
	_load_terrain_library()


## 加载 6 个 TerrainTileData .tres 到内存查找表。
## 若在 _ready 之前手动调用 init_from_tilemap，也会在那里兜底调用一次。
func _load_terrain_library() -> void:
	if not _terrain_library.is_empty():
		return
	for id in TERRAIN_IDS:
		var path := "%s%s.tres" % [TERRAIN_DIR, id]
		var res: Resource = load(path)
		if res == null:
			push_error("[GridSystem] failed to load terrain resource: %s" % path)
			continue
		_terrain_library[id] = res


## 从一个 TileMapLayer 初始化 tiles。
## 对每个 used_cells_by_id 的格子读取 custom_data_0 (tile_id) → 查库 → 建 GridTile。
func init_from_tilemap(tilemap: TileMapLayer) -> void:
	if tilemap == null:
		push_error("[GridSystem] init_from_tilemap: tilemap is null")
		return
	_load_terrain_library()
	tiles.clear()

	var used := tilemap.get_used_cells()
	for coord in used:
		var td = tilemap.get_cell_tile_data(coord)
		if td == null:
			# 该格有 atlas 图但没 tile data（不该发生）
			push_warning("[GridSystem] no tile_data at %s" % coord)
			continue
		var tid: String = td.get_custom_data("tile_id")
		if tid == null or tid == "":
			push_warning("[GridSystem] empty tile_id at %s" % coord)
			tid = "grass"  # 兜底
		var terrain: TerrainTileData = _terrain_library.get(tid)
		if terrain == null:
			push_warning("[GridSystem] unknown tile_id '%s' at %s (using grass)" % [tid, coord])
			terrain = _terrain_library.get("grass")
		tiles[coord] = GridTile.new(coord, terrain)

	print("[GridSystem] initialized %d tiles from TileMapLayer" % tiles.size())


## 从 LevelData 初始化（新式，优先使用 walkable_cells + terrain_by_cell）。
## 若 walkable_cells 为空，退回 map_layout（legacy 路径）。未知 terrain 回退
## 到 grass + warning。
func init_from_level_data(level_data: LevelData) -> void:
	if level_data == null:
		push_error("[GridSystem] init_from_level_data: level_data is null")
		return
	_load_terrain_library()
	tiles.clear()

	var cells: PackedVector2Array = level_data.ensure_map_layout()
	var grass: TerrainTileData = _terrain_library.get("grass")
	if grass == null:
		push_error("[GridSystem] grass terrain missing; cannot init from level_data")
		return

	for v in cells:
		var coord := Vector2i(int(v.x), int(v.y))
		var tid_variant = level_data.terrain_by_cell.get(coord, "grass")
		var tid: String = str(tid_variant) if tid_variant != null else "grass"
		var terrain: TerrainTileData = _terrain_library.get(tid)
		if terrain == null:
			push_warning("[GridSystem] unknown terrain '%s' at %s (using grass)" % [tid, coord])
			terrain = grass
		tiles[coord] = GridTile.new(coord, terrain)

	print("[GridSystem] initialized %d tiles from LevelData (map_id=%s)" % [tiles.size(), level_data.map_id])


## ============ 查询 API ============

func get_tile(coord: Vector2i) -> GridTile:
	return tiles.get(coord)


func has_tile(coord: Vector2i) -> bool:
	return tiles.has(coord)


## 是否可落脚：格子存在 + 地形非障碍 + 无占用单位
func is_walkable(coord: Vector2i) -> bool:
	var t: GridTile = tiles.get(coord)
	if t == null:
		return false
	if not t.is_walkable():
		return false
	if t.is_occupied():
		return false
	return true


## 是否被单位占用（不管地形）
func is_occupied(coord: Vector2i) -> bool:
	var t: GridTile = tiles.get(coord)
	if t == null:
		return false
	return t.is_occupied()


## 设置/清除占用（S3 Unit 引入后调用）
func set_occupant(coord: Vector2i, unit: Node) -> void:
	var t: GridTile = tiles.get(coord)
	if t == null:
		push_warning("[GridSystem] set_occupant on non-existent tile %s" % coord)
		return
	t.occupant = unit


func clear_occupant(coord: Vector2i) -> void:
	var t: GridTile = tiles.get(coord)
	if t != null:
		t.occupant = null


func get_all_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in tiles.keys():
		out.append(k)
	return out


func tile_count() -> int:
	return tiles.size()


## ============ 范围 / 寻路算法（S4） ============

const _DIRS_4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## 根据移动点数预算，从 from 出发可达的全部格子（不含 from 本身）。
##
## Dijkstra（因为 movement_cost 可不同）。
## - 障碍格 (is_obstacle) 直接跳过
## - 其他单位占用的格子不能落脚，但可以穿过（默认规则）——S5 可改为敌方单位阻挡
## - 返回 Array[Vector2i]，按最小 cost 顺序
##
## treat_occupied_as_block=true 时，其他单位占用的格子被视为不可穿过（供 AI 用保守路径）。
func get_move_range(from: Vector2i, budget: int,
		treat_occupied_as_block: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not tiles.has(from) or budget <= 0:
		return result

	var dist: Dictionary = {from: 0}
	# 简单 O(N^2) Dijkstra：节点数 <=120，完全够用
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		# 取当前 dist 最小的
		var best_idx := 0
		for i in range(1, frontier.size()):
			if dist[frontier[i]] < dist[frontier[best_idx]]:
				best_idx = i
		var cur: Vector2i = frontier[best_idx]
		frontier.remove_at(best_idx)
		var cur_cost: int = dist[cur]

		for d in _DIRS_4:
			var nxt: Vector2i = cur + d
			if not tiles.has(nxt):
				continue
			var t: GridTile = tiles[nxt]
			if t.terrain == null or t.terrain.is_obstacle:
				continue
			if treat_occupied_as_block and t.is_occupied():
				continue
			var step_cost: int = max(1, t.terrain.movement_cost)
			var new_cost: int = cur_cost + step_cost
			if new_cost > budget:
				continue
			if not dist.has(nxt) or new_cost < dist[nxt]:
				dist[nxt] = new_cost
				frontier.append(nxt)

	for coord in dist.keys():
		if coord == from:
			continue
		# 终点必须可落脚（不被占用），但中途可以穿过
		var t2: GridTile = tiles[coord]
		if t2.is_occupied():
			continue
		result.append(coord)
	return result


## 攻击范围：Chebyshev 距离 = weapon_range 的环（含射程 1..weapon_range）。
## S4 简化：只要求 Chebyshev 距离 ∈ [1, weapon_range]，不考虑地形遮挡。
func get_attack_range(from: Vector2i, weapon_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if weapon_range <= 0:
		return result
	for dx in range(-weapon_range, weapon_range + 1):
		for dy in range(-weapon_range, weapon_range + 1):
			if dx == 0 and dy == 0:
				continue
			var d: int = max(abs(dx), abs(dy))  # Chebyshev
			if d > weapon_range:
				continue
			var coord := from + Vector2i(dx, dy)
			if not tiles.has(coord):
				continue
			result.append(coord)
	return result


## A* 寻路：from → to，返回格子序列（含 to，不含 from）。
## 找不到时返回空 []。
## 与 get_move_range 规则一致：障碍不可穿，其他单位默认可穿（treat_occupied_as_block 控制）。
##
## 注意：避免与 Node.get_path() 冲突，方法名用 find_path。
func find_path(from: Vector2i, to: Vector2i,
		treat_occupied_as_block: bool = false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from == to or not tiles.has(from) or not tiles.has(to):
		return out

	var open_set: Array[Vector2i] = [from]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0}
	var f_score: Dictionary = {from: _heuristic(from, to)}

	while not open_set.is_empty():
		# 取 f_score 最小
		var best_idx := 0
		for i in range(1, open_set.size()):
			if f_score.get(open_set[i], INF) < f_score.get(open_set[best_idx], INF):
				best_idx = i
		var cur: Vector2i = open_set[best_idx]
		if cur == to:
			return _reconstruct_path(came_from, cur)
		open_set.remove_at(best_idx)

		for d in _DIRS_4:
			var nxt: Vector2i = cur + d
			if not tiles.has(nxt):
				continue
			var t: GridTile = tiles[nxt]
			if t.terrain == null or t.terrain.is_obstacle:
				continue
			if treat_occupied_as_block and t.is_occupied() and nxt != to:
				continue
			var step_cost: int = max(1, t.terrain.movement_cost)
			var tentative_g: int = g_score[cur] + step_cost
			if tentative_g < g_score.get(nxt, INF):
				came_from[nxt] = cur
				g_score[nxt] = tentative_g
				f_score[nxt] = tentative_g + _heuristic(nxt, to)
				if not open_set.has(nxt):
					open_set.append(nxt)

	return out


func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)  # Manhattan（4 邻格）


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.insert(0, current)
	# 去掉起点
	if path.size() > 0:
		path.pop_front()
	return path


## 便捷：找 occupant 所在 coord（O(N)）
func find_unit_coord(unit: Node) -> Vector2i:
	for coord in tiles.keys():
		var t: GridTile = tiles[coord]
		if t.occupant == unit:
			return coord
	return Vector2i(-1, -1)


## 返回所有敌方或己方单位的 coord（用于 AI 搜最近目标）
func get_units_by_enemy_flag(is_enemy: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for coord in tiles.keys():
		var t: GridTile = tiles[coord]
		if t.occupant == null:
			continue
		# occupant 是 Unit，访问 unit_data.is_enemy
		if t.occupant.unit_data != null and t.occupant.unit_data.is_enemy == is_enemy:
			out.append(coord)
	return out
