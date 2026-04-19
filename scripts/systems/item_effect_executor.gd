extends RefCounted
class_name ItemEffectExecutor

const ItemData = preload("res://scripts/core/item_data.gd")


static func apply_effect(item, target, caster = null) -> bool:
	if item == null or target == null:
		return false
	if item.category != ItemData.ItemCategory.CONSUMABLE:
		printerr("[ItemEffectExecutor] item %s is not consumable" % item.id)
		return false

	match item.effect_type:
		ItemData.ConsumableEffectType.HEAL_HP:
			if target.current_hp >= target.max_hp:
				return false
			target.heal(int(round(item.effect_value)))
			return target.current_hp > 0
		ItemData.ConsumableEffectType.HEAL_MP:
			var prev_mp: int = target.current_mp
			target.restore_mp(int(round(item.effect_value)))
			return target.current_mp > prev_mp
		ItemData.ConsumableEffectType.BUFF:
			var source_id: String = item.id if not item.id.is_empty() else "item_buff"
			var modifier_dict: Dictionary = {}
			if not item.effect_target_stat.is_empty():
				modifier_dict[item.effect_target_stat] = int(round(item.effect_value))
			var turns: int = max(item.effect_duration, 1)
			target.add_status_effect(source_id, modifier_dict, turns)
			return true
		ItemData.ConsumableEffectType.DISPEL:
			return _remove_debuffs(item, target, caster)

	return false


static func _remove_debuffs(item, target, _caster) -> bool:
	var remaining_effects: Array = []
	var removed: bool = false

	for effect in target.status_effects:
		if effect == null:
			continue
		if _is_debuff(effect):
			removed = true
			continue
		remaining_effects.append(effect)

	target.status_effects.clear()
	for effect in remaining_effects:
		target.status_effects.append(effect)
	if removed:
		target._refresh_derived_resources()
		return true

	return false


static func _is_debuff(effect) -> bool:
	if effect == null:
		return false
	for value in effect.modifier_dict.values():
		if int(value) < 0:
			return true
	return false
