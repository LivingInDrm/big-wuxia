extends SceneTree
## build_tileset.gd —— 一次性脚本：生成 resources/data/tiles/main_tileset.tres
##
## 用法：
##   godot --headless --path . --script tools/build_tileset.gd
##
## 产物：
##   resources/data/tiles/main_tileset.tres
##   （TileSet：1 个 TileSetAtlasSource[64x64]，54 个 tiles，custom_data_0=tile_id(String)）
##
## tile_id 标注策略（查看 Tiny Swords Tilemap_color1.png 9x6 grid 得出）：
##   row0, row1         → water / deep water  （0..8, 9..17）
##   row2..row5 边缘    → water 过渡带
##   row2..row5 中央    → grass / road
##   我们只需为 MVP 标注足够多的 grass/water/forest/mountain/road/bridge 即可；
##   其它未标注 tile 默认 grass（move=1, obstacle=false），保证不会有 null。
##
## 见 05-mvp-scope.md §3.2 / 03-art-pipeline.md §3。

const OUT_PATH := "res://resources/data/tiles/main_tileset.tres"
const ATLAS_PATH := "res://resources/sprites/terrain/tilemap_color1.png"
const TILE_PX := 64

# 9x6 网格 → 用默认 "grass" 填充，然后对关键 coord 覆盖
# （Tiny Swords Tilemap_color1 的典型布局：上面两行是水，中间大片是草地与路）
const DEFAULT_TILE_ID := "grass"

# S2 简化映射（详见 scenes/battle/battle_controller.gd 的 CHAR_TO_ATLAS 注释）：
#   atlas (6, 1) → grass （纯中央草地，用作大部分地形的视觉底）
#   atlas (5, 5) → water （水色石壁，用作水域视觉标记）
#   其它 coord   → grass 兜底（S2 地图只用到 (6,1) 和 (5,5) 两种）
# 未来（S3+）引入 TileSet Terrains autotile 或 sprite 差异后再扩展。
static func get_tile_id_for(coord: Vector2i) -> String:
	if coord == Vector2i(5, 5):
		return "water"
	return "grass"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var tex: Texture2D = load(ATLAS_PATH) as Texture2D
	if tex == null:
		push_error("[build_tileset] texture not found: %s" % ATLAS_PATH)
		quit(2)
		return

	var tex_size := tex.get_size()
	var cols := int(tex_size.x) / TILE_PX
	var rows := int(tex_size.y) / TILE_PX
	print("[build_tileset] atlas %sx%s → %dx%d tiles" % [tex_size.x, tex_size.y, cols, rows])

	# 1. TileSetAtlasSource
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE_PX, TILE_PX)

	# 创建全部 cols×rows 个 tile
	for y in rows:
		for x in cols:
			atlas.create_tile(Vector2i(x, y))

	# 2. TileSet
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_PX, TILE_PX)

	# Custom Data Layer 0: tile_id (String)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "tile_id")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	# 加入 atlas source
	var source_id := ts.add_source(atlas)
	print("[build_tileset] source_id = %d" % source_id)

	# 3. 对每个 tile 填 tile_id 自定义数据
	for y in rows:
		for x in cols:
			var coord := Vector2i(x, y)
			var tile_data = atlas.get_tile_data(coord, 0)
			if tile_data == null:
				push_warning("[build_tileset] no tile_data at %s" % coord)
				continue
			var id := get_tile_id_for(coord)
			tile_data.set_custom_data("tile_id", id)

	# 4. 保存
	var err := ResourceSaver.save(ts, OUT_PATH)
	if err != OK:
		push_error("[build_tileset] save failed err=%d out=%s" % [err, OUT_PATH])
		quit(3)
		return

	print("[build_tileset] OK saved %s (%d tiles)" % [OUT_PATH, cols * rows])
	quit(0)
