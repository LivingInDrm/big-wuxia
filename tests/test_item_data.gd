extends SceneTree

const ITEM_DIR := "res://resources/data/items/"
const ItemData = preload("res://scripts/core/item_data.gd")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_item_data] ==== BEGIN ====")

	_check("jinchuang_yao", {
		"category": ItemData.ItemCategory.CONSUMABLE,
		"stackable": true,
		"max_stack": 99,
		"effect_type": ItemData.ConsumableEffectType.HEAL_HP,
		"effect_value": 30.0,
		"icon_contains": "Icon_04.png",
	})
	_check("jiedu_dan", {
		"category": ItemData.ItemCategory.CONSUMABLE,
		"stackable": true,
		"max_stack": 99,
		"effect_type": ItemData.ConsumableEffectType.DISPEL,
		"effect_target_stat": "poison",
		"icon_contains": "Icon_07.png",
	})
	_check("neili_dan", {
		"category": ItemData.ItemCategory.CONSUMABLE,
		"stackable": true,
		"max_stack": 99,
		"effect_type": ItemData.ConsumableEffectType.HEAL_MP,
		"effect_value": 20.0,
		"icon_contains": "Icon_07.png",
	})
	_check("iron_blade", {
		"category": ItemData.ItemCategory.EQUIPMENT,
		"stackable": false,
		"max_stack": 1,
		"equip_slot": "weapon",
		"attack": 5,
		"weapon_type": "blade",
		"icon_contains": "Icon_05.png",
	})
	_check("leather_armor", {
		"category": ItemData.ItemCategory.EQUIPMENT,
		"stackable": false,
		"max_stack": 1,
		"equip_slot": "armor",
		"defense": 3,
		"icon_contains": "Icon_06.png",
	})
	_check("jade_pendant", {
		"category": ItemData.ItemCategory.EQUIPMENT,
		"stackable": false,
		"max_stack": 1,
		"equip_slot": "accessory",
		"hp": 20,
		"icon_contains": "Icon_11.png",
	})
	_check("chunqiu_daofa", {
		"category": ItemData.ItemCategory.MANUAL,
		"stackable": false,
		"max_stack": 1,
		"teaches_specialty": "blade",
		"teaches_level": 1,
		"icon_contains": "Icon_05.png",
	})
	_check("yishu_miji", {
		"category": ItemData.ItemCategory.MANUAL,
		"stackable": false,
		"max_stack": 1,
		"teaches_specialty": "medicine",
		"teaches_level": 1,
		"icon_contains": "Icon_11.png",
	})
	_check("lao_huang_xinwu", {
		"category": ItemData.ItemCategory.QUEST,
		"stackable": false,
		"max_stack": 1,
		"droppable": false,
		"quest_flag": "lao_huang_token",
		"icon_contains": "Icon_08.png",
	})
	_check("misc_caoyao", {
		"category": ItemData.ItemCategory.MISC,
		"stackable": true,
		"max_stack": 99,
		"icon_contains": "Icon_01.png",
	})

	_finish()


func _check(item_id: String, expected: Dictionary) -> void:
	var item := load("%s%s.tres" % [ITEM_DIR, item_id]) as ItemData
	_assert(item != null, "%s load 非 null" % item_id)
	if item == null:
		return

	_assert(item.id == item_id, "%s id=%s" % [item_id, item.id])
	_assert(item.category == expected["category"],
		"%s category=%d (exp=%d)" % [item_id, item.category, expected["category"]])
	_assert(item.stackable == expected["stackable"],
		"%s stackable=%s (exp=%s)" % [item_id, item.stackable, expected["stackable"]])
	_assert(item.max_stack == expected["max_stack"],
		"%s max_stack=%d (exp=%d)" % [item_id, item.max_stack, expected["max_stack"]])
	_assert(item.icon != null, "%s icon 非 null" % item_id)
	if item.icon != null:
		_assert(item.icon.resource_path.contains(expected["icon_contains"]),
			"%s icon 路径包含 %s (实际=%s)" % [item_id, expected["icon_contains"], item.icon.resource_path])

	match item.category:
		ItemData.ItemCategory.CONSUMABLE:
			_assert(item.effect_type == expected["effect_type"],
				"%s effect_type=%d (exp=%d)" % [item_id, item.effect_type, expected["effect_type"]])
			if expected.has("effect_value"):
				_assert(is_equal_approx(item.effect_value, expected["effect_value"]),
					"%s effect_value=%.1f (exp=%.1f)" % [item_id, item.effect_value, expected["effect_value"]])
			if expected.has("effect_target_stat"):
				_assert(item.effect_target_stat == expected["effect_target_stat"],
					"%s effect_target_stat=%s (exp=%s)" % [item_id, item.effect_target_stat, expected["effect_target_stat"]])
		ItemData.ItemCategory.EQUIPMENT:
			_assert(item.equip_slot == expected["equip_slot"],
				"%s equip_slot=%s (exp=%s)" % [item_id, item.equip_slot, expected["equip_slot"]])
			_assert(item.enhancement_level == 0, "%s enhancement_level=0" % item_id)
			if expected.has("attack"):
				_assert(int(item.stat_modifiers.get("attack", -1)) == expected["attack"],
					"%s stat_modifiers.attack=%s (exp=%s)" % [item_id, item.stat_modifiers.get("attack", null), expected["attack"]])
			if expected.has("defense"):
				_assert(int(item.stat_modifiers.get("defense", -1)) == expected["defense"],
					"%s stat_modifiers.defense=%s (exp=%s)" % [item_id, item.stat_modifiers.get("defense", null), expected["defense"]])
			if expected.has("hp"):
				_assert(int(item.stat_modifiers.get("hp", -1)) == expected["hp"],
					"%s stat_modifiers.hp=%s (exp=%s)" % [item_id, item.stat_modifiers.get("hp", null), expected["hp"]])
			if expected.has("weapon_type"):
				_assert(String(item.stat_modifiers.get("weapon_type", "")) == expected["weapon_type"],
					"%s stat_modifiers.weapon_type=%s (exp=%s)" % [item_id, item.stat_modifiers.get("weapon_type", ""), expected["weapon_type"]])
		ItemData.ItemCategory.MANUAL:
			_assert(item.teaches_specialty == expected["teaches_specialty"],
				"%s teaches_specialty=%s (exp=%s)" % [item_id, item.teaches_specialty, expected["teaches_specialty"]])
			_assert(item.teaches_level == expected["teaches_level"],
				"%s teaches_level=%d (exp=%d)" % [item_id, item.teaches_level, expected["teaches_level"]])
		ItemData.ItemCategory.QUEST:
			_assert(item.droppable == expected["droppable"],
				"%s droppable=%s (exp=%s)" % [item_id, item.droppable, expected["droppable"]])
			_assert(item.quest_flag == expected["quest_flag"],
				"%s quest_flag=%s (exp=%s)" % [item_id, item.quest_flag, expected["quest_flag"]])


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_item_data] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
