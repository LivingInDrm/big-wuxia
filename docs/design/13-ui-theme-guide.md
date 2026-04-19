# UI Theme Guide

## Theme Type Variations
| Control | Variation | 用途 |
| --- | --- | --- |
| `Label` | `display` | 主展示标题，80px |
| `Label` | `title` | 区块标题，48px |
| `Label` | `section` | 次级标题，30px |
| `Label` | `body` | 正文，22px |
| `Label` | `caption` | 注释，17px |
| `Label` | `micro` | 微文案，13px |
| `Button` | `danger` | 红色危险按钮 |
| `PanelContainer` | `modal` | 浮层/模态纸张 |
| `PanelContainer` | `tooltip` | 窄边提示纸张 |
| `PanelContainer` | `slot` | 木质槽位框 |
| `ThemedBar` | `bar` | 基础进度条（中性白色调） |
| `ThemedBar` | `bar_hp` | HP 条，红色 |
| `ThemedBar` | `bar_mp` | MP 条，蓝色 |
| `ThemedBar` | `bar_exp` | 经验条，金黄 |

## 默认资源
- 主题文件：`res://resources/ui/theme/main_ui_theme.tres`
- 色板常量：`res://resources/ui/colors.gd`
- 默认字体：`res://resources/fonts/NotoSerifCJKsc-Regular.otf`
- 进度条控件：`res://resources/ui/controls/themed_bar.gd` (`class_name ThemedBar`)

## 按钮怎么用
- 默认 `Button` 不设 variation，即使用蓝色四态按钮。
- 红色危险按钮：`button.theme_type_variation = "danger"`
- 按钮文字默认使用 `INK_BROWN`，按下态文字切到 `PAPER_GOLD`。

## PanelContainer 怎么用
- 默认 `PanelContainer` 不设 variation，即使用 `panel_primary`。
- 模态面板：`panel.theme_type_variation = "modal"`
- 提示面板：`panel.theme_type_variation = "tooltip"`
- 槽位面板：`panel.theme_type_variation = "slot"`

## Label 怎么用
- 默认 `Label` 为 `body` 层级，22px。
- 大标题：`label.theme_type_variation = "display"`
- 标题：`label.theme_type_variation = "title"`
- 小节标题：`label.theme_type_variation = "section"`
- 说明文字：`label.theme_type_variation = "caption"`
- 微文案：`label.theme_type_variation = "micro"`

## 进度条怎么用
`ThemedBar` 继承自 `Range`，因此 `value / max_value / min_value / value_changed` 的语义与 `ProgressBar` / `TextureProgressBar` 完全一致。

```gdscript
var bar := ThemedBar.new()
bar.theme_type_variation = &"bar_hp"
bar.custom_minimum_size = Vector2(320, 64)
bar.max_value = 100.0
bar.value = 75.0
add_child(bar)
```

- 端帽 inset：`bar/constants/fill_padding_left = 52`、`fill_padding_right = 58`（单位为 `bigbar_base.png` 的源图像素）。控件在绘制时按 `size.x / base.width` 自适配缩放，所以条目任意改宽高都会同比例保留端帽 gap。
- 颜色方案：`fill` 贴图（`bigbar_fill_neutral.png`）是灰度图，通过 `bar_<name>/colors/fill_tint` 做 RGB 相乘来染色；新加条目只需加一条 type variation 并指定 `fill_tint`。
- 新增冷却条/读条等：直接在主题里加 `bar_cooldown`、`bar_cast`，指定 `base_type = &"bar"` 和自定义 `fill_tint`，然后 `control.theme_type_variation = &"bar_cooldown"` 即可，**不需要写任何 padding / draw / offset 代码**。
- 极少数场景需要覆盖外观时，可以直接在节点上设置 `base_texture_override`、`fill_texture_override` 或 `fill_tint_override`（`Color(0,0,0,0)` 代表使用主题值）。

## 预览与验收
- 预览场景：`res://scenes/debug/theme_preview.tscn`
- 运行截图：
```bash
godot --path . --script tools/ui_theme_preview_shot.gd -- tools/screenshots/p4_theme_preview.png
```
- Headless 测试：
```bash
godot --headless --path . --script tests/test_theme_loads.gd
```
