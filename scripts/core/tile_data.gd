extends Resource
class_name TerrainTileData
## TerrainTileData —— 单种地形的运行时数据（Resource，可在编辑器或脚本中实例化成 .tres）
##
## 命名注意：Godot 4 内建类 `TileData` 已存在（TileSet per-tile data），
## 为避免 class_name 冲突，本类命名为 TerrainTileData。
##
## 字段说明：
##   tile_id         逻辑 ID，对应 TileSet 的 Custom Data Layer "tile_id"
##   display_name    中文显示名（UI / debug 用）
##   movement_cost   移动消耗点数（S4 BFS/Dijkstra 用）。0 表示不可通行（is_obstacle=true 时等价）
##   dodge_bonus     地形闪避加成（百分比，0.10 = +10%）
##   is_obstacle     是否完全不可通行（山/深水）
##
## 注意：本 Resource 只存静态地形规则；占用 (occupancy) 由 GridSystem 运行时维护，不在这里。

@export var tile_id: String = ""
@export var display_name: String = ""
@export_range(0, 99) var movement_cost: int = 1
@export_range(0.0, 1.0, 0.01) var dodge_bonus: float = 0.0
@export var is_obstacle: bool = false


func _to_string() -> String:
	return "[TileData id=%s name=%s cost=%d dodge=%.2f obs=%s]" % [
		tile_id, display_name, movement_cost, dodge_bonus, is_obstacle
	]
