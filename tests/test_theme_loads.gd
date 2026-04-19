extends SceneTree

const UIColors := preload("res://resources/ui/colors.gd")
const THEME_PATH := "res://resources/ui/theme/main_ui_theme.tres"
const STYLEBOX_PATHS := [
	"res://resources/ui/styleboxes/panel_primary.tres",
	"res://resources/ui/styleboxes/panel_modal.tres",
	"res://resources/ui/styleboxes/panel_tooltip.tres",
	"res://resources/ui/styleboxes/slot_frame.tres",
	"res://resources/ui/styleboxes/button_blue_normal.tres",
	"res://resources/ui/styleboxes/button_blue_pressed.tres",
	"res://resources/ui/styleboxes/button_blue_hover.tres",
	"res://resources/ui/styleboxes/button_blue_disabled.tres",
	"res://resources/ui/styleboxes/button_red_normal.tres",
	"res://resources/ui/styleboxes/button_red_pressed.tres",
	"res://resources/ui/styleboxes/button_red_hover.tres",
	"res://resources/ui/styleboxes/button_red_disabled.tres",
]
const STYLEBOX_MARGINS := {
	"res://resources/ui/styleboxes/panel_primary.tres": 32.0,
	"res://resources/ui/styleboxes/panel_modal.tres": 32.0,
	"res://resources/ui/styleboxes/panel_tooltip.tres": 32.0,
	"res://resources/ui/styleboxes/slot_frame.tres": 24.0,
	"res://resources/ui/styleboxes/button_blue_normal.tres": 32.0,
	"res://resources/ui/styleboxes/button_blue_pressed.tres": 32.0,
	"res://resources/ui/styleboxes/button_blue_hover.tres": 32.0,
	"res://resources/ui/styleboxes/button_blue_disabled.tres": 32.0,
	"res://resources/ui/styleboxes/button_red_normal.tres": 32.0,
	"res://resources/ui/styleboxes/button_red_pressed.tres": 32.0,
	"res://resources/ui/styleboxes/button_red_hover.tres": 32.0,
	"res://resources/ui/styleboxes/button_red_disabled.tres": 32.0,
}

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_theme_loads] ==== BEGIN ====")

	var theme := load(THEME_PATH)
	_assert(theme != null, "main_ui_theme.tres 可加载")
	if theme == null:
		print("[test_theme_loads] ==== END ==== pass=%d fail=%d" % [_pass, _fail])
		quit(1)
		return

	for path in STYLEBOX_PATHS:
		var sb := load(path) as StyleBoxTexture
		_assert(sb != null, "StyleBox 可加载: %s" % path)
		_assert(
			sb.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH,
			"%s 横向 axis_stretch = STRETCH" % path
		)
		_assert(
			sb.axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH,
			"%s 纵向 axis_stretch = STRETCH" % path
		)
		_assert(
			sb.texture_margin_left == STYLEBOX_MARGINS[path],
			"%s texture_margin_left = %s" % [path, STYLEBOX_MARGINS[path]]
		)
		_assert(
			sb.texture_margin_top == STYLEBOX_MARGINS[path],
			"%s texture_margin_top = %s" % [path, STYLEBOX_MARGINS[path]]
		)
		_assert(
			sb.texture_margin_right == STYLEBOX_MARGINS[path],
			"%s texture_margin_right = %s" % [path, STYLEBOX_MARGINS[path]]
		)
		_assert(
			sb.texture_margin_bottom == STYLEBOX_MARGINS[path],
			"%s texture_margin_bottom = %s" % [path, STYLEBOX_MARGINS[path]]
		)

	_assert_theme_stylebox(theme.get_stylebox("normal", "Button") as StyleBoxTexture, "Theme Button normal", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("hover", "Button") as StyleBoxTexture, "Theme Button hover", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("pressed", "Button") as StyleBoxTexture, "Theme Button pressed", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("disabled", "Button") as StyleBoxTexture, "Theme Button disabled", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("normal", "danger") as StyleBoxTexture, "Theme danger normal", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("hover", "danger") as StyleBoxTexture, "Theme danger hover", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("pressed", "danger") as StyleBoxTexture, "Theme danger pressed", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("disabled", "danger") as StyleBoxTexture, "Theme danger disabled", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("panel", "PanelContainer") as StyleBoxTexture, "Theme PanelContainer panel", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("panel", "modal") as StyleBoxTexture, "Theme modal panel", 32.0)
	_assert_theme_stylebox(theme.get_stylebox("panel", "slot") as StyleBoxTexture, "Theme slot panel", 24.0)
	_assert_theme_stylebox(theme.get_stylebox("panel", "tooltip") as StyleBoxTexture, "Theme tooltip panel", 32.0)

	_assert(UIColors.PAPER_GOLD == Color("#E7C98A"), "UIColors.PAPER_GOLD 常量值正确")
	_assert(UIColors.INK_BROWN == Color("#3A2518"), "UIColors 常量可访问")

	print("[test_theme_loads] ==== END ==== pass=%d fail=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _assert(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] %s" % label)
	else:
		_fail += 1
		push_error("[FAIL] %s" % label)


func _assert_theme_stylebox(sb: StyleBoxTexture, label: String, expected_margin: float) -> void:
	_assert(sb != null, "%s 可访问" % label)
	if sb == null:
		return

	_assert(
		sb.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH,
		"%s 横向 axis_stretch = STRETCH" % label
	)
	_assert(
		sb.axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH,
		"%s 纵向 axis_stretch = STRETCH" % label
	)
	_assert(
		sb.texture_margin_left == expected_margin,
		"%s texture_margin_left = %s" % [label, expected_margin]
	)
	_assert(
		sb.texture_margin_top == expected_margin,
		"%s texture_margin_top = %s" % [label, expected_margin]
	)
	_assert(
		sb.texture_margin_right == expected_margin,
		"%s texture_margin_right = %s" % [label, expected_margin]
	)
	_assert(
		sb.texture_margin_bottom == expected_margin,
		"%s texture_margin_bottom = %s" % [label, expected_margin]
	)
