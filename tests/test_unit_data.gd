extends SceneTree
## test_unit_data —— S3 UnitData Resource 单测
##
## 用法：godot --headless --path . --script tests/test_unit_data.gd
##
## 覆盖：
##   T1  5 个 .tres 均可加载，且为 UnitData 实例
##   T2  核心资源字段对齐 v2 属性结构
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
		"unit_name": "徐凤年", "constitution": 7, "strength": 8, "agility": 8, "move_range": 4,
		"weapon_type": 1, "sf_contains": "warrior", "is_enemy": false,
	})
	_check("jiang_ni", {
		"unit_name": "姜泥", "constitution": 5, "strength": 4, "agility": 7, "move_range": 5,
		"weapon_type": 3, "sf_contains": "monk", "is_enemy": false,
	})
	_check("li_chungang", {
		"unit_name": "李淳罡", "constitution": 7, "strength": 9, "agility": 8, "move_range": 3,
		"weapon_type": 2, "sf_contains": "warrior", "is_enemy": false,
	})
	_check("enemy_soldier", {
		"unit_name": "北莽普通兵", "constitution": 5, "strength": 5, "agility": 4, "move_range": 3,
		"weapon_type": 3, "sf_contains": "warrior", "is_enemy": true,
	})
	_check("yang_yuanzan", {
		"unit_name": "杨元赞", "constitution": 9, "strength": 9, "agility": 6, "move_range": 3,
		"weapon_type": 1, "sf_contains": "warrior", "is_enemy": true,
	})

	_finish()


func _check(id: String, expected: Dictionary) -> void:
	var u: UnitData = load("res://resources/data/units/%s.tres" % id) as UnitData
	_assert(u != null, "%s load 非 null" % id)
	if u == null:
		return
	_assert(u.unit_name == expected["unit_name"],
		"%s unit_name=%s (exp=%s)" % [id, u.unit_name, expected["unit_name"]])
	_assert(u.attributes != null, "%s attributes 非 null" % id)
	if u.attributes == null:
		return
	_assert(u.attributes.constitution == expected["constitution"],
		"%s constitution=%d (exp=%d)" % [id, u.attributes.constitution, expected["constitution"]])
	_assert(u.attributes.strength == expected["strength"],
		"%s strength=%d (exp=%d)" % [id, u.attributes.strength, expected["strength"]])
	_assert(u.attributes.agility == expected["agility"],
		"%s agility=%d (exp=%d)" % [id, u.attributes.agility, expected["agility"]])
	_assert(u.attributes.move_range == expected["move_range"],
		"%s move_range=%d (exp=%d)" % [id, u.attributes.move_range, expected["move_range"]])
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
