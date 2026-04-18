extends Node
class_name GridSystem
## GridSystem —— 战斗网格系统（Sprint 2 基础版，不含 BFS/A*）
##
## 职责：
##   - 从 TileMapLayer 读取每格的 tile_id（Custom Data Layer），匹配 TerrainTileData .tres
##   - 维护 tiles: Dictionary[Vector2i, GridTile]
##   - 提供基础查询：get_tile / is_walkable / is_occupied / get_all_coords
##
## 不做（留给 Sprint 4）：
##   - BFS 移动范围
##   - A* 寻路
##   - 攻击范围计算
##
## 使用：
##   var grid := GridSystem.new()
##   grid.init_from_tilemap(tilemap_layer)
##   var tile: GridTile = grid.get_tile(Vector2i(3, 5))
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
