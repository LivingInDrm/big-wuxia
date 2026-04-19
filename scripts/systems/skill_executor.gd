extends RefCounted
class_name SkillExecutor

const VFX = preload("res://scripts/systems/vfx.gd")
const DUST_VFX: SpriteFrames = preload("res://resources/sprites/vfx/dust.tres")
const FIRE_VFX: SpriteFrames = preload("res://resources/sprites/vfx/fire.tres")
const EXPLOSION_VFX: SpriteFrames = preload("res://resources/sprites/vfx/explosion.tres")
const HEAL_VFX: SpriteFrames = preload("res://resources/sprites/vfx/heal.tres")
const FIRE_LIFETIME := 0.45
const LINE_VFX_STEP_DELAY := 0.05


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
	await caster.play_skill(skill.animation_key, _coord_to_world(target_pos))
	await _spawn_skill_vfx(caster, skill, target_pos, affected_cells)

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
				var result: Dictionary = CombatSystem.calculate_attack(caster, unit, grid, skill)
				if result.hit:
					unit.take_damage(result.damage)
				else:
					_spawn_miss_number(unit)
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


static func _spawn_skill_vfx(caster: Unit, skill, target_pos: Vector2i,
		affected_cells: Array[Vector2i]) -> void:
	if caster == null or skill == null:
		return
	var parent_node := caster.get_parent() if caster.get_parent() != null else caster
	match String(skill.skill_id):
		"chun_qiu_dao_fa", "nei_gong_zhang", "jian_qi":
			_spawn_damage_dust(parent_node, target_pos)
		"liang_xiu_qing_she":
			for coord in affected_cells:
				_spawn_fire(parent_node, coord, 0.6)
		"jian_qi_ru_lei":
			for coord in affected_cells:
				_spawn_fire(parent_node, coord, 0.8)
				await caster.get_tree().create_timer(LINE_VFX_STEP_DELAY).timeout
		"jian_kai_tian_men":
			VFX.spawn_at(parent_node, EXPLOSION_VFX, _coord_to_world(target_pos), 1.5)
			for coord in affected_cells:
				_spawn_fire(parent_node, coord, 0.8)
		"hui_chun_shu":
			VFX.spawn_at(parent_node, HEAL_VFX, _coord_to_world(target_pos) + Vector2(0, -32), 0.75)
		"qing_gong":
			VFX.spawn_at(parent_node, DUST_VFX, caster.global_position + Vector2(0, 12), 1.0)


static func _spawn_damage_dust(parent_node: Node, target_pos: Vector2i) -> void:
	var world_pos := _coord_to_world(target_pos) + Vector2(0, 16)
	if parent_node == null:
		return
	VFX.spawn_at(parent_node, DUST_VFX, world_pos, 1.0)


static func _spawn_fire(parent_node: Node, coord: Vector2i, scale: float) -> void:
	if parent_node == null:
		return
	var sprite := VFX.spawn_at(parent_node, FIRE_VFX, _coord_to_world(coord) + Vector2(0, 8), scale)
	parent_node.get_tree().create_timer(FIRE_LIFETIME).timeout.connect(
		sprite.queue_free,
		CONNECT_ONE_SHOT
	)


static func _spawn_miss_number(unit: Unit) -> void:
	var parent_node := unit.get_parent() if unit.get_parent() != null else unit
	VFX.spawn_damage_number(parent_node, unit.global_position + Vector2(0, -40), "MISS", false)


static func _coord_to_world(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * 64 + 32, coord.y * 64 + 32)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))
