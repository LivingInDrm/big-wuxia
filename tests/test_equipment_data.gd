extends SceneTree

const ItemData = preload("res://scripts/core/item_data.gd")
const IRON_BLADE = preload("res://resources/data/items/iron_blade.tres")
const PLAIN_SWORD = preload("res://resources/data/items/plain_sword.tres")
const LEATHER_ARMOR = preload("res://resources/data/items/leather_armor.tres")
const CLOTH_ROBE = preload("res://resources/data/items/cloth_robe.tres")
const JADE_PENDANT = preload("res://resources/data/items/jade_pendant.tres")
const HEAL_AMULET = preload("res://resources/data/items/heal_amulet.tres")
const SWIFT_BOOTS = preload("res://resources/data/items/swift_boots.tres")
const JINCHUANG_YAO = preload("res://resources/data/items/jinchuang_yao.tres")
const JIEDU_DAN = preload("res://resources/data/items/jiedu_dan.tres")
const NEILI_DAN = preload("res://resources/data/items/neili_dan.tres")
const CHUNQIU_DAOFA = preload("res://resources/data/items/chunqiu_daofa.tres")
const YISHU_MIJI = preload("res://resources/data/items/yishu_miji.tres")
const LAO_HUANG_XINWU = preload("res://resources/data/items/lao_huang_xinwu.tres")
const MISC_CAOYAO = preload("res://resources/data/items/misc_caoyao.tres")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_equipment_data] ==== BEGIN ====")

	_check_equipment(IRON_BLADE, ItemData.EquipSlot.WEAPON, "blade", {"attack": 5})
	_check_equipment(PLAIN_SWORD, ItemData.EquipSlot.WEAPON, "sword", {"attack": 4})
	_check_equipment(LEATHER_ARMOR, ItemData.EquipSlot.ARMOR, "", {"defense": 3, "max_hp": 10})
	_check_equipment(CLOTH_ROBE, ItemData.EquipSlot.ARMOR, "", {"defense": 2, "max_hp": 5})
	_check_equipment(JADE_PENDANT, ItemData.EquipSlot.ACCESSORY_1, "", {"max_hp": 20})
	_check_equipment(HEAL_AMULET, ItemData.EquipSlot.ACCESSORY_1, "", {"max_hp": 15, "max_mp": 10})
	_check_equipment(SWIFT_BOOTS, ItemData.EquipSlot.ACCESSORY_2, "", {"qinggong": 1, "qi_speed": 1})

	_check_non_equipment(JINCHUANG_YAO)
	_check_non_equipment(JIEDU_DAN)
	_check_non_equipment(NEILI_DAN)
	_check_non_equipment(CHUNQIU_DAOFA)
	_check_non_equipment(YISHU_MIJI)
	_check_non_equipment(LAO_HUANG_XINWU)
	_check_non_equipment(MISC_CAOYAO)

	_finish()


func _check_equipment(item: ItemData, expected_slot: int, expected_weapon_type: String, expected_stats: Dictionary) -> void:
	_assert(item != null, "%s load 非 null" % item.id)
	if item == null:
		return

	_assert(item.category == ItemData.ItemCategory.EQUIPMENT, "%s category=EQUIPMENT" % item.id)
	_assert(item.equip_slot == expected_slot, "%s equip_slot=%d (exp=%d)" % [item.id, item.equip_slot, expected_slot])
	_assert(item.weapon_type == expected_weapon_type,
		"%s weapon_type=%s (exp=%s)" % [item.id, item.weapon_type, expected_weapon_type])
	_assert(_has_only_allowed_stat_keys(item.stat_modifiers), "%s stat_modifiers 键符合规范" % item.id)
	_assert(item.stat_modifiers.size() == expected_stats.size(),
		"%s stat_modifiers 键数量=%d (exp=%d)" % [item.id, item.stat_modifiers.size(), expected_stats.size()])

	for key in expected_stats.keys():
		_assert(int(item.stat_modifiers.get(key, -999)) == int(expected_stats[key]),
			"%s stat_modifiers.%s=%s (exp=%s)" % [item.id, key, item.stat_modifiers.get(key, null), expected_stats[key]])


func _check_non_equipment(item: ItemData) -> void:
	_assert(item != null, "非装备 load 非 null")
	if item == null:
		return

	_assert(item.category != ItemData.ItemCategory.EQUIPMENT, "%s category 非 EQUIPMENT" % item.id)
	_assert(item.equip_slot == ItemData.EquipSlot.NONE, "%s equip_slot=NONE" % item.id)
	_assert(item.weapon_type == "", "%s weapon_type 为空" % item.id)


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


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_equipment_data] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
