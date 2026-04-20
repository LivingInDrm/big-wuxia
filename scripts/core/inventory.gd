extends RefCounted
class_name Inventory

const ItemData = preload("res://scripts/core/item_data.gd")
const ItemInstance = preload("res://scripts/core/item_instance.gd")

var stackable_items: Dictionary = {}
var unique_items: Array = []


func add(item_id: String, count: int = 1) -> void:
	if count <= 0:
		return

	var item_data := _load_item_data(item_id)
	if item_data == null:
		return

	if item_data.stackable:
		stackable_items[item_id] = int(stackable_items.get(item_id, 0)) + count
		return

	for _i in count:
		unique_items.append(ItemInstance.new(item_data))


func remove(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false

	var item_data := _load_item_data(item_id)
	if item_data == null:
		return false

	if item_data.stackable:
		var current := int(stackable_items.get(item_id, 0))
		if current < count:
			return false
		var remaining := current - count
		if remaining == 0:
			stackable_items.erase(item_id)
		else:
			stackable_items[item_id] = remaining
		return true

	var removed := 0
	for index in range(unique_items.size() - 1, -1, -1):
		var instance = unique_items[index] as ItemInstance
		if instance != null and instance.item_data != null and instance.item_data.id == item_id:
			removed += 1
			if removed == count:
				break
	if removed < count:
		return false

	for index in range(unique_items.size() - 1, -1, -1):
		var instance = unique_items[index] as ItemInstance
		if instance != null and instance.item_data != null and instance.item_data.id == item_id:
			unique_items.remove_at(index)
			removed -= 1
			if removed == 0:
				return true
	return true


func has(item_id: String) -> bool:
	return count(item_id) > 0


func count(item_id: String) -> int:
	var item_data := _load_item_data(item_id)
	if item_data == null:
		return 0

	if item_data.stackable:
		return int(stackable_items.get(item_id, 0))

	var total := 0
	for instance in unique_items:
		if instance.item_data != null and instance.item_data.id == item_id:
			total += 1
	return total


# 返回混合列表：
# - 可堆叠物品：{"item_data": ItemData, "count": int}
# - 独立物品：ItemInstance
func list_by_category(cat: ItemData.ItemCategory) -> Array:
	var results: Array = []

	for item_id in stackable_items.keys():
		var item_data := _load_item_data(String(item_id))
		if item_data != null and item_data.category == cat:
			results.append({
				"item_data": item_data,
				"count": int(stackable_items[item_id]),
			})

	for instance in unique_items:
		if instance.item_data != null and instance.item_data.category == cat:
			results.append(instance)

	return results


func remove_instance(instance_id: int) -> bool:
	for index in range(unique_items.size()):
		var instance = unique_items[index] as ItemInstance
		if instance != null and instance.instance_id == instance_id:
			unique_items.remove_at(index)
			return true
	return false


func _load_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	# 优先走 ItemRegistry 单例；启动早期 autoload 未入树时回退到直接 load。
	var main_loop := Engine.get_main_loop()
	if main_loop != null and main_loop is SceneTree:
		var root := (main_loop as SceneTree).root
		if root != null and root.is_inside_tree():
			var registry := root.get_node_or_null("ItemRegistry")
			if registry != null:
				return registry.get_data(item_id)
	var path := "res://resources/data/items/%s.tres" % item_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ItemData
