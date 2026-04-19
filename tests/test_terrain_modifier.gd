extends SceneTree

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_terrain_modifier] ==== BEGIN ====")
	CombatSystem.reset_roll_seed(4)

	var packed := load("res://scenes/unit/unit.tscn") as PackedScene
	var attacker: Unit = packed.instantiate()
	var defender: Unit = packed.instantiate()
	attacker.setup(load("res://resources/data/units/xu_fengnian.tres"), Vector2i(0, 0))
	defender.setup(load("res://resources/data/units/enemy_soldier.tres"), Vector2i(1, 0))
	root.add_child(attacker)
	root.add_child(defender)
	await process_frame

	var grid := GridSystem.new()
	root.add_child(grid)
	var grass := load("res://resources/data/tiles/grass.tres") as TerrainTileData
	var forest := TerrainTileData.new()
	forest.tile_id = "forest_mock"
	forest.display_name = "Mock Forest"
	forest.movement_cost = 2
	forest.dodge_bonus = 0.20
	grid.tiles[Vector2i(0, 0)] = GridTile.new(Vector2i(0, 0), grass)
	grid.tiles[Vector2i(1, 0)] = GridTile.new(Vector2i(1, 0), forest)
	grid.tiles[Vector2i(0, 0)].occupant = attacker
	grid.tiles[Vector2i(1, 0)].occupant = defender

	var hit_count := 0
	for _i in 100:
		var result: Dictionary = CombatSystem.calculate_attack(attacker, defender, grid)
		if result.hit:
			hit_count += 1

	_assert(hit_count >= 65 and hit_count <= 85,
		"T1 森林闪避后 100 次命中=%d，位于 65-85" % hit_count)

	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_terrain_modifier] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
