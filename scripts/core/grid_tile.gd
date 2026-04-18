extends RefCounted
class_name GridTile
## GridTile —— GridSystem 运行时单格状态（每个网格坐标对应一个实例）
##
## 字段：
##   coord     格子坐标 (Vector2i)
##   terrain   地形规则（TerrainTileData Resource，可为 null = 未知/边界外，视为障碍）
##   occupant  当前占用单位（Node，S3 引入 Unit 后填；S2 恒为 null）

var coord: Vector2i
var terrain: TerrainTileData
var occupant: Node = null


func _init(p_coord: Vector2i, p_terrain: TerrainTileData) -> void:
	coord = p_coord
	terrain = p_terrain


func is_walkable() -> bool:
	if terrain == null:
		return false
	if terrain.is_obstacle:
		return false
	return true


func is_occupied() -> bool:
	return occupant != null


func _to_string() -> String:
	var terrain_id := terrain.tile_id if terrain != null else "<null>"
	return "[GridTile %s terrain=%s occ=%s]" % [coord, terrain_id, occupant]
