extends SceneTree

const UIColors := preload("res://resources/ui/colors.gd")
const THEME_PATH := "res://resources/ui/theme/main_ui_theme.tres"

# 每个外部 StyleBox 完整期望值（与 main_ui_theme.tres 中内嵌 SubResource 的"真值"一致）。
# 注：test_theme_sync.gd 额外校验外部 ↔ 内嵌逐字段一致，这里负责和"数值语义"对齐。
const STYLEBOX_EXPECT := {
	"res://resources/ui/styleboxes/panel_primary.tres": {
		"texture_margin": 32.0,
		"content_margin": [44.0, 36.0, 44.0, 36.0],  # L T R B
		"modulate": Color(1, 1, 1, 1),
	},
	"res://resources/ui/styleboxes/panel_modal.tres": {
		"texture_margin": 32.0,
		"content_margin": [50.0, 42.0, 50.0, 42.0],
		"modulate": Color(1, 1, 1, 1),
	},
	"res://resources/ui/styleboxes/panel_tooltip.tres": {
		"texture_margin": 32.0,
		"content_margin": [28.0, 24.0, 28.0, 24.0],
		"modulate": Color(1, 1, 1, 1),
	},
	"res://resources/ui/styleboxes/slot_frame.tres": {
		"texture_margin": 24.0,
		"content_margin": [18.0, 18.0, 18.0, 18.0],
		"modulate": Color(1, 1, 1, 1),
	},
	"res://resources/ui/styleboxes/button_blue_normal.tres": {
		"texture_margin": 32.0,
		"content_margin": [52.0, 28.0, 52.0, 34.0],
		"modulate": Color(1, 1, 1, 1),
	},
	"res://resources/ui/styleboxes/button_blue_pressed.tres": {
		"texture_margin": 32.0,
		"content_margin": [52.0, 34.0, 52.0, 28.0],
		"modulate": Color(1, 1, 1, 1),
	},
	"res://resources/ui/styleboxes/button_blue_hover.tres": {
		"texture_margin": 32.0,
		"content_margin": [52.0, 28.0, 52.0, 34.0],
		"modulate": Color(1.1, 1.1, 1.1, 1),
	},
	"res://resources/ui/styleboxes/button_blue_disabled.tres": {
		"texture_margin": 32.0,
		"content_margin": [52.0, 28.0, 52.0, 34.0],
		"modulate": Color(0.6, 0.6, 0.6, 0.7),
	},
	"res://resources/ui/styleboxes/button_red_normal.tres": {
		"texture_margin": 32.0,
		"content_margin": [52.0, 28.0, 52.0, 34.0],
		"modulate": Color(1, 1, 1, 1),
	},
	"res://resources/ui/styleboxes/button_red_pressed.tres": {
		"texture_margin": 32.0,
		"content_margin": [52.0, 34.0, 52.0, 28.0],
		"modulate": Color(1, 1, 1, 1),
	},
	"res://resources/ui/styleboxes/button_red_hover.tres": {
		"texture_margin": 32.0,
		"content_margin": [52.0, 28.0, 52.0, 34.0],
		"modulate": Color(1.1, 1.1, 1.1, 1),
	},
	"res://resources/ui/styleboxes/button_red_disabled.tres": {
		"texture_margin": 32.0,
		"content_margin": [52.0, 28.0, 52.0, 34.0],
		"modulate": Color(0.6, 0.6, 0.6, 0.7),
	},
}

# Theme 内嵌 stylebox：(name, theme_type, 对应的外部 .tres 路径)
# 内嵌真值 = 外部 .tres 期望（与 test_theme_sync.gd 的 SYNC_MAP 对齐）
const THEME_STYLEBOXES := [
	["normal", "Button", "res://resources/ui/styleboxes/button_blue_normal.tres"],
	["hover", "Button", "res://resources/ui/styleboxes/button_blue_hover.tres"],
	["pressed", "Button", "res://resources/ui/styleboxes/button_blue_pressed.tres"],
	["disabled", "Button", "res://resources/ui/styleboxes/button_blue_disabled.tres"],
	["normal", "danger", "res://resources/ui/styleboxes/button_red_normal.tres"],
	["hover", "danger", "res://resources/ui/styleboxes/button_red_hover.tres"],
	["pressed", "danger", "res://resources/ui/styleboxes/button_red_pressed.tres"],
	["disabled", "danger", "res://resources/ui/styleboxes/button_red_disabled.tres"],
	["panel", "PanelContainer", "res://resources/ui/styleboxes/panel_primary.tres"],
	["panel", "modal", "res://resources/ui/styleboxes/panel_modal.tres"],
	["panel", "slot", "res://resources/ui/styleboxes/slot_frame.tres"],
	["panel", "tooltip", "res://resources/ui/styleboxes/panel_tooltip.tres"],
]

# Label variations 与期望字号（对照 docs/design/13-ui-theme-guide.md）。
const LABEL_VARIATIONS := {
	"Label": 22,   # 默认 Label = body 层级
	"display": 80,
	"title": 48,
	"section": 30,
	"body": 22,
	"caption": 17,
	"micro": 13,
}

# Type Variation → 期望 base_type
const VARIATION_BASES := {
	"display": "Label",
	"title": "Label",
	"section": "Label",
	"body": "Label",
	"caption": "Label",
	"micro": "Label",
	"danger": "Button",
	"modal": "PanelContainer",
	"tooltip": "PanelContainer",
	"slot": "PanelContainer",
	"bar_hp": "bar",
	"bar_mp": "bar",
	"bar_exp": "bar",
}

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_theme_loads] ==== BEGIN ====")

	var theme := load(THEME_PATH) as Theme
	_assert(theme != null, "main_ui_theme.tres 可加载")
	if theme == null:
		print("[test_theme_loads] ==== END ==== pass=%d fail=%d" % [_pass, _fail])
		quit(1)
		return

	# 外部 stylebox .tres：完整字段断言
	for path in STYLEBOX_EXPECT.keys():
		var sb := load(path) as StyleBoxTexture
		_assert(sb != null, "StyleBox 可加载: %s" % path)
		if sb == null:
			continue
		var exp: Dictionary = STYLEBOX_EXPECT[path]
		_assert_stylebox_full(sb, path, exp["texture_margin"], exp["content_margin"], exp["modulate"])

	# Theme 内嵌 stylebox：按 (type, name) 直接对照外部 .tres 的期望真值
	for entry in THEME_STYLEBOXES:
		var sb_name: String = entry[0]
		var theme_type: String = entry[1]
		var ext_path: String = entry[2]
		var label := "Theme %s/%s" % [theme_type, sb_name]
		var sb := theme.get_stylebox(sb_name, theme_type) as StyleBoxTexture
		_assert(sb != null, "%s 可访问" % label)
		if sb == null:
			continue
		var exp: Dictionary = STYLEBOX_EXPECT[ext_path]
		_assert_stylebox_full(
			sb, label, exp["texture_margin"], exp["content_margin"], exp["modulate"]
		)

	# Label / variations font_size + font_color
	for type_name in LABEL_VARIATIONS.keys():
		var expected_size: int = LABEL_VARIATIONS[type_name]
		_assert(
			theme.get_font_size("font_size", type_name) == expected_size,
			"%s font_size = %d" % [type_name, expected_size]
		)
		_assert(
			theme.get_color("font_color", type_name) == UIColors.INK_BROWN,
			"%s font_color = INK_BROWN" % type_name
		)

	# Button default 四态 font_color
	_assert_button_font_colors(theme, "Button", "默认蓝色按钮")
	# danger 四态 font_color
	_assert_button_font_colors(theme, "danger", "红色危险按钮")

	# Button / danger 默认字号（22）
	_assert(theme.get_font_size("font_size", "Button") == 22, "Button font_size = 22")
	_assert(theme.get_font_size("font_size", "danger") == 22, "danger font_size = 22")

	# Type Variation base_type
	for variation in VARIATION_BASES.keys():
		var expected_base: String = VARIATION_BASES[variation]
		var actual_base := String(theme.get_type_variation_base(variation))
		_assert(
			actual_base == expected_base,
			"variation %s base_type = %s (actual=%s)" % [variation, expected_base, actual_base]
		)

	# Bar 基础类型（Theme Type "bar"）：fill padding 常量 + base/fill 图标
	_assert(theme.has_constant("fill_padding_left", "bar"), "bar 变体存在 fill_padding_left 常量")
	_assert(theme.has_constant("fill_padding_right", "bar"), "bar 变体存在 fill_padding_right 常量")
	_assert(theme.get_constant("fill_padding_left", "bar") == 52, "bar fill_padding_left = 52 (源像素)")
	_assert(theme.get_constant("fill_padding_right", "bar") == 58, "bar fill_padding_right = 58 (源像素)")
	_assert(theme.has_icon("base_texture", "bar"), "bar 变体存在 base_texture 图标")
	_assert(theme.has_icon("fill_texture", "bar"), "bar 变体存在 fill_texture 图标")
	_assert(theme.get_icon("base_texture", "bar") != null, "bar.base_texture 可解析为 Texture2D")
	_assert(theme.get_icon("fill_texture", "bar") != null, "bar.fill_texture 可解析为 Texture2D")

	# bar_hp / bar_mp / bar_exp variations：fill_tint 色相正确
	for variant in ["bar_hp", "bar_mp", "bar_exp"]:
		_assert(theme.has_color("fill_tint", variant), "%s 变体存在 fill_tint 颜色" % variant)

	var hp_tint: Color = theme.get_color("fill_tint", "bar_hp")
	var mp_tint: Color = theme.get_color("fill_tint", "bar_mp")
	var exp_tint: Color = theme.get_color("fill_tint", "bar_exp")
	_assert(hp_tint.r > hp_tint.b and hp_tint.r > hp_tint.g, "bar_hp fill_tint 以红色为主 (r>b, r>g)")
	_assert(mp_tint.b > mp_tint.r and mp_tint.b > mp_tint.g, "bar_mp fill_tint 以蓝色为主 (b>r, b>g)")
	_assert(exp_tint.r > 0.8 and exp_tint.g > 0.6 and exp_tint.b < 0.4, "bar_exp fill_tint 金黄色 (r高 g高 b低)")

	var themed_bar_script := load("res://resources/ui/controls/themed_bar.gd")
	_assert(themed_bar_script != null, "themed_bar.gd 可加载")

	# UIColors 常量
	_assert(UIColors.PAPER_GOLD == Color("#E7C98A"), "UIColors.PAPER_GOLD 常量值正确")
	_assert(UIColors.INK_BROWN == Color("#3A2518"), "UIColors.INK_BROWN 常量值正确")

	print("[test_theme_loads] ==== END ==== pass=%d fail=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _assert(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] %s" % label)
	else:
		_fail += 1
		push_error("[FAIL] %s" % label)


func _assert_eq(label: String, field: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_pass += 1
		print("[PASS] %s :: %s = %s" % [label, field, str(expected)])
	else:
		_fail += 1
		push_error("[FAIL] %s :: %s  actual=%s  expected=%s" % [
			label, field, str(actual), str(expected)
		])


func _assert_stylebox_full(
	sb: StyleBoxTexture,
	label: String,
	expected_texture_margin: float,
	expected_content_margin: Array,
	expected_modulate: Color,
) -> void:
	# axis_stretch
	_assert_eq(label, "axis_stretch_horizontal",
		sb.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH)
	_assert_eq(label, "axis_stretch_vertical",
		sb.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH)

	# texture_margin（四边统一期望值）
	_assert_eq(label, "texture_margin_left", sb.texture_margin_left, expected_texture_margin)
	_assert_eq(label, "texture_margin_top", sb.texture_margin_top, expected_texture_margin)
	_assert_eq(label, "texture_margin_right", sb.texture_margin_right, expected_texture_margin)
	_assert_eq(label, "texture_margin_bottom", sb.texture_margin_bottom, expected_texture_margin)

	# content_margin（LTRB），允许空表示跳过该项
	if expected_content_margin.size() == 4:
		_assert_eq(label, "content_margin_left",
			sb.get_content_margin(SIDE_LEFT), float(expected_content_margin[0]))
		_assert_eq(label, "content_margin_top",
			sb.get_content_margin(SIDE_TOP), float(expected_content_margin[1]))
		_assert_eq(label, "content_margin_right",
			sb.get_content_margin(SIDE_RIGHT), float(expected_content_margin[2]))
		_assert_eq(label, "content_margin_bottom",
			sb.get_content_margin(SIDE_BOTTOM), float(expected_content_margin[3]))

	# modulate_color
	_assert_eq(label, "modulate_color", sb.modulate_color, expected_modulate)


func _assert_button_font_colors(theme: Theme, type_name: String, label: String) -> void:
	_assert_eq(label, "%s font_color" % type_name,
		theme.get_color("font_color", type_name), UIColors.INK_BROWN)
	_assert_eq(label, "%s font_hover_color" % type_name,
		theme.get_color("font_hover_color", type_name), UIColors.INK_BROWN)
	_assert_eq(label, "%s font_pressed_color" % type_name,
		theme.get_color("font_pressed_color", type_name), UIColors.PAPER_GOLD)

	# font_disabled_color：期望 = INK_BROWN 带 0.55 透明度
	var expected_disabled := UIColors.INK_BROWN
	expected_disabled.a = 0.55
	var actual_disabled := theme.get_color("font_disabled_color", type_name)
	_assert_eq(label, "%s font_disabled_color" % type_name,
		actual_disabled, expected_disabled)
