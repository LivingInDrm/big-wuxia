class_name AttributeResolver
extends RefCounted

const AttributeSet = preload("res://scripts/core/attribute_set.gd")
const WeaponTypes = preload("res://scripts/core/weapon_types.gd")


static func get_attack(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var base := 0
	var attribute := attrs.strength * 2
	var specialty := int(_get_specialty_for_weapon(unit) * 1.5)
	var equip := 0
	var technique := 0
	var status := _get_status_modifier(unit, "attack")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_defense(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var base := 0
	var attribute := int(attrs.constitution * 1.5)
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := _get_status_modifier(unit, "defense")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_qinggong(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var base := 0
	var attribute := attrs.agility
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := _get_status_modifier(unit, "qinggong")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_qi_speed(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var qinggong_total: int = int(get_qinggong(unit)["total"])
	var base := 0
	var attribute := int(attrs.agility * 0.5 + qinggong_total * 0.3)
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := _get_status_modifier(unit, "qi_speed")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_max_hp(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var base := attrs.base_hp + 1 * 5
	var attribute := attrs.constitution * 10
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := _get_status_modifier(unit, "max_hp")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_max_mp(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var base := attrs.base_mp
	var attribute := attrs.constitution * 2 + attrs.insight * 3
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := _get_status_modifier(unit, "max_mp")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_hit(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var base := 75
	var attribute := attrs.agility
	var specialty := int(_get_specialty_for_weapon(unit) * 0.5)
	var equip := 0
	var technique := 0
	var status := _get_status_modifier(unit, "hit")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_dodge(unit, terrain_dodge_bonus: int = 0) -> Dictionary:
	var attrs := _get_attributes(unit)
	var qinggong_total: int = int(get_qinggong(unit)["total"])
	var base := 5
	var attribute := int(attrs.agility * 0.5 + qinggong_total * 0.3)
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := terrain_dodge_bonus + _get_status_modifier(unit, "dodge")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_crit(unit) -> Dictionary:
	var base := 5
	var attribute := 0
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := _get_status_modifier(unit, "crit")
	return _build_result(base, attribute, specialty, equip, technique, status)


static func _build_result(base: int, attribute: int, specialty: int, equip: int,
		technique: int, status: int) -> Dictionary:
	var sources := {
		"base": base,
		"attribute": attribute,
		"specialty": specialty,
		"equip": equip,
		"technique": technique,
		"status": status,
	}
	return {
		"total": base + attribute + specialty + equip + technique + status,
		"sources": sources,
	}


static func _get_attributes(unit) -> AttributeSet:
	if unit != null and unit.unit_data != null and unit.unit_data.attributes != null:
		return unit.unit_data.attributes
	return AttributeSet.new()


static func _get_specialty_for_weapon(unit) -> int:
	if unit == null or unit.unit_data == null:
		return 0

	var attrs := _get_attributes(unit)
	match int(unit.unit_data.weapon_type):
		WeaponTypes.Type.BLADE:
			return attrs.spec_blade
		WeaponTypes.Type.SWORD:
			return attrs.spec_sword
		WeaponTypes.Type.FIST:
			return attrs.spec_fist
		_:
			return 0


static func _get_status_modifier(unit, key: String) -> int:
	if unit == null:
		return 0

	var total := 0
	var unit_traits = unit.get("traits")
	if unit_traits is Array:
		for trait_item in unit_traits:
			if trait_item == null:
				continue
			total += _get_modifier_value(trait_item.modifier_dict, key)
	var unit_status_effects = unit.get("status_effects")
	if unit_status_effects is Array:
		for effect in unit_status_effects:
			if effect == null:
				continue
			total += _get_modifier_value(effect.modifier_dict, key)
	return total


static func _get_modifier_value(modifier_dict: Dictionary, key: String) -> int:
	if modifier_dict == null:
		return 0
	return int(modifier_dict.get(key, 0))
