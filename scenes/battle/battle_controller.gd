extends Node2D
## BattleController —— 战斗场景主控（Sprint 2）
##
## 职责：
##   - _ready() 程序化铺设 12×10 grass 战场地图（TileSet Terrain autotile）
##   - 实例化 GridSystem 并从 TerrainLayer 初始化
##   - 居中相机
##
## 地图为什么用代码而非 .tscn 存：
##   .tscn 的 tile_map_data 是 PackedByteArray（不可读不可 diff），且 Terrain autotile
##   只需要一行 API 即可铺设，代码表达更清晰。后续有正式关卡时改为从 .tres level 资源读。
##
## 后续 Sprint：S3 Unit 放置 / S4 输入+范围 / S5 战斗结算 / S6 AI+胜负

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var highlight_layer: TileMapLayer = $HighlightLayer
@onready var camera: Camera2D = $Camera2D

var grid: GridSystem

const MAP_COLS := 12
const MAP_ROWS := 10
const TILE_PX := 64


func _ready() -> void:
	print("[BattleController] ready")

	_paint_map()

	grid = GridSystem.new()
	add_child(grid)
	grid.init_from_tilemap(terrain_layer)

	var count := grid.tile_count()
	print("[BattleController] GridSystem initialized with %d tiles" % count)

	# 居中相机到地图中点
	var map_w := MAP_COLS * TILE_PX
	var map_h := MAP_ROWS * TILE_PX
	camera.position = Vector2(map_w / 2.0, map_h / 2.0)


## 用 grass Terrain（autotile）一次性铺设 12×10 全平原。
##
## TileSet 状态（见 resources/data/tiles/main_tileset.tres）：
##   terrain_set_0 / terrain_0 = "grass"
##   16 tiles(0..3, 0..3) 的 peering bits 覆盖 16 autotile 形状（4 角 + 8 边 + 中心/孤岛）
##
## set_cells_terrain_connect 会根据每格与邻居的连通性自动选择合适形状，
## 达到"中央纯草 + 四边自动走边界 sprite + 四角完美收束"的视觉效果。
func _paint_map() -> void:
	const TERRAIN_SET_ID := 0
	const GRASS_TERRAIN_ID := 0
	var cells: Array[Vector2i] = []
	for x in MAP_COLS:
		for y in MAP_ROWS:
			cells.append(Vector2i(x, y))
	terrain_layer.set_cells_terrain_connect(cells, TERRAIN_SET_ID, GRASS_TERRAIN_ID, true)
	print("[BattleController] painted %d cells via terrain_connect (grass)" % cells.size())


## Debug 用（test 辅助）：返回 GridSystem 引用
func get_grid() -> GridSystem:
	return grid
