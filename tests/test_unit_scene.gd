extends SceneTree
## test_unit_scene —— S3 Unit 场景 _ready 初始化单测
##
## 用法：godot --headless --path . --script tests/test_unit_scene.gd
##
## 覆盖：
##   T1  unit.tscn 可加载
##   T2  instantiate + setup(data) + add_child 后 _ready 正确初始化：
##        - current_hp == max_hp
##        - anim_sprite.animation == "idle"
##        - anim_sprite.modulate == unit_data.modulate
##        - health_bar.max_value / value 正确
##   T3  HP 条按阈值染色：
##        ratio > 0.5 → 绿 (0.3,0.85,0.35)
##        0.2 < ratio <= 0.5 → 黄 (0.95,0.82,0.25)
##        ratio <= 0.2 → 红 (0.9,0.25,0.25)
##
## 退出码：0 = 全部通过，1 = 有失败

const UNIT_SCENE := "res://scenes/unit/unit.tscn"

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_unit_scene] ==== BEGIN ====")

	var packed: PackedScene = load(UNIT_SCENE)
	_assert(packed != null, "T1 unit.tscn 加载")
	if packed == null:
		_finish()
		return

	var data_xu: UnitData = load("res://resources/data/units/xu_fengnian.tres")
	_assert(data_xu != null, "T1b xu_fengnian.tres 加载")

	# T2: _ready 初始化
	var u: Unit = packed.instantiate()
	u.setup(data_xu, Vector2i(3, 3))
	root.add_child(u)
	await process_frame

	_assert(u.current_hp == data_xu.max_hp,
		"T2a current_hp == max_hp (实际=%d, 期望=%d)" % [u.current_hp, data_xu.max_hp])
	_assert(u.anim_sprite != null, "T2b anim_sprite 非 null")
	if u.anim_sprite != null:
		_assert(u.anim_sprite.animation == &"idle",
			"T2c animation == idle (实际=%s)" % u.anim_sprite.animation)
		_assert(u.anim_sprite.modulate == data_xu.modulate,
			"T2d modulate 与 data 一致")
		_assert(u.anim_sprite.flip_h == false,
			"T2d2 玩家 flip_h=false (实际=%s)" % u.anim_sprite.flip_h)
	_assert(u.health_bar.max_value == float(data_xu.max_hp),
		"T2e health_bar.max_value")
	_assert(u.health_bar.value == float(data_xu.max_hp),
		"T2f health_bar.value 初始 = max_hp")

	# T3: HP 染色（通过手动改 current_hp 再刷新）
	_check_hp_color(u, 0.8, Color(0.3, 0.85, 0.35), "T3a 高血量绿色")
	_check_hp_color(u, 0.35, Color(0.95, 0.82, 0.25), "T3b 中血量黄色")
	_check_hp_color(u, 0.1, Color(0.9, 0.25, 0.25), "T3c 低血量红色")

	u.queue_free()
	await process_frame

	# T4: 敌方 flip_h=true
	var data_enemy: UnitData = load("res://resources/data/units/enemy_soldier.tres")
	var e: Unit = packed.instantiate()
	e.setup(data_enemy, Vector2i(5, 5))
	root.add_child(e)
	await process_frame
	_assert(e.anim_sprite.flip_h == true,
		"T4a 敌方 flip_h=true (实际=%s)" % e.anim_sprite.flip_h)
	e.queue_free()
	await process_frame

	_finish()


func _check_hp_color(u: Unit, ratio: float, expected: Color, msg: String) -> void:
	u.current_hp = int(round(u.unit_data.max_hp * ratio))
	u._refresh_health_bar()
	var fg: StyleBoxFlat = u.health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_assert(fg != null, "%s fill stylebox 非 null" % msg)
	if fg == null:
		return
	var ok: bool = is_equal_approx(fg.bg_color.r, expected.r) \
		and is_equal_approx(fg.bg_color.g, expected.g) \
		and is_equal_approx(fg.bg_color.b, expected.b)
	_assert(ok, "%s 颜色=%s 期望=%s" % [msg, str(fg.bg_color), str(expected)])


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_unit_scene] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
