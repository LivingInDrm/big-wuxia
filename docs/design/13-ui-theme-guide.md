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

## 默认资源
- 主题文件：`res://resources/ui/theme/main_ui_theme.tres`
- 色板常量：`res://resources/ui/colors.gd`
- 默认字体：`res://resources/fonts/NotoSerifCJKsc-Regular.otf`

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
