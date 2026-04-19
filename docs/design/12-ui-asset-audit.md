# BigWuXia v2 P4 UI 素材盘点与设计提案

## 0. 盘点范围与结论摘要

- 本次实际扫描范围为项目根目录下可用于 UI 的资源目录，而不是不存在的 `assets/`。主要来源为：
  - `Tiny Swords (Free Pack)/UI Elements/UI Elements/`
  - `resources/sprites/ui/`
  - `resources/fonts/`
  - `resources/data/items/`
- 现有项目已经在 `inventory` 和 `character_panel` 两个场景中接入了木桌背景与纸张面板素材，但仍大量依赖运行时 `StyleBoxFlat`、默认 `Button`、硬编码字号与纯色遮罩。
- 素材库能覆盖 P4 的第一阶段统一视觉语言，但覆盖方式更接近“切图重组 + Theme 统一”，而不是直接拿到完整可用的 Godot 9-patch 素材。真正缺口主要有三类：
  - 缺可直接上手的 9-patch 面板和多状态按钮体系
  - 缺中文 UI 字体的备选方案
  - 缺 UI 音效与战斗专用图标体系

## 1. 素材清单

### 1.1 缩略总表

| 类别 | 主要来源 | 现状判断 | 备注 |
| --- | --- | --- | --- |
| 面板 / 边框 | `Papers/`, `Wood Table/`, `Banners/`, `Ribbons/` | 需要切图为主 | 当前没有现成 `.9.png` 或 `StyleBoxTexture` 配置 |
| 按钮 | `Buttons/`, `resources/sprites/ui/` | 可直接用少量，体系化仍需切图 | 只有 regular/pressed，缺 disabled，hover 需复用或调色 |
| 图标 | `Icons/`, `resources/data/items/*.tres`, `Human Avatars/` | 可直接用 | 物品图标覆盖度尚可，属性/装备槽专用图标不足 |
| 进度条 | `Bars/`, `scenes/unit/unit.tscn` | 可直接用少量 | 有底图和填充图，但当前血条仍是纯色 `ProgressBar` |
| 字体 | `resources/fonts/NotoSerifCJKsc-Regular.otf` | 可直接用，但单点风险高 | 当前全项目只此一套中文字体 |
| 装饰元素 | `Ribbons/`, `Banners/`, `Swords/`, `Cursors/`, `WoodTable_Slots`, `Banner_Slots` | 需要切图 | 适合做标题饰条、槽位框、分隔头 |
| UI 音效 | 全仓库扫描 | 缺失需生成 | 未找到 `.wav/.ogg/.mp3` UI 音效 |

### 1.2 9-patch / 面板 / 边框

#### 可直接用

| 资源 | 尺寸 | 路径 | 适合用途 | 说明 |
| --- | --- | --- | --- | --- |
| `RegularPaper.png` | 320x320 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png` | 静态主面板、详情卡、列表卡 | 当前 `inventory` 与 `character_panel` 已直接平铺使用 |
| `SpecialPaper.png` | 320x320 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/SpecialPaper.png` | 弹窗、tooltip、说明板 | 纹理更重，适合高优先级弹窗 |
| `WoodTable.png` | 448x448 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table/WoodTable.png` | 全屏 UI 背景 | 当前背包/角色页已用作底图 |

#### 需要切图

| 资源 | 尺寸 | 路径 | 适合用途 | 切图建议 |
| --- | --- | --- | --- | --- |
| `RegularPaper.png` | 320x320 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png` | 主面板、列表项 | 切为 `StyleBoxTexture`，保留四角与边缘纸纹 |
| `SpecialPaper.png` | 320x320 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/SpecialPaper.png` | 弹窗、剧情提示、tooltip | 做高对比 9-patch，内容区保留空白 |
| `Banner.png` | 448x448 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Banners/Banner.png` | 大标题头、章节名、胜利标题底板 | 可切成标题牌匾与横向头图 |
| `Banner_Slots.png` | 192x192 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Banners/Banner_Slots.png` | 装备槽边框、物品品质框 | 需要拆为四角与中心 |
| `WoodTable_Slots.png` | 192x192 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table/WoodTable_Slots.png` | 槽位卡、行动按钮底板 | 适合小型交互卡片 |
| `BigRibbons.png` | 448x640 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Ribbons/BigRibbons.png` | 分节标题、任务头、角色标签 | 需按颜色和款式逐块裁切 |
| `SmallRibbons.png` | 320x640 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Ribbons/SmallRibbons.png` | 标签、状态徽记、角标 | 适合小范围装饰 |

#### 缺失需生成

| 缺口 | 影响 | 建议 |
| --- | --- | --- |
| 现成 9-patch 面板资源 | 主题落地速度慢 | 先从 `RegularPaper` / `SpecialPaper` 自制 4 套 `StyleBoxTexture` |
| 真正轻量级 tooltip 边框 | 战斗 HUD 易显笨重 | 从纸张切一套窄边框；不够则补一套更薄的卷轴边 |
| 列表项选中态边框 | 当前只能靠 `StyleBoxFlat` 调色 | 从 `Banner_Slots` 或 `WoodTable_Slots` 派生选中框 |

### 1.3 按钮

#### 可直接用

| 资源 | 尺寸 | 路径 | 状态 | 适合用途 |
| --- | --- | --- | --- | --- |
| `BigBlueButton_Regular.png` | 320x320 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigBlueButton_Regular.png` | normal | 主菜单主操作 |
| `BigBlueButton_Pressed.png` | 320x320 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigBlueButton_Pressed.png` | pressed | 主菜单主操作 |
| `BigRedButton_Regular.png` | 320x320 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigRedButton_Regular.png` | normal | 危险操作、退出 |
| `BigRedButton_Pressed.png` | 320x320 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigRedButton_Pressed.png` | pressed | 危险操作、退出 |
| `SmallBlueRoundButton_Regular.png` | 128x128 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallBlueRoundButton_Regular.png` | normal | 圆形次操作 |
| `SmallBlueRoundButton_Pressed.png` | 128x128 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallBlueRoundButton_Pressed.png` | pressed | 圆形次操作 |
| `SmallBlueSquareButton_Regular.png` | 128x128 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallBlueSquareButton_Regular.png` | normal | 列表按钮、页签 |
| `SmallBlueSquareButton_Pressed.png` | 128x128 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallBlueSquareButton_Pressed.png` | pressed | 列表按钮、页签 |
| `SmallRedSquareButton_Regular.png` | 128x128 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallRedSquareButton_Regular.png` | normal | 取消、关闭 |
| `SmallRedSquareButton_Pressed.png` | 128x128 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallRedSquareButton_Pressed.png` | pressed | 取消、关闭 |
| `resources/sprites/ui/button_regular.png` | 320x320 | `resources/sprites/ui/button_regular.png` | normal | 本地引用备用 |
| `resources/sprites/ui/button_pressed.png` | 320x320 | `resources/sprites/ui/button_pressed.png` | pressed | 本地引用备用 |

#### 需要切图

| 资源 | 路径 | 问题 | 建议 |
| --- | --- | --- | --- |
| 全部 320x320 / 128x128 按钮图 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/` | 目前是整张按钮图，不是 Godot 可拉伸按钮 | 切为按钮底板 9-patch，文字仍走 Theme 字体 |
| `TinyRound*` / `TinySquare*` | 同上 | 只有单状态 | 适合图标按钮，不适合主交互体系 |

#### 缺失需生成

| 缺口 | 影响 | 建议 |
| --- | --- | --- |
| disabled 状态图 | 无法统一不可用态 | 先用 normal 降饱和 + 文字变灰；后续补图 |
| 明确 hover 状态图 | PC 交互反馈弱 | 短期通过 normal 图提亮与描边补；长期补 hover 切图 |
| 长条文本按钮 | 选关、战斗技能文本长度不稳定 | 从 `BigBlueButton` 自制可拉伸横向版 |

### 1.4 图标

#### 可直接用

| 资源 | 尺寸 | 路径 | 适合用途 | 现有使用 |
| --- | --- | --- | --- | --- |
| `Icon_01` - `Icon_12` | 64x64 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_*.png` | 物品图标、装备图标、秘籍/丹药图标 | 已绑定到 `resources/data/items/*.tres` |
| `Avatars_01` - `Avatars_25` | 256x256 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_*.png` | 角色头像、立绘裁切 | 项目尚未接入 |
| `Cursor_01` - `Cursor_04` | 64x64 / 128x128 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Cursors/` | 鼠标样式、高亮指针 | 项目尚未接入 |

已被项目物品数据实际引用的图标：

| 图标 | 使用位置 |
| --- | --- |
| `Icon_01` | 草药 |
| `Icon_04` | 金疮药 |
| `Icon_05` | 铁刃 / 春秋刀法 |
| `Icon_06` | 皮甲 |
| `Icon_07` | 内力丹 / 解毒丹 |
| `Icon_08` | 老黄信物 |
| `Icon_10` | 治疗饰品 |
| `Icon_11` | 玉佩 / 医术秘籍 |
| `Icon_12` | 轻身靴 |

#### 需要切图

| 资源 | 路径 | 适合用途 | 说明 |
| --- | --- | --- | --- |
| `Swords.png` | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Swords/Swords.png` | 武器类型图标、职业标签、技能按钮装饰 | 需要拆单个剑形元素 |
| `Banner_Slots.png` | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Banners/Banner_Slots.png` | 品质边框、装备槽图标底座 | 更适合做图标框而非图标本体 |
| `WoodTable_Slots.png` | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table/WoodTable_Slots.png` | 槽位背景、空槽占位图 | 可切空槽与选中槽 |

#### 缺失需生成

| 缺口 | 影响 | 建议 |
| --- | --- | --- |
| 装备槽专用图标 | 角色面板目前只能文字写 `WEAPON/ARMOR/ACC_1/ACC_2` | 需要补武器/护甲/饰品图标 |
| 属性图标 | 战斗和角色面板缺视觉锚点 | 补 HP/MP/气/攻击/防御/轻功/集气图标 |
| 技能图标体系 | 战斗技能按钮仍是纯文本 | 需要补 3-6 个通用技能图标或占位符 |
| 品质边框 | 稀有度表达缺失 | 可先从 `Banner_Slots` 自制，后续补完 |

### 1.5 进度条 / 血条 / 气条

#### 可直接用

| 资源 | 尺寸 | 路径 | 类型 | 适合用途 |
| --- | --- | --- | --- | --- |
| `BigBar_Base.png` | 320x64 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/BigBar_Base.png` | 底图 | 主 HUD HP/MP/气条 |
| `BigBar_Fill.png` | 64x64 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/BigBar_Fill.png` | 填充 | 主 HUD 填充层 |
| `SmallBar_Base.png` | 320x64 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/SmallBar_Base.png` | 底图 | 头像下小血条、单位状态 |
| `SmallBar_Fill.png` | 64x64 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/SmallBar_Fill.png` | 填充 | 小型条形填充层 |

#### 需要切图

| 资源 | 路径 | 用途 | 切图建议 |
| --- | --- | --- | --- |
| `BigBar_*` | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/` | 战场顶部单位信息、角色详情资源条 | Base 保留左右端帽，Fill 做水平拉伸 |
| `SmallBar_*` | 同上 | 单位头顶血条 | 用于替换当前纯绿 `ProgressBar` |

#### 缺失需生成

| 缺口 | 影响 | 建议 |
| --- | --- | --- |
| 独立 MP / 气色版填充 | 只能同一套填充复染色 | 短期调 modulate；长期补蓝/金两套填充图 |
| 受伤 / 护盾 / 过量治疗叠层素材 | 高阶表现不足 | 不影响 P4 首批落地，可后补 |

### 1.6 字体

#### 可直接用

| 资源 | 路径 | 格式 | 中文支持 | 结论 |
| --- | --- | --- | --- | --- |
| `NotoSerifCJKsc-Regular.otf` | `resources/fonts/NotoSerifCJKsc-Regular.otf` | `.otf` | 支持中文 | 当前项目唯一正式 UI 字体 |

#### 需要切图

- 无

#### 缺失需生成

| 缺口 | 影响 | 建议 |
| --- | --- | --- |
| 粗体 / 半粗体中文字体 | 层级只能靠字号和颜色硬拉开 | 增补同家族 Bold 或另一套标题字体 |
| 像素风中文字体备选 | 若后续追求更强像素味会冲突 | 暂不建议 P4 首批引入，避免与现有 serif 混风格 |

### 1.7 装饰元素

#### 可直接用

| 资源 | 路径 | 适合用途 |
| --- | --- | --- |
| `Ribbon_*.png` | `Tiny Swords (Free Pack)/UI Elements/UI Banners from the store page/Ribbons/` | 章节头、状态徽章、角标 |
| `Banner.png` | `Tiny Swords (Free Pack)/UI Elements/UI Banners from the store page/Banner/Banner.png` | 标题底板 |

#### 需要切图

| 资源 | 路径 | 适合用途 | 说明 |
| --- | --- | --- | --- |
| `BigRibbons.png` / `SmallRibbons.png` | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Ribbons/` | 分隔线、子标题条、角标 | 内容较密，需要选样式 |
| `Swords.png` | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Swords/Swords.png` | 标题左右装饰、技能类别标记 | 可提炼“江湖感” |
| `Banner_Slots.png` / `WoodTable_Slots.png` | 见上 | 槽位边框、品质角框 | 更适合做半装饰半功能元素 |

#### 缺失需生成

| 缺口 | 影响 | 建议 |
| --- | --- | --- |
| 细分隔线 | 纸张与纸张之间层次略散 | 从 ribbon 或 sword sheet 抽细长元素 |
| tooltip 小角标 / 稀有度徽记 | 信息表达单调 | 可由现有 ribbon 自制，或后补 AI 小件 |

### 1.8 UI 音效

#### 可直接用

- 无。全仓库未扫描到 `.wav`、`.ogg` 或 `.mp3` 的 UI 音效资源。

#### 需要切图

- 不适用

#### 缺失需生成

| 缺口 | 影响 | 建议 |
| --- | --- | --- |
| hover | 鼠标反馈弱 | P4 后半加入轻木质/纸张摩擦感 UI 音效 |
| click / confirm | 按钮缺确认感 | 至少补主按钮点击与通用确认 |
| cancel / close | 弹窗与返回缺收束感 | 与红色按钮共用一类短音效 |
| equip / unequip | 角色页交互缺记忆点 | 可用轻金属碰撞或布料声 |

## 2. 当前 UI 场景现状表

### 2.1 场景审计

| 场景 | 背景 | 按钮样式 | 字体 / 字号 | 已使用素材 | 现状评价 |
| --- | --- | --- | --- | --- | --- |
| `scenes/main_menu/main_menu.tscn` | `mountain_bg.png` 全屏背景 | 自定义 `StyleBoxFlat` 三态；无贴图按钮 | `NotoSerifCJKsc`，标题 120，按钮 38 | 仅背景图 | 信息结构清楚，但按钮与标题都偏“工程样式” |
| `scenes/level_select/level_select.tscn` | `mountain_bg.png` + `ColorRect` 遮罩 | `StyleBoxFlat` 卡片和按钮，动态关卡按钮复用 `BackButton` 样式 | `NotoSerifCJKsc`，标题 54，按钮 28 | 无 UI 贴图 | 可用但最缺素材化，卡片很像调试菜单 |
| `scenes/inventory/inventory_panel.tscn` | `WoodTable.png` 背景 + 轻遮罩 | 返回/页签/物品卡均为代码生成 `StyleBoxFlat` | `NotoSerifCJKsc`，标题 52，正文 20-34 | `WoodTable`、`RegularPaper`、物品图标 | 已有视觉方向，但仍是“素材底图 + 扁平控件”混搭 |
| `scenes/character_panel/character_panel.tscn` | `WoodTable.png` 背景 + 轻遮罩 | 大量运行时 `Button.new()`，未接贴图按钮 | `NotoSerifCJKsc`，标题 52，正文 17-34 | `WoodTable`、`RegularPaper`、物品图标 | 比背包更像数据面板，槽位文案仍是英文缩写 |
| `scenes/character_panel/equip_select_popup.tscn` | 半透明黑遮罩 | `StyleBoxFlat` 面板 + 默认按钮 | `NotoSerifCJKsc`，标题 28，正文 18-22 | 无 UI 贴图 | 功能完整，但外观与主界面不统一 |
| `scenes/battle/battle.tscn` | 战场地形本体 | 默认 `Button`、默认 `PanelContainer` | `NotoSerifCJKsc`，顶部标签 24，消息 18 | 无 UI 贴图 | 当前最需要重做，界面语言与其余场景断裂 |
| `scenes/battle/item_select_panel.tscn` | 无专用底图 | `StyleBoxFlat` 面板 + 默认按钮 + `ItemList` | `NotoSerifCJKsc`，标题 18 | 无 UI 贴图 | 纯功能面板，贴上素材后收益明显 |
| 战场 HUD (`scenes/unit/unit.tscn`) | 无面板，单位头顶悬浮 | 纯色 `ProgressBar` + 文本 | `NotoSerifCJKsc` 10 | 无 UI 贴图 | 很原型感，和世界美术不在一个层级 |
| `scenes/victory/victory.tscn` | 纯 `ColorRect` | 默认按钮 | `NotoSerifCJKsc`，标题 64，按钮 28 | 无 UI 贴图 | 简陋但改造成本极低 |
| `scenes/defeat/defeat.tscn` | 纯 `ColorRect` | 默认按钮 | `NotoSerifCJKsc`，标题 64，按钮 28 | 无 UI 贴图 | 简陋但改造成本极低 |

### 2.2 优先级打分

打分标准：`5 = 最丑 / 最需要优先重做`，`1 = 暂可接受`

| 场景 | 丑度 | 重做优先级 | 原因 |
| --- | --- | --- | --- |
| 战场 HUD + `battle.tscn` | 5 | P4 Step 2 | 战斗是最高曝光场景，但目前按钮、面板、血条都仍是原型级 |
| `level_select.tscn` | 5 | P4 Step 1 | 入口页之一，却完全没有 UI 贴图支撑 |
| `victory.tscn` / `defeat.tscn` | 5 | P4 Step 1 或 2 | 纯色底 + 默认按钮，视觉完成度最低 |
| `equip_select_popup.tscn` | 4 | P4 Step 3 | 弹窗风格和角色页主面板脱节 |
| `character_panel.tscn` | 4 | P4 Step 3 | 底图已对，但装备槽、属性行、弹窗仍未素材化 |
| `inventory_panel.tscn` | 3 | P4 Step 4 | 已有方向，但需要统一页签、列表项、详情卡样式 |
| `main_menu.tscn` | 3 | P4 Step 1 | 基础构图不错，换按钮和标题牌后收益高 |

## 3. UI 系统架构提案

### 3.1 Theme 资源建议

建议建立一套全局主题资源，例如：

- `resources/ui/theme/main_ui_theme.tres`
- `resources/ui/styleboxes/`
- `resources/ui/icons/`

建议由 `Theme.tres` 统一覆盖以下 base type：

| Base Type | 建议覆盖项 | 说明 |
| --- | --- | --- |
| `Button` | `normal/hover/pressed/disabled/focus`、font、font_size、color | 覆盖主菜单、选关、弹窗、通用按钮 |
| `PanelContainer` | `panel` | 统一主面板 / 弹窗 / tooltip |
| `Label` | title / subtitle / body / caption 方案 | 减少每个场景手填字号 |
| `ItemList` | font、selected/hover 背景 | 用于装备弹窗、战斗物品选择 |
| `ProgressBar` 或 `TextureProgressBar` | 背景、填充 | 替换战场血条 |
| `TabBar` 或 toggle `Button` | 页签样式 | 背包页签可以并入统一方案 |

不建议继续让各场景脚本里手工创建大量 `StyleBoxFlat`。现阶段脚本里这些运行时样式只适合过渡，不适合 P4 的统一素材化。

### 3.2 9-patch StyleBox 映射

建议先做 4 套核心样式：

| 样式名 | 来源图 | 用途 | 风格说明 |
| --- | --- | --- | --- |
| `panel_primary` | `RegularPaper.png` | 主界面卡片、左右栏、背包详情 | 纸张主面板，边浅内亮 |
| `panel_modal` | `SpecialPaper.png` | 弹窗、确认框、胜利/失败板 | 纹理更厚，中心更聚焦 |
| `panel_tooltip` | `SpecialPaper.png` 窄切 | tooltip、技能说明、掉落说明 | 比弹窗更薄、更紧凑 |
| `slot_frame` | `Banner_Slots.png` 或 `WoodTable_Slots.png` | 装备槽、物品品质框、选中态外框 | 功能性边框 |

建议场景映射如下：

| 模式 | 推荐图 |
| --- | --- |
| 主面板 | `RegularPaper` 9-patch |
| 弹窗 | `SpecialPaper` 9-patch |
| tooltip | `SpecialPaper` 简化窄边版 |
| 列表项 | `WoodTable_Slots` / `Banner_Slots` 切出的浅框 |
| 标题牌匾 | `Banner.png` / `BigRibbons.png` |
| 危险按钮 | `BigRedButton` / `SmallRedSquareButton` |
| 普通按钮 | `BigBlueButton` / `SmallBlueSquareButton` |

### 3.3 色彩系统

现有素材主风格是木、纸、旧金属，不适合继续走高饱和纯平 UI。建议色板如下：

| 角色 | 色值建议 | 用途 |
| --- | --- | --- |
| 主色 `paper-gold` | `#E7C98A` | 标题、主按钮高光、分节头 |
| 辅色 `ink-brown` | `#3A2518` | 正文、边框、主文字 |
| 背景深色 `wood-shadow` | `#20140D` | 遮罩、战斗 HUD 背板 |
| 强调色 `jade-blue` | `#4E6E7C` | 普通可点击态、选中态、可交互高亮 |
| 危险色 `cinnabar` | `#9A4B3F` | 退出、取消、失败相关 |
| 治疗 / 正收益 `herb-green` | `#6E8B4A` | HP、增益、正反馈 |

原则：

- 主界面避免再用纯黑半透明大面积 `StyleBoxFlat`。
- 战斗 HUD 尽量用深木色底 + 纸金高亮，保持和世界美术统一。
- 强调色不宜大面积铺满，只用于 hover、选中、可交互指示。

### 3.4 字体方案

#### 选型建议

- 正文与通用 UI：继续使用 `NotoSerifCJKsc-Regular.otf`
- 标题：短期仍沿用同字体，但通过标题牌匾 + 更重描边拉层级
- 中期建议补：
  - `NotoSerifCJKsc-Bold.otf` 或同家族粗体
  - 如果想强化“江湖味”，可额外补一套只用于大标题的书法/碑刻标题字

#### 系统字体 vs 打包字体

- 不建议用系统字体。原因是：
  - 跨平台不稳定
  - 中文字重和字面控制会漂移
  - 不利于视觉统一
- 建议继续打包字体到 `resources/fonts/`

#### 字号层级

| 层级 | 建议字号 | 用途 |
| --- | --- | --- |
| `display` | 72-96 | 主菜单标题、胜利失败标题 |
| `title` | 40-52 | 页面标题、卡片主标题 |
| `section` | 28-34 | 模块标题、弹窗标题 |
| `body` | 20-24 | 列表名称、按钮正文 |
| `caption` | 16-18 | 辅助说明、预览词条、tooltip |
| `micro` | 12-14 | 小数值、角标、资源条数字 |

### 3.5 图标规范

建议建立以下目录与命名规则：

- `resources/ui/icons/items/`
- `resources/ui/icons/slots/`
- `resources/ui/icons/stats/`
- `resources/ui/icons/skills/`

命名规则建议：

- 物品图标：`item_<id>.png`
- 装备槽：`slot_weapon.png`, `slot_armor.png`, `slot_accessory.png`
- 属性：`stat_hp.png`, `stat_mp.png`, `stat_qi.png`, `stat_attack.png`
- 技能：`skill_<id>.png`
- 品质框：`rarity_common.png`, `rarity_rare.png`

来源建议：

| 类型 | 短期来源 | 中期来源 |
| --- | --- | --- |
| 物品图标 | 继续使用 `Icon_01-12` | 后续按具体物品扩图 |
| 角色头像 | `Avatars_01-25` 裁切 | 后续按主角人设定制 |
| 槽位图标 | 从 `Swords.png` + 自制通用轮廓图标 | 补统一手绘图标 |
| 属性图标 | 需要新生成 | 建议补一组风格统一小图标 |
| 品质边框 | `Banner_Slots` / `WoodTable_Slots` 派生 | 后续定制多稀有度版本 |

### 3.6 组件化建议

建议在 P4 内抽出可复用场景，而不是继续完全依赖代码里 `Button.new()` 现场拼 UI。

优先可组件化的模式：

| 组件 | 来源场景 | 价值 |
| --- | --- | --- |
| `DialogPanel` | 胜利 / 失败 / 装备弹窗 | 统一标题、正文、按钮区 |
| `ItemCard` | 背包列表项 | 统一图标、名称、数量、选中态 |
| `EquipSlot` | 角色页装备槽 | 统一图标槽、名称、副词条、点击态 |
| `StatsRow` | 角色页属性行 | 统一标签、数值、加成显示 |
| `ActionButton` | 战斗技能按钮 / 菜单按钮 | 统一按钮主题与图标布局 |
| `TopBanner` | 页面标题、章节头 | 统一标题牌匾与副标题 |
| `UnitBar` | 战场单位头顶状态条 | 统一 HP / MP / 气条呈现 |

## 4. P4 Step 拆分草案

建议按依赖和视觉收益拆成 5 步，每步尽量只动一个主题面。

### Step 1. 建立 UI Theme 基础设施

- 主题：字体层级、基础按钮、主面板、弹窗面板
- 目标文件范围：
  - `resources/ui/theme/main_ui_theme.tres`
  - `resources/ui/styleboxes/*`
- 理由：这是后续所有场景改造的依赖层

### Step 2. 快速替换入口场景

- 主题：主菜单、选关、胜利、失败四个入口与结算页
- 目标文件范围：
  - `scenes/main_menu/`
  - `scenes/level_select/`
  - `scenes/victory/`
  - `scenes/defeat/`
- 理由：改动面相对可控，视觉收益大，能最快建立统一第一印象

### Step 3. 改造角色页与通用弹窗

- 主题：角色页、装备选择弹窗、StatsRow / EquipSlot 组件
- 目标文件范围：
  - `scenes/character_panel/`
  - `scenes/ui/components/`（若新增）
- 理由：当前已有木桌和纸张底，适合从“半成品”升级到完整系统

### Step 4. 改造背包页

- 主题：页签、列表项、详情卡、物品品质边框
- 目标文件范围：
  - `scenes/inventory/`
  - `resources/data/items/`（若补图标映射）
- 理由：背包已有最多素材接入，适合在 Theme 与组件稳定后完成统一

### Step 5. 改造战斗 HUD

- 主题：行动面板、物品选择、顶部回合条、单位头顶血条
- 目标文件范围：
  - `scenes/battle/`
  - `scenes/unit/`
- 理由：最复杂，也最需要先有一套成熟组件和条形资源规范

## 5. 风险与缺口

### 5.1 明确缺什么素材

| 缺口 | 结论 |
| --- | --- |
| 中文字体备选 | 缺。当前只有 `NotoSerifCJKsc-Regular.otf` |
| 装备槽图标 | 缺 |
| 属性图标 | 缺 |
| 技能图标 | 缺 |
| 品质边框 | 缺现成成品，可从 slot 图切一个过渡版 |
| 9-patch 面板 | 缺现成成品，但可从纸张素材切出 |
| UI 音效 | 完全缺失 |
| disabled / hover 按钮图 | 缺完整状态图 |

### 5.2 哪些需求素材库覆盖不了

以下需求无法仅靠现有 Tiny Swords UI 包完整覆盖：

- 角色页四个装备槽的语义化图标
- 战斗技能按钮图标与技能类别图标
- HP / MP / 气 / 攻防轻功等属性图标
- 中文标题风格强化所需的第二字体
- 更细致的 tooltip / 稀有度 / 徽章体系
- 全套 UI 交互音效

这些更适合由美术补图，或先用 AI 生成一版占位资源，再统一手工收边。

### 5.3 过渡策略

P4 改造期间，旧场景短时间内可能更丑，因为 Theme 刚接入时会出现“新按钮 + 旧面板”或“新纸张 + 旧列表项”混搭。建议：

- 优先按完整场景切换，不要在一个场景内长期混用三套风格
- Theme 基础设施先落地，再批量替换按钮，不要一个个局部试
- 对战斗 HUD 尤其避免半成品状态上线，因为它最显眼
- 若必须过渡：
  - 先保持旧 `StyleBoxFlat`，直到对应贴图按钮和面板都准备好
  - 或只先替换全屏背景与标题牌匾，不先动交互控件

## 6. 推荐的 P4 第一步快速胜利

推荐场景：`scenes/level_select/level_select.tscn`

原因：

- 改动面小，结构简单，只有一个主卡片、一组关卡按钮、两个底部按钮
- 当前视觉完成度低，仍是典型 `StyleBoxFlat` 菜单，提升空间非常大
- 可以一次验证 P4 的四项基础资产：
  - 标题牌匾
  - 纸张面板
  - 贴图按钮
  - 字体层级
- 做好后能直接反哺：
  - 主菜单
  - 胜利 / 失败页
  - 装备弹窗

如果要更保守，第二个“快速胜利”备选是 `victory + defeat` 双场景打包改造，但它们对组件沉淀的价值不如选关页高。

## 7. 落地判断

- 可直接开始 P4，不需要等新素材再启动
- 但建议把 P4 第一周目标限定为“建立 Theme + 完成一个入口场景”
- 真正会卡住 P4 后半段的，不是纸张和按钮，而是图标体系与 UI 音效
