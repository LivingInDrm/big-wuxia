extends SceneTree
## s4_screenshots —— S4 验收截图 harness
##
## 产出 3 张截图：
##   tools/screenshots/s4_move_range.png    — 选中徐凤年显示蓝色移动范围
##   tools/screenshots/s4_attack_range.png  — 移动后显示红色攻击范围
##   tools/screenshots/s4_post_combat.png   — 攻击敌兵后 HP 下降
##
## 用法（不要 --headless，渲染需要）:
##   godot --path . --script tools/s4_screenshots.gd

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const OUT_DIR := "res://../tools/screenshots/"  # 不用，用绝对路径
const VIEWPORT := Vector2i(960, 720)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT)

	var packed := ResourceLoader.load(BATTLE_SCENE) as PackedScene
	if packed == null:
		push_error("[s4_screenshots] Failed to load battle.tscn")
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)

	# 等 controller ready + turn_started 完成
	for _i in 20:
		await process_frame

	var controller := scene  # battle.tscn 根即 BattleController
	var players: Array = controller.get_player_units()
	if players.is_empty():
		push_error("[s4_screenshots] no player units")
		quit(2)
		return

	var xu = players[0]  # 徐凤年

	# === 1. s4_move_range.png: 选中徐凤年 ===
	controller.debug_select(xu)
	for _i in 10:
		await process_frame
	_save("tools/screenshots/s4_move_range.png")

	# === 2. s4_attack_range.png: 移动后 ===
	# 徐凤年初始 (2,2)，mov=5，选 (5,2) 往前 3 格（靠近敌兵）
	await controller.debug_move(xu, Vector2i(5, 2))
	for _i in 10:
		await process_frame
	_save("tools/screenshots/s4_attack_range.png")

	# === 3. s4_post_combat.png: 攻击敌兵 ===
	# 敌兵在 (6,1) 和 (6,3)，徐凤年在 (5,2) 攻击范围=1 → (6,1) 和 (6,3) 都在范围内
	var enemies: Array = controller.get_enemy_units()
	var target = null
	for e in enemies:
		if e.current_position == Vector2i(6, 1) or e.current_position == Vector2i(6, 3):
			target = e
			break
	if target != null:
		await controller.debug_attack(xu, target)
		for _i in 15:
			await process_frame
		_save("tools/screenshots/s4_post_combat.png")
	else:
		push_warning("[s4_screenshots] no adjacent enemy to attack")

	print("[s4_screenshots] all 3 screenshots saved")
	quit(0)


func _save(rel_path: String) -> void:
	var abs := ProjectSettings.globalize_path("res://" + rel_path)
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(abs)
	if err != OK:
		push_error("[s4_screenshots] save_png failed err=%s path=%s" % [err, abs])
	else:
		print("[s4_screenshots] saved %s (%sx%s)" % [abs, img.get_width(), img.get_height()])
