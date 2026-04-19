extends Node2D
## BattleController —— 战斗场景主控（Sprint 3）
##
## 职责（S3）：
##   - 程序化铺设 12×10 grass 战场地图（S2 遗留）
##   - 实例化 GridSystem 并从 TerrainLayer 初始化
##   - 在 UnitsContainer 下放置 3 玩家 + 3 敌兵（教程关初始位置）
##   - 连接 TurnManager 信号 → 驱动 BattleUI 文字更新
##   - 启动战斗 start_battle()
##
## 地图为什么用代码而非 .tscn 存：
##   .tscn 的 tile_map_data 是 PackedByteArray（不可读不可 diff），且 Terrain autotile
##   只需要一行 API 即可铺设，代码表达更清晰。后续有正式关卡时改为从 .tres level 资源读。
##
## 后续 Sprint：S4 输入+范围 / S5 战斗结算 / S6 AI+胜负

const UNIT_SCENE: PackedScene = preload("res://scenes/unit/unit.tscn")
const UNIT_PATH_FMT := "res://resources/data/units/%s.tres"
const TILE_PX := 64
const MAP_COLS := 12
const MAP_ROWS := 10

## 教程关单位布阵（id + grid_pos + 阵营）
## 参考 docs/design/05-mvp-scope.md §3.1 教程关布阵
const UNIT_LAYOUT := [
	{"id": "xu_fengnian",    "pos": Vector2i(2, 2), "faction": "player"},
	{"id": "jiang_ni",       "pos": Vector2i(2, 4), "faction": "player"},
	{"id": "li_chungang",    "pos": Vector2i(2, 6), "faction": "player"},
	{"id": "enemy_soldier",  "pos": Vector2i(6, 1), "faction": "enemy"},
	{"id": "enemy_soldier",  "pos": Vector2i(6, 3), "faction": "enemy"},
	{"id": "enemy_soldier",  "pos": Vector2i(6, 6), "faction": "enemy"},
]

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var highlight_layer: TileMapLayer = $HighlightLayer
@onready var units_container: Node2D = $UnitsContainer
@onready var camera: Camera2D = $Camera2D
@onready var turn_manager: TurnManager = $TurnManager
@onready var ui: BattleUI = $UI

var grid: GridSystem
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []


func _ready() -> void:
	print("[BattleController] ready")

	_paint_map()

	grid = GridSystem.new()
	add_child(grid)
	grid.init_from_tilemap(terrain_layer)
	print("[BattleController] GridSystem initialized with %d tiles" % grid.tile_count())

	_spawn_units()

	# 居中相机到地图中点
	var map_w := MAP_COLS * TILE_PX
	var map_h := MAP_ROWS * TILE_PX
	camera.position = Vector2(map_w / 2.0, map_h / 2.0)

	# 接入回合管理
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.start_battle()


## 用 grass Terrain（autotile）一次性铺设 12×10 全平原。
##
## TileSet 状态（见 resources/data/tiles/main_tileset.tres）：
##   terrain_set_0 / terrain_0 = "grass"
##   16 tiles(0..3, 0..3) 的 peering bits 覆盖 16 autotile 形状
func _paint_map() -> void:
	const TERRAIN_SET_ID := 0
	const GRASS_TERRAIN_ID := 0
	var cells: Array[Vector2i] = []
	for x in MAP_COLS:
		for y in MAP_ROWS:
			cells.append(Vector2i(x, y))
	terrain_layer.set_cells_terrain_connect(cells, TERRAIN_SET_ID, GRASS_TERRAIN_ID, true)
	print("[BattleController] painted %d cells via terrain_connect (grass)" % cells.size())


## 按 UNIT_LAYOUT 放置 6 个单位到 UnitsContainer 下。
func _spawn_units() -> void:
	for entry in UNIT_LAYOUT:
		var id: String = entry["id"]
		var pos: Vector2i = entry["pos"]
		var faction: String = entry["faction"]

		var data: UnitData = load(UNIT_PATH_FMT % id)
		if data == null:
			push_error("[BattleController] UnitData load failed: %s" % id)
			continue

		var unit: Unit = UNIT_SCENE.instantiate()
		unit.setup(data, pos)
		units_container.add_child(unit)

		if faction == "player":
			player_units.append(unit)
		else:
			enemy_units.append(unit)

	print("[BattleController] spawned %d player + %d enemy units" % [
		player_units.size(), enemy_units.size()])


func _on_turn_started(turn_num: int) -> void:
	print("[BattleController] turn_started: %d" % turn_num)
	ui.set_turn(turn_num, TurnManager.phase_label(turn_manager.current_phase))


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	ui.set_turn(turn_manager.current_turn, TurnManager.phase_label(phase))


## Debug / 测试辅助
func get_grid() -> GridSystem:
	return grid


func get_turn_manager() -> TurnManager:
	return turn_manager


func get_player_units() -> Array[Unit]:
	return player_units


func get_enemy_units() -> Array[Unit]:
	return enemy_units
