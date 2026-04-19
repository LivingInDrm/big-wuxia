extends Resource
class_name LootTable

@export var entries: Array[Dictionary] = []


func roll() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return roll_with_rng(rng)


func roll_with_rng(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if rng == null:
		return drops

	for entry in entries:
		if not (entry is Dictionary):
			continue

		var item_id := String(entry.get("item_id", ""))
		var weight := clampi(int(entry.get("weight", 0)), 0, 100)
		var min_count := maxi(0, int(entry.get("min", 0)))
		var max_count := maxi(min_count, int(entry.get("max", min_count)))
		if item_id.is_empty() or weight <= 0 or max_count <= 0:
			continue
		if rng.randf() >= float(weight) / 100.0:
			continue

		drops.append({
			"item_id": item_id,
			"count": rng.randi_range(min_count, max_count),
		})

	return drops
