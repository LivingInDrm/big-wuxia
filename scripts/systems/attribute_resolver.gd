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
	var status := 0
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_defense(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var base := 0
	var attribute := int(attrs.constitution * 1.5)
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := 0
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_qinggong(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var base := 0
	var attribute := attrs.agility
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := 0
	return _build_result(base, attribute, specialty, equip, technique, status)


static func get_qi_speed(unit) -> Dictionary:
	var attrs := _get_attributes(unit)
	var qinggong_total: int = int(get_qinggong(unit)["total"])
	var base := 0
	var attribute := int(attrs.agility * 0.5 + qinggong_total * 0.3)
	var specialty := 0
	var equip := 0
	var technique := 0
	var status := 0
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
