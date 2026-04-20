extends Node
## GameState — 游戏全局状态（Autoload）
##
## 职责：管理当前关卡、角色选择、通关进度。
## 依赖：无。
## 参考：docs/design/02-architecture.md §3.1

const Inventory = preload("res://scripts/core/inventory.gd")
const ItemData = preload("res://scripts/core/item_data.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")
const UnitData = preload("res://scripts/core/unit_data.gd")
const WeaponTypes = preload("res://scripts/core/weapon_types.gd")
const STARTING_EQUIPMENT := {
	"xu_fengnian": {
		"item_id": "iron_blade",
		"slot": ItemData.EquipSlot.WEAPON,
	},
	"li_chungang": {
		"item_id": "plain_sword",
		"slot": ItemData.EquipSlot.WEAPON,
	},
	"jiang_ni": {
		"item_id": "cloth_robe",
		"slot": ItemData.EquipSlot.ARMOR,
	},
}
const PLAYER_CHAR_IDS := [
	"xu_fengnian",
	"jiang_ni",
	"li_chungang",
]

signal level_completed(level_name: String)
signal equipment_changed(char_id: String)

var current_level: String = ""
var selected_characters: Array[String] = []
var completed_levels: Array[String] = []
var dialogue_flags: Dictionary = {}
var location: String = ""
var overworld_player_position: Vector2 = Vector2.ZERO
var return_context: Dictionary = {}
var inventory: Inventory
var equipped: Dictionary = {}


func _init() -> void:
	reset()


func start_level(level_name: String) -> void:
	current_level = level_name


func complete_level(level_name: String) -> void:
	if level_name not in completed_levels:
		completed_levels.append(level_name)
	level_completed.emit(level_name)


func is_level_completed(level_name: String) -> bool:
	return level_name in completed_levels


func set_flag(key: String, value: Variant = true) -> void:
	dialogue_flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	return dialogue_flags.get(key, default)


func has_flag(key: String) -> bool:
	return dialogue_flags.has(key)


func clear_flag(key: String) -> void:
	dialogue_flags.erase(key)


func begin_battle_from(context: Dictionary) -> void:
	return_context = context.duplicate(true)
	_capture_current_world_position()
	var level_id := String(return_context.get("level_id", ""))
	if not level_id.is_empty():
		current_level = level_id
	return_context["from_battle"] = true
	location = "battle"


func resume_from_battle(result: String) -> String:
	if return_context.is_empty():
		return ""
	var scene_path := _resolve_return_scene_path()
	if not scene_path.is_empty():
		return_context["battle_result"] = result
	location = "poi:%s" % String(return_context.get("return_to_poi", return_context.get("poi_id", "")))
	return scene_path


func abort_battle() -> String:
	if return_context.is_empty():
		return ""
	return_context.erase("on_victory_dialogue")
	return_context.erase("on_defeat_dialogue")
	return resume_from_battle("defeat")


func equip(char_id: String, slot: ItemData.EquipSlot, item_instance: ItemInstance) -> bool:
	if item_instance == null or item_instance.item_data == null:
		return false
	if slot != item_instance.item_data.equip_slot:
		return false
	if slot == ItemData.EquipSlot.WEAPON and not _weapon_type_matches(char_id, item_instance.item_data):
		return false
	if not inventory.remove_instance(item_instance.instance_id):
		return false

	var char_equipped := _ensure_equipped_slots(char_id)
	var previous := char_equipped.get(slot) as ItemInstance
	if previous != null:
		inventory.unique_items.append(previous)
	char_equipped[slot] = item_instance
	equipped[char_id] = char_equipped
	equipment_changed.emit(char_id)
	return true


func unequip(char_id: String, slot: ItemData.EquipSlot) -> ItemInstance:
	var char_equipped := _ensure_equipped_slots(char_id)
	var previous := char_equipped.get(slot) as ItemInstance
	if previous == null:
		return null

	inventory.unique_items.append(previous)
	char_equipped[slot] = null
	equipped[char_id] = char_equipped
	equipment_changed.emit(char_id)
	return previous


func get_equipped_items(char_id: String) -> Dictionary:
	return _ensure_equipped_slots(char_id).duplicate(false)


func reset() -> void:
	current_level = ""
	selected_characters = []
	completed_levels = []
	dialogue_flags = {}
	location = ""
	overworld_player_position = Vector2.ZERO
	return_context = {}
	inventory = Inventory.new()
	equipped = {}
	for char_id in PLAYER_CHAR_IDS:
		var unit_data := _load_unit_data(char_id)
		if unit_data != null and not unit_data.unit_id.is_empty():
			equipped[unit_data.unit_id] = _create_empty_slots()
	_init_starting_equipment()


func _capture_current_world_position() -> void:
	if location != "overworld" and not location.begins_with("poi:"):
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var player := tree.current_scene.get_node_or_null("Player") as Node2D
	if player != null:
		overworld_player_position = player.global_position


func _resolve_return_scene_path() -> String:
	var scene_path := String(return_context.get("return_scene", return_context.get("scene", "")))
	if not scene_path.is_empty():
		return scene_path
	var poi_id := String(return_context.get("return_to_poi", return_context.get("poi_id", "")))
	if poi_id.is_empty():
		return ""
	var registry := get_node_or_null("/root/POIRegistry")
	if registry == null:
		return ""
	var poi_data: POIData = registry.get_data(poi_id) as POIData
	if poi_data == null:
		return ""
	return poi_data.scene_path


func _ensure_equipped_slots(char_id: String) -> Dictionary:
	if not equipped.has(char_id):
		equipped[char_id] = _create_empty_slots()
	return equipped[char_id] as Dictionary


func _create_empty_slots() -> Dictionary:
	return {
		ItemData.EquipSlot.WEAPON: null,
		ItemData.EquipSlot.ARMOR: null,
		ItemData.EquipSlot.ACCESSORY_1: null,
		ItemData.EquipSlot.ACCESSORY_2: null,
	}


func _load_unit_data(char_id: String) -> UnitData:
	# 优先走 UnitRegistry 单例；_init 阶段自身尚未入树，直接回退到 load。
	if is_inside_tree():
		var registry := get_node_or_null("/root/UnitRegistry")
		if registry != null:
			return registry.get_data(char_id)
	var path := "res://resources/data/units/%s.tres" % char_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as UnitData


func _init_starting_equipment() -> void:
	for char_id in STARTING_EQUIPMENT.keys():
		var config := STARTING_EQUIPMENT[char_id] as Dictionary
		if config == null:
			continue
		var item_id := String(config.get("item_id", ""))
		var slot := config.get("slot", ItemData.EquipSlot.WEAPON) as ItemData.EquipSlot
		if item_id.is_empty():
			continue
		inventory.add(item_id)
		var item_instance := _find_inventory_item(item_id)
		if item_instance == null:
			continue
		equip(String(char_id), slot, item_instance)


func _weapon_type_matches(char_id: String, item_data: ItemData) -> bool:
	var unit_data := _load_unit_data(char_id)
	if unit_data == null:
		return false
	return _weapon_type_to_string(unit_data.weapon_type) == item_data.weapon_type.to_lower()


func _find_inventory_item(item_id: String) -> ItemInstance:
	for entry in inventory.unique_items:
		var item_instance := entry as ItemInstance
		if item_instance != null and item_instance.item_data != null and item_instance.item_data.id == item_id:
			return item_instance
	return null


func _weapon_type_to_string(weapon_type: WeaponTypes.Type) -> String:
	match int(weapon_type):
		WeaponTypes.Type.BLADE:
			return "blade"
		WeaponTypes.Type.SWORD:
			return "sword"
		WeaponTypes.Type.FIST:
			return "fist"
		WeaponTypes.Type.INNER:
			return "inner"
		_:
			return ""
