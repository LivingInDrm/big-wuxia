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

@export var unit_data: UnitData

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar/Fill
@onready var hp_label: Label = $HealthBar/HPLabel
@onready var select_indicator: Node2D = $SelectIndicator
@onready var acted_indicator: ColorRect = $ActedIndicator
@onready var area: Area2D = $Area2D

var current_hp: int = 0
var current_position: Vector2i = Vector2i.ZERO
var acted: bool = false

signal unit_selected(unit: Unit)
signal unit_died(unit: Unit)


## 场景预设或代码构造时调用；add_child 之后 _ready 会按 unit_data 初始化视觉。
func setup(data: UnitData, grid_pos: Vector2i = Vector2i.ZERO) -> void:
	unit_data = data
	current_position = grid_pos


func _ready() -> void:
	if unit_data == null:
		push_warning("[Unit] unit_data 未设置，跳过初始化")
		return

	# 动画
	anim_sprite.sprite_frames = unit_data.sprite_frames
	anim_sprite.offset = unit_data.sprite_offset
	anim_sprite.modulate = unit_data.modulate
	# 敌方单位面向左（flip_h），玩家单位保持默认（面向右）
	anim_sprite.flip_h = unit_data.is_enemy
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")

	# 血量
	current_hp = unit_data.max_hp
	_refresh_health_bar()

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
	health_bar.max_value = unit_data.max_hp
	health_bar.value = current_hp
	hp_label.text = "%d/%d" % [current_hp, unit_data.max_hp]
	var ratio := float(current_hp) / float(unit_data.max_hp) if unit_data.max_hp > 0 else 0.0
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
	anim_sprite.modulate = unit_data.modulate * (Color(0.6, 0.6, 0.6, 1.0) if on else Color.WHITE)


## 扣血 + 更新 HP 条；HP<=0 触发 unit_died 信号并启动死亡动画。
func take_damage(amount: int) -> void:
	if amount < 0:
		amount = 0
	current_hp = max(0, current_hp - amount)
	_refresh_health_bar()
	if current_hp <= 0:
		_die()


## 沿 path 逐格 tween 过去（每格 0.15s）。Coroutine：await unit.move_along_path(...)。
## path 中第一个元素应是第一个目标格（不含起点）。
func move_along_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	# 播放 run 动画
	if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("run"):
		anim_sprite.play("run")
	# 根据移动方向调整朝向（敌方默认左，不覆盖）
	var first_dx: int = path[0].x - current_position.x
	if not unit_data.is_enemy:
		if first_dx > 0:
			anim_sprite.flip_h = false
		elif first_dx < 0:
			anim_sprite.flip_h = true

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
	if not unit_data.is_enemy:
		anim_sprite.flip_h = false


## 播放 attack 动画（Coroutine：await unit.play_attack()）。
## 若没 attack animation 则退化为 idle 一帧后返回。
func play_attack(target_world_pos: Vector2 = Vector2.ZERO) -> void:
	# 调整朝向到目标
	if target_world_pos != Vector2.ZERO:
		if not unit_data.is_enemy:
			anim_sprite.flip_h = target_world_pos.x < position.x
		else:
			anim_sprite.flip_h = target_world_pos.x <= position.x
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
	# 恢复默认朝向
	if not unit_data.is_enemy:
		anim_sprite.flip_h = false
	else:
		anim_sprite.flip_h = true


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
