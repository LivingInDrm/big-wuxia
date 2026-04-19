extends SceneTree

# 校验：外部 stylebox .tres ↔ main_ui_theme.tres 内嵌 SubResource 严格一致。
# 任何一边改动另一边未跟进 → 红，打印清晰 diff。

const THEME_PATH := "res://resources/ui/theme/main_ui_theme.tres"

# (theme_type, stylebox_name, external_path)
const SYNC_MAP := [
	["Button", "normal", "res://resources/ui/styleboxes/button_blue_normal.tres"],
	["Button", "hover", "res://resources/ui/styleboxes/button_blue_hover.tres"],
	["Button", "pressed", "res://resources/ui/styleboxes/button_blue_pressed.tres"],
	["Button", "disabled", "res://resources/ui/styleboxes/button_blue_disabled.tres"],
	["danger", "normal", "res://resources/ui/styleboxes/button_red_normal.tres"],
	["danger", "hover", "res://resources/ui/styleboxes/button_red_hover.tres"],
	["danger", "pressed", "res://resources/ui/styleboxes/button_red_pressed.tres"],
	["danger", "disabled", "res://resources/ui/styleboxes/button_red_disabled.tres"],
	["PanelContainer", "panel", "res://resources/ui/styleboxes/panel_primary.tres"],
	["modal", "panel", "res://resources/ui/styleboxes/panel_modal.tres"],
	["tooltip", "panel", "res://resources/ui/styleboxes/panel_tooltip.tres"],
	["slot", "panel", "res://resources/ui/styleboxes/slot_frame.tres"],
]

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_theme_sync] ==== BEGIN ====")

	var theme := load(THEME_PATH) as Theme
	_assert(theme != null, "main_ui_theme.tres 可加载")
	if theme == null:
		print("[test_theme_sync] ==== END ==== pass=%d fail=%d" % [_pass, _fail])
		quit(1)
		return

	for entry in SYNC_MAP:
		var theme_type: String = entry[0]
		var sb_name: String = entry[1]
		var ext_path: String = entry[2]
		var label := "%s/%s ↔ %s" % [theme_type, sb_name, ext_path.get_file()]

		var external := load(ext_path) as StyleBoxTexture
		var embedded := theme.get_stylebox(sb_name, theme_type) as StyleBoxTexture

		if not _assert(external != null, "外部 stylebox 可加载: %s" % ext_path):
			continue
		if not _assert(embedded != null, "内嵌 stylebox 可取: Theme.get_stylebox(\"%s\", \"%s\")" % [sb_name, theme_type]):
			continue

		_compare_stylebox(label, external, embedded)

	print("[test_theme_sync] ==== END ==== pass=%d fail=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _compare_stylebox(label: String, ext: StyleBoxTexture, emb: StyleBoxTexture) -> void:
	# texture 身份（用资源路径做比较，规避实例地址差异）
	_assert_eq(label, "texture.resource_path",
		_texture_path(ext.texture), _texture_path(emb.texture))

	# texture_margin（9-patch 源切片）
	_assert_eq(label, "texture_margin_left", ext.texture_margin_left, emb.texture_margin_left)
	_assert_eq(label, "texture_margin_top", ext.texture_margin_top, emb.texture_margin_top)
	_assert_eq(label, "texture_margin_right", ext.texture_margin_right, emb.texture_margin_right)
	_assert_eq(label, "texture_margin_bottom", ext.texture_margin_bottom, emb.texture_margin_bottom)

	# content_margin（内容内缩）
	_assert_eq(label, "content_margin_left",
		ext.get_content_margin(SIDE_LEFT), emb.get_content_margin(SIDE_LEFT))
	_assert_eq(label, "content_margin_top",
		ext.get_content_margin(SIDE_TOP), emb.get_content_margin(SIDE_TOP))
	_assert_eq(label, "content_margin_right",
		ext.get_content_margin(SIDE_RIGHT), emb.get_content_margin(SIDE_RIGHT))
	_assert_eq(label, "content_margin_bottom",
		ext.get_content_margin(SIDE_BOTTOM), emb.get_content_margin(SIDE_BOTTOM))

	# axis_stretch
	_assert_eq(label, "axis_stretch_horizontal",
		ext.axis_stretch_horizontal, emb.axis_stretch_horizontal)
	_assert_eq(label, "axis_stretch_vertical",
		ext.axis_stretch_vertical, emb.axis_stretch_vertical)

	# modulate_color
	_assert_eq(label, "modulate_color", ext.modulate_color, emb.modulate_color)

	# region_rect（未设默认为 Rect2(0,0,0,0)）
	_assert_eq(label, "region_rect", ext.region_rect, emb.region_rect)


func _texture_path(tex: Texture2D) -> String:
	if tex == null:
		return "<null>"
	return tex.resource_path


func _assert(cond: bool, label: String) -> bool:
	if cond:
		_pass += 1
		print("[PASS] %s" % label)
	else:
		_fail += 1
		push_error("[FAIL] %s" % label)
	return cond


func _assert_eq(label: String, field: String, external_val: Variant, embedded_val: Variant) -> void:
	if external_val == embedded_val:
		_pass += 1
		print("[PASS] %s :: %s" % [label, field])
	else:
		_fail += 1
		push_error("[sync FAIL] %s :: %s  external=%s  embedded=%s" % [
			label, field, str(external_val), str(embedded_val)
		])
