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
var facing: int = 1
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


## 场景预设或代码构造时调用；add_child 之后 _ready 会按 unit_data 初始化视觉。
func setup(data: UnitData, grid_pos: Vector2i = Vector2i.ZERO) -> void:
	unit_data = data
	current_position = grid_pos
	if is_inside_tree():
		_initialize_runtime_resources()
		_refresh_health_bar()
		_load_skills()


func _ready() -> void:
	if unit_data == null:
		push_warning("[Unit] unit_data 未设置，跳过初始化")
		return

	# 动画
	anim_sprite.sprite_frames = unit_data.sprite_frames
	anim_sprite.offset = unit_data.sprite_offset
	facing = -1 if unit_data.is_enemy else 1
	_refresh_sprite_modulate()
	_apply_facing()
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")

	# 运行时资源
	_initialize_runtime_resources()
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


func consume_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_mp < amount:
		return false
	current_mp -= amount
	return true


func restore_mp(amount: int) -> void:
	if amount <= 0:
		return
	current_mp = min(max_mp, current_mp + amount)


## 沿 path 逐格 tween 过去（每格 0.15s）。Coroutine：await unit.move_along_path(...)。
## path 中第一个元素应是第一个目标格（不含起点）。
func move_along_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	_update_facing(path.back().x - current_position.x)
	# 播放 run 动画
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("run"):
		anim_sprite.play("run")

	for step in path:
		var target_px := Vector2(
			step.x * TILE_PX + TILE_PX / 2.0,
			step.y * TILE_PX + TILE_PX / 2.0
		)
		var tw := create_tween()
		tw.tween_property(self, "position", target_px, 0.15)
		await tw.finished
		current_position = step

	# 恢复 idle + 恢复朝向
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")
	_apply_facing()


## 播放 attack 动画（Coroutine：await unit.play_attack()）。
## 若没 attack animation 则退化为 idle 一帧后返回。
func play_attack(target_world_pos: Vector2 = Vector2.ZERO) -> void:
	# 调整朝向到目标
	if target_world_pos != Vector2.ZERO:
		_update_facing(signi(int(round(target_world_pos.x - position.x))))
	var anim_name := "attack" if anim_sprite.sprite_frames != null \
		and anim_sprite.sprite_frames.has_animation("attack") else "idle"
	anim_sprite.play(anim_name)
	# 等待 attack 动画一个循环
	if anim_name == "attack":
		await anim_sprite.animation_finished
	else:
		await get_tree().create_timer(0.25).timeout
	# 回到 idle
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")
	_apply_facing()


func play_skill(animation_key: String = "skill", target_world_pos: Vector2 = Vector2.ZERO) -> void:
	if target_world_pos != Vector2.ZERO:
		_update_facing(signi(int(round(target_world_pos.x - position.x))))
	var anim_name := animation_key
	if anim_sprite.sprite_frames == null or not anim_sprite.sprite_frames.has_animation(anim_name):
		anim_name = "attack" if anim_sprite.sprite_frames != null \
			and anim_sprite.sprite_frames.has_animation("attack") else "idle"
	anim_sprite.play(anim_name)
	if anim_name != "idle":
		await anim_sprite.animation_finished
	else:
		await get_tree().create_timer(0.2).timeout
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")
	_apply_facing()


func _die() -> void:
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


func _update_facing(dx: int) -> void:
	if dx < 0:
		facing = -1
	elif dx > 0:
		facing = 1
	_apply_facing()


func _apply_facing() -> void:
	if anim_sprite != null:
		anim_sprite.flip_h = facing < 0


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
	var balance = get_node_or_null("/root/GameBalance")
	for skill_id in unit_data.skill_ids:
		if balance == null:
			break
		var skill = balance.get_skill_data(skill_id)
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
	return unit_data.mov + temp_move_bonus if unit_data != null else temp_move_bonus


func get_qi_regen_amount() -> int:
	return int(AttributeResolver.get_qi_speed(self)["total"])


func set_move_buff(amount: int) -> void:
	temp_move_bonus = max(temp_move_bonus, amount)
	skill_state_changed.emit(self)


func clear_temp_buffs() -> void:
	temp_move_bonus = 0
	skill_state_changed.emit(self)


func _play_hurt_feedback() -> void:
	if _hurt_feedback_running or anim_sprite == null or unit_data == null or current_hp <= 0:
		return
	_hurt_feedback_running = true
	var base_pos := position
	var base_color := unit_data.modulate * (Color(0.6, 0.6, 0.6, 1.0) if acted else Color.WHITE)
	var shake_offset := Vector2(-6.0 * float(facing), 0.0)
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


func _refresh_derived_resources() -> void:
	var prev_max_hp := max_hp
	var prev_max_mp := max_mp
	max_hp = int(AttributeResolver.get_max_hp(self)["total"])
	max_mp = int(AttributeResolver.get_max_mp(self)["total"])
	if prev_max_hp > 0:
		current_hp = min(current_hp, max_hp)
	if prev_max_mp > 0:
		current_mp = min(current_mp, max_mp)
	if is_inside_tree():
		_refresh_health_bar()


func _get_attributes() -> AttributeSet:
	if unit_data != null and unit_data.attributes != null:
		return unit_data.attributes
	return AttributeSet.new()
