extends RefCounted
class_name SkillExecutor


static func get_targetable_cells(caster: Unit, skill, grid: GridSystem) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if caster == null or skill == null or grid == null:
		return out
	match skill.range_type:
		0:
			for coord in grid.get_all_coords():
				if _chebyshev(caster.current_position, coord) <= skill.range_value:
					out.append(coord)
		2:
			for coord in grid.get_all_coords():
				if _chebyshev(caster.current_position, coord) <= skill.range_value:
					out.append(coord)
		3:
			for coord in grid.get_all_coords():
				if _chebyshev(caster.current_position, coord) <= skill.range_value:
					out.append(coord)
		1:
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				for step in range(1, skill.range_value + 1):
					var coord: Vector2i = caster.current_position + dir * step
					if grid.has_tile(coord):
						out.append(coord)
	return out


static func get_affected_cells(caster: Unit, skill, target_pos: Vector2i,
		grid: GridSystem) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if caster == null or skill == null or grid == null:
		return out
	match skill.range_type:
		0:
			if grid.has_tile(target_pos):
				out.append(target_pos)
		1:
			var delta: Vector2i = target_pos - caster.current_position
			var dir: Vector2i = Vector2i.ZERO
			if abs(delta.x) >= abs(delta.y):
				dir = Vector2i(signi(delta.x), 0)
			else:
				dir = Vector2i(0, signi(delta.y))
			if dir == Vector2i.ZERO:
				return out
			for step in range(1, skill.range_value + 1):
				var coord: Vector2i = caster.current_position + dir * step
				if grid.has_tile(coord):
					out.append(coord)
		2:
			if grid.has_tile(target_pos):
				out.append(target_pos)
			for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				for step in range(1, skill.range_value + 1):
					var coord: Vector2i = target_pos + dir * step
					if grid.has_tile(coord):
						out.append(coord)
		3:
			for dx in range(-skill.range_value, skill.range_value + 1):
				for dy in range(-skill.range_value, skill.range_value + 1):
					var coord: Vector2i = target_pos + Vector2i(dx, dy)
					if grid.has_tile(coord) and _chebyshev(target_pos, coord) <= skill.range_value:
						out.append(coord)
	return out


static func execute_skill(caster: Unit, skill, target_pos: Vector2i, grid: GridSystem,
		_combat_system = null) -> Array[Unit]:
	var affected_units: Array[Unit] = []
	if caster == null or skill == null or grid == null:
		return affected_units

	var affected_cells: Array[Vector2i] = get_affected_cells(caster, skill, target_pos, grid)
	var flash_color := Color(1.0, 0.85, 0.4, 1.0) if skill.effect_type == 0 \
		else Color(0.55, 1.0, 0.8, 1.0)
	await caster.play_skill(skill.animation_key, _coord_to_world(target_pos), flash_color)

	for coord in affected_cells:
		var tile: GridTile = grid.get_tile(coord)
		if tile == null:
			continue
		var unit := tile.occupant as Unit
		if unit == null or unit.current_hp <= 0:
			continue
		match skill.effect_type:
			0:
				if unit.unit_data.is_enemy == caster.unit_data.is_enemy:
					continue
				CombatSystem.resolve_attack(caster, unit, grid, skill)
				affected_units.append(unit)
			1:
				if unit.unit_data.is_enemy != caster.unit_data.is_enemy:
					continue
				unit.heal(int(round(skill.power)))
				affected_units.append(unit)
			2:
				if unit != caster:
					continue
				unit.set_move_buff(int(round(skill.power)))
				affected_units.append(unit)

	skill.spend_use()
	caster.skill_state_changed.emit(caster)
	return affected_units


static func _coord_to_world(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * 64 + 32, coord.y * 64 + 32)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))
