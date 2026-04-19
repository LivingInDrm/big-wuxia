extends SceneTree

const UNIT_SCENE = preload("res://scenes/unit/unit.tscn")
const ITEM_EFFECT_EXECUTOR = preload("res://scripts/systems/item_effect_executor.gd")
const ITEM_DATA_SCRIPT = preload("res://scripts/core/item_data.gd")
const ATTRIBUTE_RESOLVER = preload("res://scripts/systems/attribute_resolver.gd")
const STATUS_EFFECT_SCRIPT = preload("res://scripts/core/status_effect.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_item_effect] ==== BEGIN ====")

	await _test_heal_hp()
	await _test_heal_mp()
	_test_non_consumable_fails()
	await _test_buff_effect()
	await _test_dispel_effect()

	_finish()


func _test_heal_hp() -> void:
	var unit = await _spawn_unit("xu_fengnian")
	var item = load("res://resources/data/items/jinchuang_yao.tres") as Resource

	unit.current_hp = 10
	var applied: bool = ITEM_EFFECT_EXECUTOR.apply_effect(item, unit)

	_assert(applied, "T1a 金疮药对受伤单位 apply=true")
	_assert(unit.current_hp == 40, "T1b 金疮药恢复后 HP=40")

	unit.queue_free()
	await process_frame


func _test_heal_mp() -> void:
	var unit = await _spawn_unit("xu_fengnian")
	var item = load("res://resources/data/items/neili_dan.tres") as Resource

	unit.current_mp = 5
	var before_mp: int = unit.current_mp
	var applied: bool = ITEM_EFFECT_EXECUTOR.apply_effect(item, unit)

	_assert(applied, "T2a 内力丹 apply=true")
	_assert(unit.current_mp > before_mp, "T2b 内力丹使用后 MP 增加")

	unit.queue_free()
	await process_frame


func _test_non_consumable_fails() -> void:
	var unit = await _spawn_unit("xu_fengnian")
	var item = load("res://resources/data/items/lao_huang_xinwu.tres") as Resource

	var applied: bool = ITEM_EFFECT_EXECUTOR.apply_effect(item, unit)

	_assert(not applied, "T3a 任务物品 apply=false")

	unit.queue_free()


func _test_buff_effect() -> void:
	var unit = await _spawn_unit("xu_fengnian")
	var item = ITEM_DATA_SCRIPT.new()
	item.id = "test_attack_buff"
	item.category = ITEM_DATA_SCRIPT.ItemCategory.CONSUMABLE
	item.effect_type = ITEM_DATA_SCRIPT.ConsumableEffectType.BUFF
	item.effect_target_stat = "attack"
	item.effect_value = 3
	item.effect_duration = 2

	var base_attack: int = int(ATTRIBUTE_RESOLVER.get_attack(unit).get("total", -1))
	var applied: bool = ITEM_EFFECT_EXECUTOR.apply_effect(item, unit)
	var buffed_attack: int = int(ATTRIBUTE_RESOLVER.get_attack(unit).get("total", -1))

	_assert(applied, "T4a BUFF apply=true")
	_assert(unit.status_effects.size() == 1, "T4b BUFF 后 status_effects 长度+1")
	_assert(buffed_attack == base_attack + 3, "T4c attack resolver 增加 3")

	unit.queue_free()
	await process_frame


func _test_dispel_effect() -> void:
	var unit = await _spawn_unit("xu_fengnian")
	var dispel_item = load("res://resources/data/items/jiedu_dan.tres") as Resource

	unit.status_effects.append(STATUS_EFFECT_SCRIPT.new("poison_test", {"attack": -3}, 2))
	unit._refresh_derived_resources()
	var applied: bool = ITEM_EFFECT_EXECUTOR.apply_effect(dispel_item, unit)

	_assert(applied, "T5a DISPEL apply=true")
	_assert(unit.status_effects.is_empty(), "T5b DISPEL 清除负面 status")

	unit.queue_free()
	await process_frame


func _spawn_unit(unit_id: String):
	var data = load("res://resources/data/units/%s.tres" % unit_id) as Resource
	_assert(data != null, "%s data load 非 null" % unit_id)
	var unit = UNIT_SCENE.instantiate()
	unit.setup(data, Vector2i(1, 1))
	root.add_child(unit)
	await process_frame
	return unit


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_item_effect] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
