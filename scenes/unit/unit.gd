extends Node2D
class_name Unit
## Unit —— 通用单位节点（玩家/敌方共用）
##
## S3 范围：只负责渲染 + HP 条 + selected/acted 指示器。
##   S4 再加 move_to / attack / use_skill / take_damage / die
##
## 初始化时序：
##   节点实例化 → setup(data) 设置 unit_data → add_child → _ready 读 data 生成视觉
##   也可以在编辑器里预设 unit_data 再 add_child，_ready 一样处理。

const TILE_PX := 64
const VFX = preload("res://scripts/systems/vfx.gd")
const AttributeSet = preload("res://scripts/core/attribute_set.gd")
const AttributeResolver = preload("res://scripts/systems/attribute_resolver.gd")
const StatusEffect = preload("res://scripts/core/status_effect.gd")
const TraitData = preload("res://scripts/core/trait_data.gd")
const ItemData = preload("res://scripts/core/item_data.gd")
const Facing = preload("res://scripts/core/facing.gd")

## 语义动画名（SpriteFrames 里需要有 `b_<sem>` + `z_<sem>` 或无前缀回退版本）。
const ANIM_SEMANTICS := ["idle", "run", "attack", "hit", "die", "skill"]

@export var unit_data: UnitData

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar/Fill
@onready var hp_label: Label = $HealthBar/HPLabel
@onready var select_indicator: Node2D = $SelectIndicator
@onready var acted_indicator: ColorRect = $ActedIndicator
@onready var area: Area2D = $Area2D

var current_hp: int = 0
var max_hp: int = 0
var current_mp: int = 0
var max_mp: int = 0
var current_position: Vector2i = Vector2i.ZERO
var acted: bool = false
## isometric 4 向：值取自 Facing.Dir 枚举（SW=0/SE=1/NE=2/NW=3）。
var facing: int = Facing.Dir.SW
var _hurt_feedback_running: bool = false
var skills: Array = []
var temp_move_bonus: int = 0
var traits: Array[TraitData] = []
var status_effects: Array[StatusEffect] = []

signal unit_selected(unit: Unit)
signal unit_died(unit: Unit)
signal hurt_started(unit: Unit)
signal hurt_finished(unit: Unit)
signal skill_state_changed(unit: Unit)
signal hud_state_changed(unit: Unit)


## 场景预设或代码构造时调用；add_child 之后 _ready 会按 unit_data 初始化视觉。
func setup(data: UnitData, grid_pos: Vector2i = Vector2i.ZERO) -> void:
	unit_data = data
	current_position = grid_pos
	if is_inside_tree():
		_initialize_runtime_resources()
		_ensure_game_state_connection()
		_refresh_health_bar()
		_load_skills()


func _ready() -> void:
	if unit_data == null:
		push_warning("[Unit] unit_data 未设置，跳过初始化")
		return

	# 动画
	anim_sprite.sprite_frames = unit_data.sprite_frames
	anim_sprite.offset = unit_data.sprite_offset
	# 阵营默认朝向：玩家 SW（面向镜头偏左）/ 敌方 NE（背对镜头偏右，朝向玩家）。
	facing = Facing.Dir.NE if unit_data.is_enemy else Facing.Dir.SW
	_refresh_sprite_modulate()
	_apply_facing()
	play_anim("idle")

	# 运行时资源
	_initialize_runtime_resources()
	_ensure_game_state_connection()
	_refresh_health_bar()
	_load_skills()

	# 初始位置（grid → pixel，tile center 对齐）
	if current_position != Vector2i.ZERO or true:
		position = Vector2(
			current_position.x * TILE_PX + TILE_PX / 2.0,
			current_position.y * TILE_PX + TILE_PX / 2.0
		)

	# Area2D 鼠标点击
	if area != null and not area.input_event.is_connected(_on_area_input):
		area.input_event.connect(_on_area_input)

	# indicators 默认隐藏
	select_indicator.visible = false
	acted_indicator.visible = false


## 血条刷新 + 按 HP 百分比调色（>50% 绿 / 20-50% 黄 / <20% 红）
func _refresh_health_bar() -> void:
	if unit_data == null:
		return
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	hp_label.text = "%d/%d" % [current_hp, max_hp]
	var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	var bar_color: Color
	if ratio > 0.5:
		bar_color = Color(0.3, 0.85, 0.35)   # 绿
	elif ratio > 0.2:
		bar_color = Color(0.95, 0.82, 0.25)  # 黄
	else:
		bar_color = Color(0.9, 0.25, 0.25)   # 红
	var fg_style := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fg_style != null:
		fg_style.bg_color = bar_color


func set_selected(on: bool) -> void:
	select_indicator.visible = on


func set_acted(on: bool) -> void:
	acted = on
	acted_indicator.visible = on
	_refresh_sprite_modulate()


## 扣血 + 更新 HP 条；HP<=0 触发 unit_died 信号并启动死亡动画。
func take_damage(amount: int) -> void:
	var prev_hp := current_hp
	if amount < 0:
		amount = 0
	current_hp = max(0, current_hp - amount)
	_refresh_health_bar()
	hud_state_changed.emit(self)
	if amount > 0 and prev_hp > 0:
		var parent_node := get_parent() if get_parent() != null else self
		VFX.spawn_damage_number(parent_node, global_position + Vector2(0, -40), amount, false)
	if current_hp <= 0:
		_die()
		return
	if is_inside_tree():
		_play_hurt_feedback()


func heal(amount: int) -> void:
	if unit_data == null or amount <= 0 or current_hp <= 0:
		return
	var prev_hp := current_hp
	current_hp = min(max_hp, current_hp + amount)
	_refresh_health_bar()
	hud_state_changed.emit(self)
	var actual := current_hp - prev_hp
	if actual > 0:
		var parent_node := get_parent() if get_parent() != null else self
		VFX.spawn_damage_number(parent_node, global_position + Vector2(0, -56), actual, true)


func get_max_hp() -> int:
	return max_hp


func get_max_mp() -> int:
	return max_mp


func add_trait(trait_id: String, modifier_dict: Dictionary) -> TraitData:
	var trait_item := TraitData.new(trait_id, modifier_dict)
	traits.append(trait_item)
	_refresh_derived_resources()
	return trait_item


func add_status_effect(source: String, modifier_dict: Dictionary, remaining_turns: int) -> StatusEffect:
	var effect := StatusEffect.new(source, modifier_dict, remaining_turns)
	status_effects.append(effect)
	_refresh_derived_resources()
	hud_state_changed.emit(self)
	return effect


func tick_status_effects() -> void:
	if status_effects.is_empty():
		return

	for effect in status_effects:
		effect.remaining_turns -= 1

	var remaining: Array[StatusEffect] = []
	for effect in status_effects:
		if effect.remaining_turns > 0:
			remaining.append(effect)
	status_effects = remaining
	_refresh_derived_resources()
	hud_state_changed.emit(self)


func consume_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_mp < amount:
		return false
	current_mp -= amount
	hud_state_changed.emit(self)
	return true


func restore_mp(amount: int) -> void:
	if amount <= 0:
		return
	current_mp = min(max_mp, current_mp + amount)
	hud_state_changed.emit(self)


## 沿 path 逐格 tween 过去（每格 0.15s）。Coroutine：await unit.move_along_path(...)。
## path 中第一个元素应是第一个目标格（不含起点）。
func move_along_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	# 起手：按整条路径的净位移一次性定方向，全程不变（避免曲折路抖动）。
	var end_cell: Vector2i = path[path.size() - 1]
	_update_facing_from_grid(
		end_cell.x - current_position.x,
		end_cell.y - current_position.y
	)
	play_anim("run")

	for step in path:
		var target_px := Vector2(
			step.x * TILE_PX + TILE_PX / 2.0,
			step.y * TILE_PX + TILE_PX / 2.0
		)
		var tw := create_tween()
		tw.tween_property(self, "position", target_px, 0.15)
		await tw.finished
		current_position = step

	# 恢复 idle + 恢复朝向（facing 不变，只让 sprite 贴合）
	play_anim("idle")
	_apply_facing()


## 播放 attack 动画（Coroutine：await unit.play_attack()）。
## defender_cell 给 grid 坐标（Vector2i）；Vector2i.MAX 表示不调整朝向。
## 若没 attack animation 则退化为 idle 一帧后返回。
func play_attack(defender_cell: Vector2i = Vector2i.MAX) -> void:
	if defender_cell != Vector2i.MAX:
		_update_facing_from_grid(
			defender_cell.x - current_position.x,
			defender_cell.y - current_position.y
		)
	var anim_name := "attack" if _has_semantic("attack") else "idle"
	play_anim(anim_name)
	# 等待 attack 动画一个循环
	if anim_name == "attack":
		await anim_sprite.animation_finished
	else:
		await get_tree().create_timer(0.25).timeout
	# 回到 idle
	play_anim("idle")
	_apply_facing()


func play_skill(animation_key: String = "skill", defender_cell: Vector2i = Vector2i.MAX) -> void:
	if defender_cell != Vector2i.MAX:
		_update_facing_from_grid(
			defender_cell.x - current_position.x,
			defender_cell.y - current_position.y
		)
	var anim_name := animation_key
	if not _has_semantic(anim_name):
		anim_name = "attack" if _has_semantic("attack") else "idle"
	play_anim(anim_name)
	if anim_name != "idle":
		await anim_sprite.animation_finished
	else:
		await get_tree().create_timer(0.2).timeout
	play_anim("idle")
	_apply_facing()


func _die() -> void:
	_grant_loot_drops()
	unit_died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		unit_selected.emit(self)
		# 关键：消费事件，避免继续冒泡到 BattleController._unhandled_input
		# 否则"点击敌兵"会同时被当成"点击空格"从而立刻 _finish_unit_action，
		# 导致攻击动画未播放 + 状态瞬间回 IDLE（用户感知为"无响应"）
		get_viewport().set_input_as_handled()


## 按 grid 位移 (dx, dy) 更新 facing 到 Facing.Dir，然后贴 sprite。
## 仅由 move/attack/skill 的"起手"调用，idle/hurt/die 不调用。
func _update_facing_from_grid(dx: int, dy: int) -> void:
	facing = Facing.from_grid_delta(dx, dy, facing)
	_apply_facing()


## 旧 1D wrapper：只看 dx，保留给尚未迁移到 2D 的调用点。
## 新代码请直接调用 `_update_facing_from_grid(dx, dy)`。
func _update_facing(dx: int) -> void:
	_update_facing_from_grid(dx, 0)


## 依据当前 facing 决定 flip_h 与 b_/z_ 前缀；唯一允许写 `flip_h` 的地方。
func _apply_facing() -> void:
	if anim_sprite == null:
		return
	var new_flip := Facing.flip_h(facing)
	var new_back := Facing.is_back(facing)
	_rebind_current_anim(new_back)
	anim_sprite.flip_h = new_flip


## 切换当前动画的 b_/z_ 前缀，同时保留帧进度避免闪帧。
## 若 SpriteFrames 没有对应前缀版本（LEGACY 无前缀资源），就保持当前动画不切。
func _rebind_current_anim(new_is_back: bool) -> void:
	if anim_sprite == null:
		return
	var sf: SpriteFrames = anim_sprite.sprite_frames
	if sf == null:
		return
	var cur := String(anim_sprite.animation)
	if cur == "":
		return
	var semantic := cur
	if cur.begins_with("b_") or cur.begins_with("z_"):
		semantic = cur.substr(2)
	var prefix := "b" if new_is_back else "z"
	var target := "%s_%s" % [prefix, semantic]
	if target == cur:
		return
	if not sf.has_animation(target):
		# LEGACY 回退：无前缀资源没有 b_/z_ 版本，保持当前动画。
		return
	var frame_idx: int = anim_sprite.frame
	var frame_progress: float = anim_sprite.frame_progress
	anim_sprite.play(target)
	anim_sprite.frame = frame_idx
	anim_sprite.frame_progress = frame_progress


## 播放语义动画；按当前 facing 自动选 b_ / z_ 前缀，找不到时回退到无前缀版本。
func play_anim(semantic: String) -> void:
	if anim_sprite == null:
		return
	var sf: SpriteFrames = anim_sprite.sprite_frames
	if sf == null:
		return
	var full := "%s_%s" % [Facing.prefix(facing), semantic]
	if sf.has_animation(full):
		anim_sprite.play(full)
	elif sf.has_animation(semantic):
		# LEGACY 回退：老资源（warrior / monk / enemy_soldier / yang_yuanzan）
		# 只有无前缀动画，直接播原名。
		anim_sprite.play(semantic)


func _has_semantic(semantic: String) -> bool:
	var sf: SpriteFrames = anim_sprite.sprite_frames if anim_sprite != null else null
	if sf == null:
		return false
	var full := "%s_%s" % [Facing.prefix(facing), semantic]
	return sf.has_animation(full) or sf.has_animation(semantic)


func _refresh_sprite_modulate() -> void:
	if anim_sprite == null or unit_data == null:
		return
	if _hurt_feedback_running:
		return
	var acted_tint := Color(0.6, 0.6, 0.6, 1.0) if acted else Color.WHITE
	anim_sprite.modulate = unit_data.modulate * acted_tint


func _load_skills() -> void:
	skills.clear()
	if unit_data == null:
		return
	var registry := get_node_or_null("/root/SkillRegistry")
	if registry == null:
		# 回退：SkillRegistry 未注册时走 GameBalance（旧路径）
		var balance := get_node_or_null("/root/GameBalance")
		for skill_id in unit_data.skill_ids:
			if balance == null:
				break
			var skill = balance.get_skill_data(skill_id)
			if skill == null:
				continue
			skills.append(skill.duplicate_runtime())
		return
	for skill_id in unit_data.skill_ids:
		var skill = registry.get_data(skill_id)
		if skill == null:
			continue
		skills.append(skill.duplicate_runtime())


func get_skill(idx: int):
	if idx < 0 or idx >= skills.size():
		return null
	return skills[idx]


func tick_cooldowns() -> void:
	for skill in skills:
		if skill.current_cd > 0:
			skill.current_cd -= 1
	skill_state_changed.emit(self)


func get_current_mov() -> int:
	if unit_data == null or unit_data.attributes == null:
		return temp_move_bonus
	return unit_data.attributes.move_range + temp_move_bonus


func get_qi_regen_amount() -> int:
	return int(AttributeResolver.get_qi_speed(self)["total"])


func set_move_buff(amount: int) -> void:
	temp_move_bonus = max(temp_move_bonus, amount)
	skill_state_changed.emit(self)
	hud_state_changed.emit(self)


func clear_temp_buffs() -> void:
	temp_move_bonus = 0
	skill_state_changed.emit(self)
	hud_state_changed.emit(self)


func _play_hurt_feedback() -> void:
	if _hurt_feedback_running or anim_sprite == null or unit_data == null or current_hp <= 0:
		return
	_hurt_feedback_running = true
	var base_pos := position
	var base_color := unit_data.modulate * (Color(0.6, 0.6, 0.6, 1.0) if acted else Color.WHITE)
	# TODO(step-1-2): shake_offset 应按 2D facing 在 isometric 正反斜方向抖。
	# 当前沿用旧的 1D 水平抖（按 flip_h 决定左右），不影响手感。
	var facing_sign := -1.0 if Facing.flip_h(facing) else 1.0
	var shake_offset := Vector2(-6.0 * facing_sign, 0.0)
	anim_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	hurt_started.emit(self)

	var tw := create_tween()
	tw.tween_property(anim_sprite, "modulate", base_color, 0.12)
	tw.parallel().tween_property(self, "position", base_pos + shake_offset, 0.05)
	tw.chain().tween_property(self, "position", base_pos - shake_offset, 0.08)
	tw.chain().tween_property(self, "position", base_pos, 0.07)
	tw.finished.connect(_on_hurt_feedback_finished.bind(base_pos))


func _on_hurt_feedback_finished(base_pos: Vector2) -> void:
	position = base_pos
	_hurt_feedback_running = false
	_refresh_sprite_modulate()
	hurt_finished.emit(self)


func _initialize_runtime_resources() -> void:
	max_hp = int(AttributeResolver.get_max_hp(self)["total"])
	max_mp = int(AttributeResolver.get_max_mp(self)["total"])
	current_hp = max_hp
	current_mp = 0


func recalc_stats() -> void:
	var prev_max_hp := max_hp
	var prev_max_mp := max_mp
	var prev_current_hp := current_hp
	max_hp = int(AttributeResolver.get_max_hp(self)["total"])
	max_mp = int(AttributeResolver.get_max_mp(self)["total"])
	if prev_max_hp > 0:
		current_hp = clampi(
			int(roundi(float(prev_current_hp) * float(max_hp) / float(prev_max_hp))),
			0,
			max_hp
		)
	else:
		current_hp = clampi(current_hp, 0, max_hp)
	if prev_max_mp > 0:
		current_mp = min(current_mp, max_mp)
	else:
		current_mp = clampi(current_mp, 0, max_mp)
	if is_inside_tree():
		_refresh_health_bar()
	hud_state_changed.emit(self)


func _refresh_derived_resources() -> void:
	recalc_stats()


func _get_attributes() -> AttributeSet:
	if unit_data != null and unit_data.attributes != null:
		return unit_data.attributes
	return AttributeSet.new()


func _exit_tree() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.equipment_changed.is_connected(_on_game_state_equipment_changed):
		game_state.equipment_changed.disconnect(_on_game_state_equipment_changed)


func _ensure_game_state_connection() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and not game_state.equipment_changed.is_connected(_on_game_state_equipment_changed):
		game_state.equipment_changed.connect(_on_game_state_equipment_changed)


func _on_game_state_equipment_changed(char_id: String) -> void:
	if unit_data == null or unit_data.unit_id != char_id:
		return
	recalc_stats()


func _grant_loot_drops() -> void:
	if unit_data == null or unit_data.loot_table == null:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var drops := unit_data.loot_table.roll()
	if drops.is_empty():
		return

	for drop in drops:
		if not (drop is Dictionary):
			continue
		var item_id := String(drop.get("item_id", ""))
		var count := int(drop.get("count", 0))
		if item_id.is_empty() or count <= 0:
			continue
		game_state.inventory.add(item_id, count)
