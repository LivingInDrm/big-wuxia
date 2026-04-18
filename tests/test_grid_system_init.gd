extends SceneTree
## test_grid_system_init —— S2 GridSystem 初始化单元测试（独立 runner，无需 GUT）
##
## 用法：
##   godot --headless --path . --script tests/test_grid_system_init.gd
##
## 覆盖场景：
##   T1  Battle 场景可加载 + 实例化不 push_error
##   T2  GridSystem 自 TerrainLayer 初始化后 tile_count() == 120 （12×10）
##   T3  (0, 0) 格子非空（has_tile / get_tile 非 null）
##   T4  (0, 0) 地形 tile_id == "grass" （map 左上角定义为 '.' = grass）
##   T5  (0, 4) 地形 tile_id == "water" （MAP_LAYOUT row 4 col 0 = 'W' = water）
##   T6  水域 is_walkable() == false （water TerrainTileData.is_obstacle = true）
##   T7  grass 地形 is_walkable() == true
##   T8  越界坐标 get_tile() 返回 null
##
## 退出码：0 = 全部通过，1 = 有失败
##
## 策略：加载 Battle 场景 → 等几帧让 _ready 跑完 → 通过 controller.get_grid() 拿 GridSystem 引用

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_grid_system_init] ==== BEGIN ====")

	# T1: Battle 场景加载
	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		_fail_test("T1 Battle 场景加载失败: %s" % BATTLE_SCENE)
		_finish()
		return
	_pass_test("T1 Battle 场景 PackedScene 加载成功")

	var scene := packed.instantiate()
	if scene == null:
		_fail_test("T1b Battle 场景实例化失败")
		_finish()
		return
	root.add_child(scene)

	# 等 _ready 跑完（GridSystem 的 init_from_tilemap 在 BattleController._ready 里同步调用）
	await process_frame
	await process_frame

	# 拿 GridSystem 引用
	var grid = scene.call("get_grid") if scene.has_method("get_grid") else null
	if grid == null:
		_fail_test("T1c 无法从 BattleController 获取 GridSystem 引用")
		_finish()
		return
	_pass_test("T1c BattleController.get_grid() 返回非 null")

	# T2: tile_count == 120
	var count: int = grid.tile_count()
	_assert(count == 120, "T2 grid.tile_count() == 120 (实际=%d)" % count)

	# T3: (0, 0) 非空
	_assert(grid.has_tile(Vector2i(0, 0)), "T3a has_tile((0,0)) == true")
	var tile_00 = grid.get_tile(Vector2i(0, 0))
	_assert(tile_00 != null, "T3b get_tile((0,0)) 返回非 null")

	# T4: (0, 0) 是 grass
	if tile_00 != null and tile_00.terrain != null:
		_assert(tile_00.terrain.tile_id == "grass",
			"T4 (0,0) terrain.tile_id == 'grass' (实际=%s)" % tile_00.terrain.tile_id)

	# T5: (0, 4) 是 water （MAP_LAYOUT row 4 col 0 = 'W'）
	var tile_04 = grid.get_tile(Vector2i(0, 4))
	_assert(tile_04 != null, "T5a get_tile((0,4)) 返回非 null")
	if tile_04 != null and tile_04.terrain != null:
		_assert(tile_04.terrain.tile_id == "water",
			"T5b (0,4) terrain.tile_id == 'water' (实际=%s)" % tile_04.terrain.tile_id)

	# T6: 水不可通行
	if tile_04 != null:
		_assert(not tile_04.is_walkable(),
			"T6 water tile (0,4).is_walkable() == false")
		_assert(not grid.is_walkable(Vector2i(0, 4)),
			"T6b grid.is_walkable((0,4)) == false")

	# T7: 草地可通行
	if tile_00 != null:
		_assert(tile_00.is_walkable(),
			"T7 grass tile (0,0).is_walkable() == true")
		_assert(grid.is_walkable(Vector2i(0, 0)),
			"T7b grid.is_walkable((0,0)) == true")

	# T8: 越界
	_assert(grid.get_tile(Vector2i(999, 999)) == null,
		"T8a get_tile((999,999)) == null")
	_assert(not grid.has_tile(Vector2i(-1, -1)),
		"T8b has_tile((-1,-1)) == false")
	_assert(not grid.is_walkable(Vector2i(-1, -1)),
		"T8c is_walkable((-1,-1)) == false")

	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass_test(msg)
	else:
		_fail_test(msg)


func _pass_test(msg: String) -> void:
	_pass += 1
	print("  [PASS] %s" % msg)


func _fail_test(msg: String) -> void:
	_fail += 1
	print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_grid_system_init] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
