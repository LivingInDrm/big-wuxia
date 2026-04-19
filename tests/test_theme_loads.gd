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
	"res://resources/ui/styleboxes/panel_primary.tres": 48.0,
	"res://resources/ui/styleboxes/panel_modal.tres": 56.0,
	"res://resources/ui/styleboxes/panel_tooltip.tres": 32.0,
	"res://resources/ui/styleboxes/slot_frame.tres": 40.0,
	"res://resources/ui/styleboxes/button_blue_normal.tres": 64.0,
	"res://resources/ui/styleboxes/button_blue_pressed.tres": 64.0,
	"res://resources/ui/styleboxes/button_blue_hover.tres": 64.0,
	"res://resources/ui/styleboxes/button_blue_disabled.tres": 64.0,
	"res://resources/ui/styleboxes/button_red_normal.tres": 64.0,
	"res://resources/ui/styleboxes/button_red_pressed.tres": 64.0,
	"res://resources/ui/styleboxes/button_red_hover.tres": 64.0,
	"res://resources/ui/styleboxes/button_red_disabled.tres": 64.0,
}

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_theme_loads] ==== BEGIN ====")

	var theme := load(THEME_PATH)
	_assert(theme != null, "main_ui_theme.tres 可加载")

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
