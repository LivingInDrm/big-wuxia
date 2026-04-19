extends Resource
class_name ItemData

enum ItemCategory {
	CONSUMABLE = 0,
	EQUIPMENT = 1,
	MANUAL = 2,
	QUEST = 3,
	MISC = 4,
}

enum ConsumableEffectType {
	HEAL_HP = 0,
	HEAL_MP = 1,
	BUFF = 2,
	DISPEL = 3,
}

enum EquipSlot {
	NONE = 0,
	WEAPON = 1,
	ARMOR = 2,
	ACCESSORY_1 = 3,
	ACCESSORY_2 = 4,
}

@export_group("Identity")
@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: ItemCategory = ItemCategory.MISC

@export_group("Stacking")
@export var stackable: bool = true
@export_range(1, 999, 1) var max_stack: int = 99
@export var droppable: bool = true

@export_group("Consumable")
@export var effect_type: ConsumableEffectType = ConsumableEffectType.HEAL_HP
@export var effect_value: float = 0.0
@export_range(0, 99, 1) var effect_duration: int = 0
@export var effect_target_stat: String = ""

@export_group("Equipment")
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var weapon_type: String = ""
@export var stat_modifiers: Dictionary = {}
@export var enhancement_level: int = 0

@export_group("Manual")
@export var teaches_specialty: String = ""
@export_range(0, 9, 1) var teaches_level: int = 0

@export_group("Quest")
@export var quest_flag: String = ""
