extends SceneTree
## build_sprite_frames.gd —— 一次性脚本：生成 warrior / monk SpriteFrames .tres
##
## 用法：
##   godot --headless --path . --script tools/build_sprite_frames.gd
##
## 产物：
##   resources/data/units/warrior_sprite_frames.tres
##   resources/data/units/monk_sprite_frames.tres
##
## 帧规格（见 docs/design/01-game-design.md §8 Sprite 映射）：
##   Warrior: Idle 8f / Run 6f / Attack 4f，每帧 192×192，水平排列
##   Monk:    Idle 6f / Run 4f / Heal 11f，每帧 192×192
##   动画速度：Idle 6fps / Run 10fps / Attack 8fps / Heal 10fps，全部 loop
##   Attack/Heal 技能类动画 loop=false（留给 S5 触发播放完回 Idle）

const OUT_DIR := "res://resources/data/units/"
const WARRIOR_DIR := "res://resources/sprites/units/warrior/"
const MONK_DIR := "res://resources/sprites/units/monk/"
const FRAME_SIZE := 192


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_build_warrior()
	_build_monk()

	print("[build_sprite_frames] OK")
	quit(0)


func _build_warrior() -> void:
	var sf := SpriteFrames.new()
	# 默认动画 Godot 会创建 "default"，我们替换为命名动画
	if sf.has_animation("default"):
		sf.remove_animation("default")

	_add_strip(sf, "idle", WARRIOR_DIR + "idle.png", 8, 6.0, true)
	_add_strip(sf, "run", WARRIOR_DIR + "run.png", 6, 10.0, true)
	_add_strip(sf, "attack", WARRIOR_DIR + "attack.png", 4, 8.0, false)

	var out := OUT_DIR + "warrior_sprite_frames.tres"
	var err := ResourceSaver.save(sf, out)
	if err != OK:
		push_error("[build_sprite_frames] warrior save failed err=%d" % err)
		return
	print("[build_sprite_frames] saved %s" % out)


func _build_monk() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	_add_strip(sf, "idle", MONK_DIR + "idle.png", 6, 6.0, true)
	_add_strip(sf, "run", MONK_DIR + "run.png", 4, 10.0, true)
	_add_strip(sf, "heal", MONK_DIR + "heal.png", 11, 10.0, false)

	var out := OUT_DIR + "monk_sprite_frames.tres"
	var err := ResourceSaver.save(sf, out)
	if err != OK:
		push_error("[build_sprite_frames] monk save failed err=%d" % err)
		return
	print("[build_sprite_frames] saved %s" % out)


## 把水平排列的 strip PNG 切成 N 个 AtlasTexture 帧加入 animation。
func _add_strip(sf: SpriteFrames, anim: String, png_path: String, frames: int, fps: float, loop: bool) -> void:
	var tex: Texture2D = load(png_path) as Texture2D
	if tex == null:
		push_error("[build_sprite_frames] texture not found: %s" % png_path)
		return
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in frames:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		sf.add_frame(anim, at)
