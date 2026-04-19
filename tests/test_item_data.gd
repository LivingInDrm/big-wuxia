extends SceneTree

const ITEM_DIR := "res://resources/data/items/"
const ItemData = preload("res://scripts/core/item_data.gd")
const JINCHUANG_YAO = preload("res://resources/data/items/jinchuang_yao.tres")
const JIEDU_DAN = preload("res://resources/data/items/jiedu_dan.tres")
const NEILI_DAN = preload("res://resources/data/items/neili_dan.tres")
const IRON_BLADE = preload("res://resources/data/items/iron_blade.tres")
const LEATHER_ARMOR = preload("res://resources/data/items/leather_armor.tres")
const JADE_PENDANT = preload("res://resources/data/items/jade_pendant.tres")
const CHUNQIU_DAOFA = preload("res://resources/data/items/chunqiu_daofa.tres")
const YISHU_MIJI = preload("res://resources/data/items/yishu_miji.tres")
const LAO_HUANG_XINWU = preload("res://resources/data/items/lao_huang_xinwu.tres")
const MISC_CAOYAO = preload("res://resources/data/items/misc_caoyao.tres")

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
		"equip_slot": ItemData.EquipSlot.WEAPON,
		"attack": 5,
		"weapon_type": "blade",
		"icon_contains": "Icon_05.png",
	})
	_check("leather_armor", {
		"category": ItemData.ItemCategory.EQUIPMENT,
		"stackable": false,
		"max_stack": 1,
		"equip_slot": ItemData.EquipSlot.ARMOR,
		"defense": 3,
		"max_hp": 10,
		"icon_contains": "Icon_06.png",
	})
	_check("jade_pendant", {
		"category": ItemData.ItemCategory.EQUIPMENT,
		"stackable": false,
		"max_stack": 1,
		"equip_slot": ItemData.EquipSlot.ACCESSORY_1,
		"max_hp": 20,
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
	var item := _load_item(item_id)
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
				"%s equip_slot=%d (exp=%d)" % [item_id, item.equip_slot, expected["equip_slot"]])
			_assert(item.enhancement_level == 0, "%s enhancement_level=0" % item_id)
			_assert(_has_only_allowed_stat_keys(item.stat_modifiers),
				"%s stat_modifiers 键符合规范" % item_id)
			if expected.has("attack"):
				_assert(int(item.stat_modifiers.get("attack", -1)) == expected["attack"],
					"%s stat_modifiers.attack=%s (exp=%s)" % [item_id, item.stat_modifiers.get("attack", null), expected["attack"]])
			if expected.has("defense"):
				_assert(int(item.stat_modifiers.get("defense", -1)) == expected["defense"],
					"%s stat_modifiers.defense=%s (exp=%s)" % [item_id, item.stat_modifiers.get("defense", null), expected["defense"]])
			if expected.has("max_hp"):
				_assert(int(item.stat_modifiers.get("max_hp", -1)) == expected["max_hp"],
					"%s stat_modifiers.max_hp=%s (exp=%s)" % [item_id, item.stat_modifiers.get("max_hp", null), expected["max_hp"]])
			if expected.has("weapon_type"):
				_assert(item.weapon_type == expected["weapon_type"],
					"%s weapon_type=%s (exp=%s)" % [item_id, item.weapon_type, expected["weapon_type"]])
				_assert(not item.stat_modifiers.has("weapon_type"),
					"%s stat_modifiers 不包含 weapon_type" % item_id)
			else:
				_assert(item.weapon_type == "", "%s weapon_type 为空" % item_id)
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


func _load_item(item_id: String) -> ItemData:
	match item_id:
		"jinchuang_yao":
			return JINCHUANG_YAO
		"jiedu_dan":
			return JIEDU_DAN
		"neili_dan":
			return NEILI_DAN
		"iron_blade":
			return IRON_BLADE
		"leather_armor":
			return LEATHER_ARMOR
		"jade_pendant":
			return JADE_PENDANT
		"chunqiu_daofa":
			return CHUNQIU_DAOFA
		"yishu_miji":
			return YISHU_MIJI
		"lao_huang_xinwu":
			return LAO_HUANG_XINWU
		"misc_caoyao":
			return MISC_CAOYAO
	return load("%s%s.tres" % [ITEM_DIR, item_id]) as ItemData


func _has_only_allowed_stat_keys(stat_modifiers: Dictionary) -> bool:
	var allowed := {
		"attack": true,
		"defense": true,
		"qinggong": true,
		"qi_speed": true,
		"max_hp": true,
		"max_mp": true,
	}
	for key in stat_modifiers.keys():
		if not allowed.has(String(key)):
			return false
	return true


func _finish() -> void:
	print("[test_item_data] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
