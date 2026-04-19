@tool
extends SceneTree

# 一次性脚本：把 Tilemap_color1.png (576x384 = 9x6 @ 64px) 切成 54 张 64x64 PNG
# 输出：tools/catalog/atlas_tiles/x{X}_y{Y}.png  (X=0..8, Y=0..5)
# 用法：godot --headless --script tools/catalog/slice_atlas.gd
# 用完即删。

const SRC_ABS: String = "/Users/xiaochunliu/Downloads/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png"
const OUT_DIR: String = "res://tools/catalog/atlas_tiles"
const TILE: int = 64
const COLS: int = 9
const ROWS: int = 6

func _init() -> void:
	var img := Image.new()
	var err := img.load(SRC_ABS)
	if err != OK:
		push_error("load src failed: %s (err=%d)" % [SRC_ABS, err])
		quit(1)
		return
	if img.get_width() != COLS * TILE or img.get_height() != ROWS * TILE:
		push_error("unexpected size %dx%d, expect %dx%d" % [img.get_width(), img.get_height(), COLS*TILE, ROWS*TILE])
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var count := 0
	for y in ROWS:
		for x in COLS:
			var sub := img.get_region(Rect2i(x * TILE, y * TILE, TILE, TILE))
			var out_path := "%s/x%d_y%d.png" % [OUT_DIR, x, y]
			var abs_path := ProjectSettings.globalize_path(out_path)
			var save_err := sub.save_png(abs_path)
			if save_err != OK:
				push_error("save failed: %s (err=%d)" % [abs_path, save_err])
				quit(1)
				return
			count += 1
	print("[slice_atlas] wrote %d tiles to %s" % [count, OUT_DIR])
	quit(0)
