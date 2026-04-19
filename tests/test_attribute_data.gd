extends SceneTree
## test_attribute_data —— v2 P1 step-1-1 属性数据层单测
##
## 用法：godot --headless --path . --script tests/test_attribute_data.gd
##
## 覆盖：
##   T1  5 个 .tres 均可加载，且为 UnitData 实例
##   T2  每个单位都有 attributes 子资源
##   T3  A 资质与 B 资源基础值符合 step-1-1 推荐表
##   T4  占位 max_hp 公式值正确（base_hp + constitution * 10 + 1 * 5）
##
## 退出码：0 = 全部通过，1 = 有失败

const AttributeSet = preload("res://scripts/core/attribute_set.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_attribute_data] ==== BEGIN ====")

	_check("xu_fengnian", {
		"constitution": 7, "strength": 8, "agility": 8, "insight": 6, "fortune": 9,
		"base_hp": 30, "base_mp": 10, "derived_max_hp": 105,
	})
	_check("jiang_ni", {
		"constitution": 5, "strength": 4, "agility": 7, "insight": 8, "fortune": 7,
		"base_hp": 25, "base_mp": 15, "derived_max_hp": 80,
	})
	_check("li_chungang", {
		"constitution": 7, "strength": 9, "agility": 8, "insight": 10, "fortune": 4,
		"base_hp": 30, "base_mp": 10, "derived_max_hp": 105,
	})
	_check("enemy_soldier", {
		"constitution": 5, "strength": 5, "agility": 4, "insight": 3, "fortune": 2,
		"base_hp": 25, "base_mp": 5, "derived_max_hp": 80,
	})
	_check("yang_yuanzan", {
		"constitution": 9, "strength": 9, "agility": 6, "insight": 5, "fortune": 3,
		"base_hp": 40, "base_mp": 10, "derived_max_hp": 135,
	})

	_finish()


func _check(id: String, expected: Dictionary) -> void:
	var unit_data := load("res://resources/data/units/%s.tres" % id) as UnitData
	_assert(unit_data != null, "%s load 非 null" % id)
	if unit_data == null:
		return

	var attributes: AttributeSet = unit_data.attributes
	_assert(attributes != null, "%s attributes 非 null" % id)
	if attributes == null:
		return

	_assert(attributes.constitution == expected["constitution"],
		"%s constitution=%d (exp=%d)" % [id, attributes.constitution, expected["constitution"]])
	_assert(attributes.strength == expected["strength"],
		"%s strength=%d (exp=%d)" % [id, attributes.strength, expected["strength"]])
	_assert(attributes.agility == expected["agility"],
		"%s agility=%d (exp=%d)" % [id, attributes.agility, expected["agility"]])
	_assert(attributes.insight == expected["insight"],
		"%s insight=%d (exp=%d)" % [id, attributes.insight, expected["insight"]])
	_assert(attributes.fortune == expected["fortune"],
		"%s fortune=%d (exp=%d)" % [id, attributes.fortune, expected["fortune"]])
	_assert(attributes.base_hp == expected["base_hp"],
		"%s base_hp=%d (exp=%d)" % [id, attributes.base_hp, expected["base_hp"]])
	_assert(attributes.base_mp == expected["base_mp"],
		"%s base_mp=%d (exp=%d)" % [id, attributes.base_mp, expected["base_mp"]])

	var derived_max_hp: int = attributes.base_hp + attributes.constitution * 10 + 1 * 5
	_assert(derived_max_hp == expected["derived_max_hp"],
		"%s derived_max_hp=%d (exp=%d)" % [id, derived_max_hp, expected["derived_max_hp"]])


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_attribute_data] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
