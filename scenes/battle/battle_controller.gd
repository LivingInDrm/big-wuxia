extends Node2D
## BattleController —— 战斗场景主控（Sprint 2 占位版本）
##
## 当前职责（S2）：
##   - _ready() 用代码铺设 12x10 测试地图（见 MAP_LAYOUT）
##   - 实例化 GridSystem 并从 TerrainLayer 初始化
##   - 居中相机
##
## 为什么地图用代码写：
##   .tscn 中 TileMapLayer 的 tile_map_data 是 PackedByteArray（不可读），手写 120 格不现实。
##   把地图定义放在这里，清晰、可 diff、可测试；后续有正式关卡时改为从 .tres level 资源读。
##
## 后续 Sprint：S3 Unit 放置 / S4 输入+范围 / S5 战斗结算 / S6 AI+胜负

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var highlight_layer: TileMapLayer = $HighlightLayer
@onready var camera: Camera2D = $Camera2D

var grid: GridSystem

const MAP_COLS := 12
const MAP_ROWS := 10
const TILE_PX := 64

# 12x10 测试地图（含平地/林地/山/水/路/桥）
# 字符 → atlas coord in tilemap_color1：
#   注意：Tilemap_color1.png 是 Tiny Swords 的 autotile 过渡集（岛与水的过渡形状），
#   单 tile 硬拼本身就带边缘 seam，这是 atlas 设计决定的。
#   S2 MVP 策略：除水域外的所有地形用同一个纯中央草 tile (6,1)，视觉清爽无 seam；
#   水域用 (5,5) 的水色石壁 tile 区分。地形差异（movement_cost/dodge）通过
#   TerrainTileData + tile_id 在 GridSystem 里体现，不依赖视觉。
#   S3 引入单位 sprite 后再考虑用 TileSet Terrains 功能或额外 sprite 做地形差异化。
#
#   . = grass       → atlas (6, 1)   纯中央草块
#   F = forest      → atlas (6, 1)   tile_id 仍为 grass（视觉同草，但 map 结构标记为林地位）
#   M = mountain    → atlas (6, 1)
#   W = water       → atlas (5, 5)   水色石壁（区分水域）
#   R = road        → atlas (6, 1)
#   B = bridge      → atlas (6, 1)
#
#   说明：因为 Tilemap_color1 没有独立 mountain/forest/road sprite，S2 所有非水 tile_id
#   实际都是 "grass"（GridSystem 读到的）。F/M/R/B 字符只影响地图绘制布局，不影响地形规则。
#   这等于 S2 只有 "grass" 和 "water" 两种有效地形 —— 满足 grid 初始化 120 tiles + 不同地形
#   表现测试。map 中 F/M/R/B 预留为 S3+ 的插槽。
const MAP_LAYOUT: Array[String] = [
	"............",
	".....FF.....",
	".FF........M",
	"...R........",
	"WWWWB.......",
	"WWWWB..R....",
	"......R.....",
	"......R....M",
	"......R.....",
	"............",
]

const CHAR_TO_ATLAS := {
	".": Vector2i(6, 1),
	"F": Vector2i(6, 1),
	"M": Vector2i(6, 1),
	"W": Vector2i(5, 5),
	"R": Vector2i(6, 1),
	"B": Vector2i(6, 1),
}


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


## 用 MAP_LAYOUT 铺设 TerrainLayer。
func _paint_map() -> void:
	var source_id := 0  # build_tileset.gd 中 ts.add_source 返回 0
	for y in MAP_ROWS:
		var row: String = MAP_LAYOUT[y]
		for x in MAP_COLS:
			var ch := row.substr(x, 1)
			var atlas_coord: Vector2i = CHAR_TO_ATLAS.get(ch, Vector2i(3, 2))
			terrain_layer.set_cell(Vector2i(x, y), source_id, atlas_coord)


## Debug 用（test 辅助）：返回 GridSystem 引用
func get_grid() -> GridSystem:
	return grid
