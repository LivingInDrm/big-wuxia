extends SceneTree

const LootTable = preload("res://scripts/core/loot_table.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_loot] ==== BEGIN ====")

	_test_guaranteed_and_zero_weight()
	_test_count_range()
	_test_seeded_determinism()

	_finish()


func _test_guaranteed_and_zero_weight() -> void:
	var loot_table := LootTable.new()
	loot_table.entries = [
		{"item_id": "jinchuang_yao", "weight": 100, "min": 1, "max": 1},
		{"item_id": "misc_caoyao", "weight": 0, "min": 1, "max": 2},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var drops := loot_table.roll_with_rng(rng)

	_assert(drops.size() == 1, "T1a 100% 与 0% 混合时只掉 1 条")
	if drops.size() == 1:
		_assert(String(drops[0].get("item_id", "")) == "jinchuang_yao", "T1b 100% 条目必落")
		_assert(int(drops[0].get("count", 0)) == 1, "T1c 固定区间掉落 count=1")


func _test_count_range() -> void:
	var loot_table := LootTable.new()
	loot_table.entries = [
		{"item_id": "jinchuang_yao", "weight": 100, "min": 2, "max": 4},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 19

	for roll_index in 5:
		var drops := loot_table.roll_with_rng(rng)
		_assert(drops.size() == 1, "T2.%da 每次 roll 都会掉落" % [roll_index + 1])
		if drops.size() == 1:
			var count := int(drops[0].get("count", 0))
			_assert(count >= 2 and count <= 4, "T2.%db count 落在 [2, 4]" % [roll_index + 1])


func _test_seeded_determinism() -> void:
	var loot_table := LootTable.new()
	loot_table.entries = [
		{"item_id": "jinchuang_yao", "weight": 60, "min": 1, "max": 2},
		{"item_id": "misc_caoyao", "weight": 40, "min": 1, "max": 3},
	]
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 20260419
	rng_b.seed = 20260419

	var seq_a: Array = []
	var seq_b: Array = []
	for _i in 6:
		seq_a.append(loot_table.roll_with_rng(rng_a))
		seq_b.append(loot_table.roll_with_rng(rng_b))

	_assert(seq_a == seq_b, "T3a 相同 seed 的多次 roll 序列完全一致")


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_loot] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
