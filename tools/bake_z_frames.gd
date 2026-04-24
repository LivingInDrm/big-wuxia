extends SceneTree
## tools/bake_z_frames.gd
##
## 离线烘焙 B/Z 双前缀 SpriteFrames（step-3-1 方向系统）。
##
## 用法（非 headless，避免 SpriteFrames 渲染问题）:
##   godot --path . --script tools/bake_z_frames.gd
##
## 读取 `wulinsh-assets/characters/<char_id>/animations.json`
## + `sprites.json`，为每个单位产出一个 `_sprite_frames.tres`，其中
## 每个语义动画（idle/run/attack/hit/die/skill）对应两条动画：
##   b_<sem>（背面，由 Z<id>_<raw> 构造时翻转前缀）
##   z_<sem>（正面）
## 前缀语义见 docs/direction-system-design.md §B。
##
## 不执行 import 流程；假定 sheet.res 已在工程里导入。
## 执行后请在 Godot 编辑器里看一眼加载无红字即可。

const ASSETS_ROOT := "res://wulinsh-assets/characters"

## 语义 → 原始动画后缀（_stand2 是 6 帧动态 idle）。
const SEMANTIC_MAP := {
	"idle":   "stand2",
	"run":    "walk",
	"attack": "attack",
	"hit":    "hit",
	"die":    "die",
	"skill":  "skill",
}

## loop 策略：一次性动作不 loop。
const LOOP_SEMANTICS := {
	"idle":   true,
	"run":    true,
	"attack": false,
	"hit":    false,
	"die":    false,
	"skill":  false,
}

## 要烘焙的单位清单。
const TARGETS := [
	{
		"unit_id": "xu_fengnian",
		"char_id": 128,
		"sheet_res": "res://resources/data/units/xu_fengnian_sheet.res",
		"out": "res://resources/data/units/xu_fengnian_sprite_frames.tres",
	},
	{
		"unit_id": "li_chungang",
		"char_id": 182,
		"sheet_res": "res://resources/data/units/li_chungang_sheet.res",
		"out": "res://resources/data/units/li_chungang_sprite_frames.tres",
	},
	{
		"unit_id": "jiang_ni",
		"char_id": 115,
		"sheet_res": "res://resources/data/units/jiang_ni_sheet.res",
		"out": "res://resources/data/units/jiang_ni_sprite_frames.tres",
	},
]


func _init() -> void:
	print("[bake_z_frames] ==== BEGIN ====")
	var ok := 0
	var fail := 0
	for cfg in TARGETS:
		var r := _bake_one(cfg)
		if r:
			ok += 1
		else:
			fail += 1
	print("[bake_z_frames] ==== END: ok=%d fail=%d ====" % [ok, fail])
	quit(0 if fail == 0 else 1)


func _bake_one(cfg: Dictionary) -> bool:
	var unit_id: String = cfg.unit_id
	var char_id: int = cfg.char_id
	var sheet_res_path: String = cfg.sheet_res
	var out_path: String = cfg.out

	print("[bake] unit=%s char=%d" % [unit_id, char_id])

	var anim_data := _load_json("%s/%d/animations.json" % [ASSETS_ROOT, char_id])
	var sprite_data := _load_json("%s/%d/sprites.json" % [ASSETS_ROOT, char_id])
	if anim_data.is_empty() or sprite_data.is_empty():
		push_error("[bake] missing json for char %d" % char_id)
		return false

	# 建 sprite name → region 索引
	var sheet_key := str(char_id)
	if not sprite_data.has(sheet_key):
		# 取第一个 key
		sheet_key = sprite_data.keys()[0]
	var sprite_list: Array = sprite_data[sheet_key].sprites
	var region_by_name: Dictionary = {}
	for s in sprite_list:
		region_by_name[s.name] = Rect2i(s.x, s.y, s.w, s.h)

	var tex: Texture2D = load(sheet_res_path)
	if tex == null:
		push_error("[bake] sheet texture load failed: %s" % sheet_res_path)
		return false

	var sf := SpriteFrames.new()
	# 去掉默认 default 动画
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var anims: Dictionary = anim_data.get("animations", {})

	for semantic in SEMANTIC_MAP.keys():
		var raw_suffix: String = SEMANTIC_MAP[semantic]
		var loop: bool = LOOP_SEMANTICS[semantic]
		for prefix in ["b", "z"]:
			var src_prefix := "B" if prefix == "b" else "Z"
			var src_name := "%s%d_%s" % [src_prefix, char_id, raw_suffix]
			if not anims.has(src_name):
				push_warning("[bake] %s missing anim %s" % [unit_id, src_name])
				continue
			var src: Dictionary = anims[src_name]
			var fps := float(src.get("fps", 8.0))
			var frames: Array = src.get("frames", [])
			var out_name := "%s_%s" % [prefix, semantic]
			sf.add_animation(out_name)
			sf.set_animation_loop(out_name, loop)
			sf.set_animation_speed(out_name, fps)
			for frame_dict in frames:
				var sprite_name: String = frame_dict.get("sprite", "")
				if not region_by_name.has(sprite_name):
					push_warning("[bake] %s frame sprite %s missing region" % [unit_id, sprite_name])
					continue
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(region_by_name[sprite_name])
				sf.add_frame(out_name, at)
			print("  %s: %d frames, fps=%.1f, loop=%s" % [out_name, sf.get_frame_count(out_name), fps, loop])

	var err := ResourceSaver.save(sf, out_path)
	if err != OK:
		push_error("[bake] save %s failed err=%d" % [out_path, err])
		return false
	print("  saved → %s" % out_path)
	return true


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[bake] open failed: %s" % path)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("[bake] JSON parse failed: %s" % path)
		return {}
	return parsed
