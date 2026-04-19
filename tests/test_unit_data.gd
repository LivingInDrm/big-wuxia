extends SceneTree
## test_unit_data —— S3 UnitData Resource 单测
##
## 用法：godot --headless --path . --script tests/test_unit_data.gd
##
## 覆盖：
##   T1  4 个 .tres 均可加载，且为 UnitData 实例
##   T2  核心字段对齐 docs/design/01-game-design.md §8
##   T3  weapon_type 枚举值正确
##   T4  sprite_frames 非 null（warrior_sf / monk_sf 正确映射）
##
## 退出码：0 = 全部通过，1 = 有失败

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_unit_data] ==== BEGIN ====")

	# T1+T2+T3+T4 按单位逐项校验
	_check("xu_fengnian", {
		"unit_name": "徐凤年", "max_hp": 28, "atk": 8, "def": 5, "spd": 6, "mov": 4,
		"weapon_type": 1, "sf_contains": "warrior", "is_enemy": false,
	})
	_check("jiang_ni", {
		"unit_name": "姜泥", "max_hp": 18, "atk": 3, "def": 3, "spd": 8, "mov": 5,
		"weapon_type": 3, "sf_contains": "monk", "is_enemy": false,
	})
	_check("li_chungang", {
		"unit_name": "李淳罡", "max_hp": 22, "atk": 12, "def": 4, "spd": 5, "mov": 3,
		"weapon_type": 2, "sf_contains": "warrior", "is_enemy": false,
	})
	_check("enemy_soldier", {
		"unit_name": "北莽普通兵", "max_hp": 12, "atk": 4, "def": 2, "spd": 4, "mov": 3,
		"weapon_type": 0, "sf_contains": "warrior", "is_enemy": true,
	})

	_finish()


func _check(id: String, expected: Dictionary) -> void:
	var u: UnitData = load("res://resources/data/units/%s.tres" % id) as UnitData
	_assert(u != null, "%s load 非 null" % id)
	if u == null:
		return
	_assert(u.unit_name == expected["unit_name"],
		"%s unit_name=%s (exp=%s)" % [id, u.unit_name, expected["unit_name"]])
	_assert(u.max_hp == expected["max_hp"],
		"%s max_hp=%d (exp=%d)" % [id, u.max_hp, expected["max_hp"]])
	_assert(u.atk == expected["atk"], "%s atk=%d (exp=%d)" % [id, u.atk, expected["atk"]])
	_assert(u.def == expected["def"], "%s def=%d (exp=%d)" % [id, u.def, expected["def"]])
	_assert(u.spd == expected["spd"], "%s spd=%d (exp=%d)" % [id, u.spd, expected["spd"]])
	_assert(u.mov == expected["mov"], "%s mov=%d (exp=%d)" % [id, u.mov, expected["mov"]])
	_assert(u.weapon_type == expected["weapon_type"],
		"%s weapon_type=%d (exp=%d)" % [id, u.weapon_type, expected["weapon_type"]])
	_assert(u.is_enemy == expected["is_enemy"],
		"%s is_enemy=%s (exp=%s)" % [id, u.is_enemy, expected["is_enemy"]])
	_assert(u.sprite_frames != null, "%s sprite_frames 非 null" % id)
	if u.sprite_frames != null:
		var path: String = u.sprite_frames.resource_path
		_assert(path.contains(expected["sf_contains"]),
			"%s sprite_frames 路径包含 %s (实际=%s)" % [id, expected["sf_contains"], path])


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_unit_data] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
