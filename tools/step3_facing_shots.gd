extends SceneTree
## tools/step3_facing_shots.gd
##
## 方向系统可视化验证：以徐凤年为例，在空背景中分别把 facing 设置到
## SW / SE / NE / NW，每次等几帧让 AnimatedSprite2D 切帧，然后截图。
##
## 期望看到：
##   SW (idle z_idle, flip_h=false) - 正面朝镜头偏左
##   SE (idle z_idle, flip_h=true)  - 正面朝镜头偏右
##   NE (idle b_idle, flip_h=true)  - 背面朝镜头偏右
##   NW (idle b_idle, flip_h=false) - 背面朝镜头偏左
##
## 用法（不要加 --headless）：
##   godot --path . --script tools/step3_facing_shots.gd

const UNIT_SCENE := "res://scenes/unit/unit.tscn"
const UNIT_DATA := "res://resources/data/units/xu_fengnian.tres"
const Facing = preload("res://scripts/core/facing.gd")

## 渲染区域：围绕 character_center 的裁剪框，贴近视觉主体。
const CROP_SIZE := Vector2i(480, 480)
const CHAR_CENTER := Vector2(200, 240)  ## 基于 1366x768 viewport，放偏左上方便裁剪。

var _u: Node = null


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[step3_facing_shots] ==== BEGIN ====")

	var packed: PackedScene = load(UNIT_SCENE)
	var data = load(UNIT_DATA)
	if packed == null or data == null:
		push_error("scene or data load failed")
		quit(1)
		return

	# 等 1 帧让 viewport 尺寸稳定
	await process_frame
	var vp_rect: Rect2 = root.get_viewport().get_visible_rect()
	var vp_size: Vector2 = vp_rect.size
	print("  viewport logical size = %s" % str(vp_size))

	# 白底：覆盖整个渲染 viewport
	var bg := ColorRect.new()
	bg.color = Color(0.92, 0.92, 0.92, 1.0)
	bg.size = vp_size
	bg.position = Vector2.ZERO
	root.add_child(bg)

	var u = packed.instantiate()
	u.setup(data, Vector2i(0, 0))
	root.add_child(u)
	# add_child 后 _ready 会按 current_position 写 position，我们再覆盖。
	u.position = CHAR_CENTER
	u.scale = Vector2(3.0, 3.0)
	_u = u

	# 等几帧让 _ready 生效 + 动画开始循环
	for _i in 20:
		await process_frame

	# 依次截 4 个方向。每次手动切 facing + 触发 _apply_facing + play_anim。
	await _shot(Facing.Dir.SW, "tools/screenshots/step3_facing_sw.png")
	await _shot(Facing.Dir.SE, "tools/screenshots/step3_facing_se.png")
	await _shot(Facing.Dir.NE, "tools/screenshots/step3_facing_ne.png")
	await _shot(Facing.Dir.NW, "tools/screenshots/step3_facing_nw.png")

	print("[step3_facing_shots] ==== END ====")
	quit(0)


func _shot(dir: int, out_rel: String) -> void:
	_u.facing = dir
	_u.play_anim("idle")
	_u._apply_facing()
	# 确保 position 没被重置
	_u.position = CHAR_CENTER
	# 等多帧让 idle 走到第 3 帧（动态效果更直观）
	for _i in 12:
		await process_frame

	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("get_texture failed")
		return

	# 裁剪：围绕 CHAR_CENTER 的 CROP_SIZE 区域。注意 get_texture 返回物理分辨率。
	var vp_size: Vector2 = root.get_viewport().get_visible_rect().size
	var scale_x: float = float(img.get_width()) / vp_size.x
	var scale_y: float = float(img.get_height()) / vp_size.y
	var half := Vector2(CROP_SIZE) * 0.5
	var crop_rect := Rect2i(
		int((CHAR_CENTER.x - half.x) * scale_x),
		int((CHAR_CENTER.y - half.y) * scale_y),
		int(CROP_SIZE.x * scale_x),
		int(CROP_SIZE.y * scale_y)
	)
	# 夹到图片范围内
	crop_rect = crop_rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var cropped: Image = img.get_region(crop_rect)

	var abs := ProjectSettings.globalize_path("res://" + out_rel)
	var err := cropped.save_png(abs)
	if err != OK:
		push_error("save_png err=%d out=%s" % [err, abs])
		return
	var flip: bool = _u.anim_sprite.flip_h
	var cur: StringName = _u.anim_sprite.animation
	print("  dir=%d anim=%s flip_h=%s → %s" % [dir, String(cur), flip, abs])
