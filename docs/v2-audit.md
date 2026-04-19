# BigWuXia v2 扩展前审计

更新时间：2026-04-19  
审计范围：`Tiny Swords (Free Pack)/` 素材盘点 + 当前战斗代码基线  
约束遵守：只读审计；未运行测试；未修改现有代码逻辑；未提交 commit

## Executive Summary

- 现有代码已经具备 `Resource + Autoload + SceneManager + BattleScene` 的基础骨架，适合继续扩成 RPG+SRPG，但当前仍是“纯战斗关卡循环”，`GameState` 只保存关卡和通关状态，尚不能承载背包、装备、剧情变量。
- Tiny Swords 免费包对 `UI 素材化`、`世界地图地标`、`小地图/NPC sprite` 有明显帮助，但对 `RPG 物品图标体系`、`对话立绘`、`复杂 overworld tile 套件` 支撑不足。
- 结论是：v2 可做，但应按“属性系统重构 -> 物品/装备 -> UI 素材化 -> overworld/dialogue”顺序推进。若把剧情对话和世界地图提前，会被状态容器和素材缺口反向卡住。

---

## Part 1: Tiny Swords 素材盘点

### 1A. UI 组件

#### 可直接复用的 UI 贴图

| 类别 | 文件路径 | 尺寸 | 9-slice 友好 | 备注 |
| --- | --- | --- | --- | --- |
| 大按钮常态 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigBlueButton_Regular.png` | 320x320 | 是 | 四角装饰集中，中心区干净，适合主菜单/确认按钮 |
| 大按钮按下 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigBlueButton_Pressed.png` | 320x320 | 是 | 可作为 pressed state |
| 大按钮红色 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/BigRedButton_Regular.png` | 320x320 | 是 | 适合危险操作/取消 |
| 小圆按钮 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallBlueRoundButton_Regular.png` | 128x128 | 否 | 更适合固定尺寸 icon button |
| 小方按钮 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/SmallBlueSquareButton_Regular.png` | 128x128 | 弱 | 可小幅缩放，不适合大尺寸拉伸 |
| 微型按钮 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Buttons/TinySquareBlueButton.png` | 64x64 | 否 | 适合 HUD 小图标槽位 |
| 面板纸张 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png` | 320x320 | 是 | 最适合做系统面板、背包窗、对话底板 |
| 特殊纸张 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/SpecialPaper.png` | 320x320 | 是 | 角花更重，适合任务/剧情/稀有提示 |
| 木板面板 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table/WoodTable.png` | 448x448 | 是 | 适合商店、装备、锻造、存档等“功能页” |
| 旗帜面板 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Banners/Banner.png` | 448x448 | 条件式 | 可以裁成标题框，但下缘卷角较强，不适合通用窗口 |
| 栏位装饰 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Banners/Banner_Slots.png` | 192x192 | 否 | 更像固定布局插槽，不适合任意拉伸 |
| 栏位装饰 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table/WoodTable_Slots.png` | 192x192 | 否 | 可做装备槽、道具槽背景 |
| 大血条底 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/BigBar_Base.png` | 320x64 | 是 | 适合 Boss HP / EXP / 剧情进度条 |
| 大血条填充 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/BigBar_Fill.png` | 64x64 | 水平裁切友好 | 建议以裁切或 nine-patch 横向铺开，不做自由缩放 |
| 小血条底 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/SmallBar_Base.png` | 320x64 | 是 | 适合单位条/资源条 |
| 小血条填充 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/SmallBar_Fill.png` | 64x64 | 水平裁切友好 | 同上 |
| 光标 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Cursors/Cursor_01.png` | 64x64 | 否 | 可替换默认鼠标或 SRPG 选点指针 |
| 光标 | `Tiny Swords (Free Pack)/UI Elements/UI Elements/Cursors/Cursor_04.png` | 128x128 | 否 | 更适合选中强调或 hover marker |

#### 辅助装饰素材

- `Tiny Swords (Free Pack)/UI Elements/UI Elements/Ribbons/BigRibbons.png`，448x640  
  推荐用途：章节标题、任务达成、稀有掉落提示。不是通用 panel。
- `Tiny Swords (Free Pack)/UI Elements/UI Elements/Ribbons/SmallRibbons.png`，320x640  
  推荐用途：小标签、阵营标、状态条角标。
- `Tiny Swords (Free Pack)/UI Elements/UI Elements/Swords/Swords.png`，448x640  
  推荐用途：装饰性标题牌、章节封面，不适合业务 UI。
- `Tiny Swords (Free Pack)/UI Elements/UI Banners from the store page/Banner/Banner.png`，448x448  
  与主 `Banners/Banner.png` 同类，可作替代配色资源。
- `Tiny Swords (Free Pack)/UI Elements/UI Banners from the store page/Ribbons/*.png`  
  推荐用途：章节色带、战报标签。

#### 缺口判断

- 字体：素材包内未发现 `.ttf/.otf`，当前项目仍依赖 `resources/fonts/NotoSerifCJKsc-Regular.otf`。
- 真正的对话框九宫格：没有现成、标准化的“对话框边框九切图”，最接近的是 `RegularPaper` / `SpecialPaper` / `WoodTable`。
- 图标槽背景：可以用 `Banner_Slots` / `WoodTable_Slots` 做固定槽位，但数量和形态有限。

### 1B. 图标

#### 现有图标资产

| 文件路径 | 尺寸 | 推荐用途 |
| --- | --- | --- |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_01.png` | 64x64 | 伐木/材料采集/工艺 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_02.png` | 64x64 | 木材/原木/建材 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_03.png` | 64x64 | 金币/货币 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_04.png` | 64x64 | 肉类/食物/恢复品 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_05.png` | 64x64 | 单手剑/攻击/武器分类 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_06.png` | 64x64 | 防御/护甲/护盾 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_07.png` | 64x64 | 药剂/毒物/状态道具 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_08.png` | 64x64 | 号角/行动号令/任务提示 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_09.png` | 64x64 | 战斗/交锋/攻击菜单 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_10.png` | 64x64 | 设置/打造/系统 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_11.png` | 64x64 | 信息/属性页/单位详情 |
| `Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_12.png` | 64x64 | 音乐/声音设置 |

#### 适配 RPG/SRPG 的结论

- 可覆盖：
  - 金币
  - 基础武器/防御
  - 恢复类消耗品
  - 系统菜单/信息/设置
- 缺失严重：
  - 没有完整的武器谱系图标，无法覆盖刀、剑、枪、弓、内功、饰品等多装备树
  - 没有明确的属性图标集合，HP/ATK/DEF/MOV/SPD 只能借用 `剑/盾/信息`，语义不够稳
  - 没有足够的稀有材料、丹药、秘籍、护符等图标

#### 审计建议

- v2 前半段可先用 `Icon_05/06/03/04/07/11` 组成最小可用系统。
- 若要正式上“装备 + 背包 + 商店 + 掉落”，必须补一套更完整的 item icon 包，Tiny Swords 不能单独撑满该系统。

### 1C. Character Sprites（非战斗单位）

#### 当前项目实际已用单位

当前已接入资源的战斗单位只有 5 个逻辑 ID：

- 玩家：`xu_fengnian`、`jiang_ni`、`li_chungang`
- 敌方：`enemy_soldier`、`yang_yuanzan`

其资源都来自两套战斗帧：

- `resources/data/units/warrior_sprite_frames.tres`
- `resources/data/units/monk_sprite_frames.tres`

#### 素材包内可新增为 NPC / 大地图角色的 Sprite 类别

| 分类 | 可用素材路径 | 尺寸特征 | 推荐角色设定 |
| --- | --- | --- | --- |
| 武士/江湖客 | `Tiny Swords (Free Pack)/Units/* Units/Warrior/*.png` | 192 高帧图 | 镖师、刀客、护院、门派弟子 |
| 弓手/巡逻兵 | `Tiny Swords (Free Pack)/Units/* Units/Archer/*.png` | `Idle 1152x192`, `Run 768x192`, `Shoot 1536x192` | 守卫、猎户、弓队、侦察兵 |
| 僧/术士/医者 | `Tiny Swords (Free Pack)/Units/* Units/Monk/*.png` | `Idle 1152x192`, `Heal 2112x192` | 医师、方士、道门弟子、治疗 NPC |
| 枪兵/卫队长 | `Tiny Swords (Free Pack)/Units/* Units/Lancer/*.png` | 320 高大体型帧 | 官兵、禁军、寨门守卫、精英敌兵 |
| 村民/劳工/商人 | `Tiny Swords (Free Pack)/Units/* Units/Pawn/*.png` | `Idle 1536x192`, `Run 1152x192` | 村民、伐木工、矿工、挑夫、基础商人 |

#### 推荐映射

- 武士：
  - `.../Warrior/*.png`
  - 适合有姓名 NPC、可加入角色、低阶敌将
- 法师/医者：
  - `.../Monk/*.png`
  - 适合药师、道姑、术士、辅助型同伴
- 村民：
  - `.../Pawn/Pawn_Idle.png`
  - 适合普通路人、农户、采集者
- 商人：
  - `.../Pawn/Pawn_Idle Gold.png`
  - 直接可做行商、钱庄掌柜、摊贩
- 特殊角色：
  - `.../Pawn/Pawn_Idle Knife.png`
  - 可做黑市、刺客线 NPC
  - `.../Pawn/Pawn_Idle Pickaxe.png`
  - 可做矿工/工匠
  - `.../Pawn/Pawn_Idle Wood.png`
  - 可做樵夫/驿站杂役
  - `.../Archer/*.png` / `.../Lancer/*.png`
  - 可做城防势力与地域 faction 区分

#### 结论

- 作为“大地图 walking sprite / NPC 站姿”，素材是够的。
- 作为“剧情立绘/半身像”，这些单位帧不够，因为它们是战棋俯视感 sprite sheet，不是 portrait。

### 1D. 大地图素材

#### 已有资源

##### Settlement / Landmark

- `Tiny Swords (Free Pack)/Buildings/Blue Buildings/House1.png`，128x192
- `Tiny Swords (Free Pack)/Buildings/Blue Buildings/House2.png`，128x192
- `Tiny Swords (Free Pack)/Buildings/Blue Buildings/House3.png`，128x192
- `Tiny Swords (Free Pack)/Buildings/Blue Buildings/Tower.png`，128x256
- `Tiny Swords (Free Pack)/Buildings/Blue Buildings/Archery.png`，192x256
- `Tiny Swords (Free Pack)/Buildings/Blue Buildings/Barracks.png`，192x256
- `Tiny Swords (Free Pack)/Buildings/Blue Buildings/Monastery.png`，192x320
- `Tiny Swords (Free Pack)/Buildings/Blue Buildings/Castle.png`，320x256

同款还有 `Black / Red / Yellow / Purple` 五套配色，可用于不同城镇阵营。

##### Terrain / Tile

- `Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png`，576x384
- `Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color2.png`，576x384
- `Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color3.png`，576x384
- `Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color4.png`，576x384
- `Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color5.png`，576x384
- `Tiny Swords (Free Pack)/Terrain/Tileset/Water Background color.png`，64x64
- `Tiny Swords (Free Pack)/Terrain/Tileset/Water Foam.png`，3072x192

##### Decorative

- 岩石：`Terrain/Decorations/Rocks/*.png`
- 灌木：`Terrain/Decorations/Bushes/*.png`
- 云：`Terrain/Decorations/Clouds/*.png`
- 水中岩石：`Terrain/Decorations/Rocks in the Water/*.png`
- 树/树桩：`Terrain/Resources/Wood/Trees/*.png`
- 羊：`Terrain/Resources/Meat/Sheep/*.png`
- 金矿/金石：`Terrain/Resources/Gold/...`

#### 是否足够做大地图

可支撑：

- 一个乡野区域的小型 overworld
- 村庄 / 小镇 / 城堡 / 寺庙 / 军营等 POI 标记
- 道路、草地、水体、树林、障碍基础地貌
- 简单装饰生态

不够支撑：

- 多地域、多生物群系世界地图
- 明确的山脉轮廓层、峡谷、雪地、沙地、荒漠、室内入口、码头、桥群、城门等系统化地标
- JRPG 式大世界的连贯道路网与地标语言

#### 缺什么

- 专门的 world map road 套路图块不够丰富
- 缺室内/城内 tileset
- 缺交通节点，如驿站、桥头、关隘、码头、城门
- 缺剧情互动物件，如告示牌、车队、神龛、墓碑、篝火
- 缺 region differentiation 所需的第二、第三生物群系

#### 结论

- 做 `P5 的 1 张原型 overworld` 足够。
- 做“章节制世界地图 + 多区域旅行”不够，后续必须补免费包或自制图块。

### 1E. 对话框 / 立绘

#### 可用对话框背景

- `Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png`
- `Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/SpecialPaper.png`
- `Tiny Swords (Free Pack)/UI Elements/UI Elements/Wood Table/WoodTable.png`
- `Tiny Swords (Free Pack)/UI Elements/UI Elements/Banners/Banner.png`

推荐：

- 常规对白框：`RegularPaper`
- 剧情/抉择/任务框：`SpecialPaper`
- 商店/装备/背包：`WoodTable`
- 章节标题或角色登场牌：`Banner`

#### 半身像 / 头像素材

- 有职业/阵营头像：`Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_01.png` 到 `Avatars_25.png`
- 这些头像本质上是“同职业不同配色徽章头像”，不是角色立绘，不适合承担剧情表演。

可用作：

- 阵营标
- 招募页头像
- 职业图鉴
- 小队列表头像

不适合：

- 对话演出中的人物情绪立绘
- 多角色剧情镜头

#### 后续方案建议

默认建议：

1. 短期：先用 `纯文字 + 名字牌 + 小头像`。  
2. 中期：若剧情占比上升，再补“半身像方案”。  
3. 若预算为零：找一套免费 portrait pack 或自行做统一风格头像。  
4. 若允许 AI：用 AI 生图出角色半身像，但必须先固定角色设定表，避免前后风格漂移。  

推荐默认值：

- v2 第一版采用：`对话框背景 + 小头像 + 纯文字`
- 不建议一开始就上 AI 立绘，因为会把 P5 的不确定性放大

---

## Part 2: 现有战斗代码基线审计

### 2A. 属性字段现状

#### 静态属性字段

`scripts/core/unit_data.gd:17-39` 在审计时定义的单位静态字段包括：

- 身份：`unit_id`, `unit_name`, `is_enemy`
- 属性：旧版平铺战斗/行动字段
- 战斗：`weapon_type`, `weapon_range`
- 技能：`skill_ids`
- 动画：`sprite_frames`, `sprite_offset`, `modulate`

这是典型的“平铺属性表”结构，尚未区分：

- 基础值
- 装备加成
- buff / debuff
- 成长值
- 衍生值

#### 运行时属性

`scenes/unit/unit.gd:24-30` 当前运行时只维护：

- `current_hp`
- `current_position`
- `acted`
- `skills`
- `temp_move_bonus`

也就是说，目前唯一显式存在的临时修正只有移动加成：

- `get_current_mov()`：`scenes/unit/unit.gd:267-268`
- `set_move_buff()`：`scenes/unit/unit.gd:271-273`
- `clear_temp_buffs()`：`scenes/unit/unit.gd:276-278`

#### 战斗公式在哪里

伤害与命中公式集中在：

- `scripts/systems/combat_system.gd:21-47`

当前公式使用的输入包括：

- 攻方：旧版攻击平铺字段
- 守方：旧版防御平铺字段
- 射程：通过外部 `weapon_range` 控制攻击范围，不参与伤害公式
- 地形：`dodge_bonus`, `def_bonus`
- 武器克制：`WeaponTypes.counter_multiplier(...)`
- 技能倍率：`skill.power`

当前没有被统一整合进结果层的维度包括：

- 旧版速度字段没有进入命中、追击、先后手
- 旧版移动字段只用于行动范围
- 生命上限只用于资源封顶

#### 三层模型改造工作量评估

目标模型：

- Base：角色基础值
- Equipment：装备修正
- Buff：状态修正

评估：`M`

原因：

- 好处：当前字段少、调用点集中，易改
- 风险：不少逻辑直接从 `unit_data` 取值，改造后必须统一经过“最终属性访问器”

建议实现方式：

1. 在 `UnitData` 中保留“基础模板值”。  
2. 在 `Unit` 或独立 `StatBlock`/`UnitRuntimeState` 中维护：
   - `base_stats`
   - `equipment_mods`
   - `buff_mods`
3. 统一提供：
   - `get_max_hp()`
   - `get_atk()`
   - `get_def()`
   - `get_spd()`
   - `get_mov()`
4. 将 `CombatSystem`、`BattleController`、技能执行器改成只读统一 getter。  

如果这样做，后续物品/装备系统会顺很多；否则每加一个装备位都会把战斗逻辑继续耦死在 `unit_data` 上。

### 2B. 场景架构现状

#### 现有场景列表

当前只有 6 个场景：

- `scenes/main_menu/main_menu.tscn`
- `scenes/level_select/level_select.tscn`
- `scenes/battle/battle.tscn`
- `scenes/victory/victory.tscn`
- `scenes/defeat/defeat.tscn`
- `scenes/unit/unit.tscn`

没有：

- overworld
- dialogue
- inventory
- equipment
- character status
- shop

#### SceneManager 怎么切场景

`autoload/scene_manager.gd:14-43`

特点：

- 单入口：`change_scene_to_file(path)`
- 带黑幕淡入淡出
- 不传 payload
- 不维护 scene stack

这意味着当前切场是“无状态 payload 切换”，状态只能落 Autoload。

#### 状态传递方式

当前主要通过 `GameState.current_level` 驱动战斗载入：

- `autoload/game_state.gd:10-12`
- `scenes/battle/battle_controller.gd:478-486`

`GameBalance` 负责读取 `.tres` 资源：

- `autoload/game_balance.gd:22-26`

#### 加入 overworld + dialogue 的难度

评估：

- overworld：`M`
- dialogue：`S-M`

原因：

- SceneManager 自身够用，切场不是阻碍
- 真正阻碍是状态容器太薄，需要记录：
  - 当前章节
  - 当前地图节点
  - 角色列表
  - 背包
  - 装备
  - 剧情变量
  - 对话分支结果

#### GameState 能否扩展成“角色包袱/装备/属性”容器

可以，但当前还是空骨架：

- `autoload/game_state.gd:10-12` 只有 `current_level / selected_characters / completed_levels`

扩展建议：

- `party: Array[String]` 或 `Array[CharacterRuntimeState]`
- `inventory: Dictionary[item_id -> count]`
- `equipment_by_character: Dictionary[char_id -> slot_map]`
- `story_flags: Dictionary[String -> Variant]`
- `overworld_state: Dictionary`
- `gold: int`

评估：`可扩，但需要先定义数据边界`

不建议直接把所有运行时对象全塞进 `GameState`。更稳妥的是：

- `GameState` 保存纯数据
- 战斗/地图场景运行时节点在场景内实例化

### 2C. UI 现状

#### 战斗 UI 组件列表

按 `scenes/battle/battle.tscn:27-98` 与 `scenes/battle/battle_ui.gd:5-63`，当前战斗 UI 包括：

- 顶部回合标签 `TurnLabel`
- 中上消息文本 `MessageLabel`
- 左下技能面板 `ActionPanel`
- 三个技能按钮 `Skill1Button/Skill2Button/Skill3Button`
- 范围高亮 `RangeOverlay`（不是贴图 UI，而是程序生成色块）
- 单位头顶血条 `scenes/unit/unit.tscn:21-48`
- 单位 acted 遮罩与选中指示 `scenes/unit/unit.tscn:50-58`

#### 哪些用 Tiny Swords，哪些是占位

已经用到 Tiny Swords 的部分：

- 单位动画：项目内 `resources/sprites/units/...` 来自 Tiny Swords 裁切资源
- 地形图块：项目内 `resources/sprites/terrain/tilemap_color1.png` 来自 Tiny Swords
- VFX：`resources/sprites/vfx/...` 来自 Tiny Swords

没用上 Tiny Swords、仍是占位/程序风格的部分：

- `ActionPanel`：无贴图，仅默认 `PanelContainer`
- 技能按钮：Godot 默认 Button
- 回合/消息框：纯文字，无背景
- 单位血条：`StyleBoxFlat + ProgressBar`
- 选中/已行动：简单几何控件
- 主菜单与选关：自定义 `StyleBoxFlat` 而非贴图按钮  
  见：
  - `scenes/main_menu/main_menu.tscn:7-65`
  - `scenes/main_menu/main_menu.tscn:144-172`
  - `scenes/level_select/level_select.tscn:7-29`
  - `scenes/level_select/level_select.tscn:68-113`

#### 素材化优先级排序

1. 战斗技能面板与消息框  
原因：出镜率最高，且与 v2 的物品/装备/属性系统直接相关。

2. 单位血条与状态标记  
原因：当前程序条风格最“占位”，且最影响战斗观感。

3. 主菜单/选关按钮面板  
原因：已有一定风格，但与 Tiny Swords 体系不统一。

4. 胜利/失败页  
原因：页面少，优先级低。

5. 范围高亮  
原因：现有色块可用，后期可再做更精致 tile overlay。

---

## Part 3: Phase 拆分建议

### P1 属性系统重构

工作量：`M`

任务清单：

- 引入统一运行时属性访问层，停止在战斗公式中直接读旧版平铺字段
- 定义基础值 / 装备修正 / buff 修正三层结构
- 把 `current_hp` 与 `max_hp` 的关系收敛到最终属性接口
- 让技能、地形、装备后续都能挂到同一结算面
- 为速度维度决定用途：命中、闪避、先手、暴击、追击至少选一种

交付标准：

- 现有战斗仍能跑现有两关
- `CombatSystem`、`BattleController`、`Unit` 不再散落读取基础字段

### P2 物品系统

工作量：`M`

任务清单：

- 定义 `ItemData`
- 定义 item 分类：消耗品、材料、任务物品、装备
- 在 `GameState` 增加背包容器
- 加入基础 API：获得、消耗、查询、堆叠
- 接入 3-5 个最小物品种子
- 预留战斗内/战斗外使用边界

交付标准：

- 能在数据层稳定存取物品
- UI 可以只做简版列表，不要求一开始就是完整背包页

### P3 装备系统

工作量：`M`

任务清单：

- 定义 `EquipmentData`
- 定义装备槽位
- 角色装备映射写入 `GameState`
- 装备加成接到 P1 的属性三层模型
- 处理武器类型/射程/属性修正
- 预留“唯一装备/剧情装备”标记

交付标准：

- 装备能真实改动战斗面板和公式
- 至少支持武器、防具、饰品三类

### P4 UI 素材化

工作量：`M`

任务清单：

- 用 Tiny Swords 纸张/木板重做：
  - 战斗技能面板
  - 消息框
  - 背包页
  - 装备页
  - 角色属性页
- 用条形素材重做 HP/EXP
- 用小图标替换一部分系统按钮
- 保留当前 Noto Serif 字体，统一材质语言

交付标准：

- 战斗 UI 不再出现明显 Godot 默认控件感
- 背包/装备界面能支撑用户决策

### P5 大地图 + 对话 + 剧情

工作量：`L`

任务清单：

- 新增 `overworld.tscn`
- 新增 `dialogue` 场景或控件系统
- 建立 overworld 节点/地图点状态
- 接入 POI：村庄、城堡、寺庙、战斗入口
- 对话系统支持：
  - 说话人
  - 名字牌
  - 文本分页
  - 分支 flag
- 将战斗前后与剧情衔接

交付标准：

- 至少完成一条“主城 -> 对话 -> 出战 -> 胜后返回”的闭环

风险：

- 这一阶段最容易被立绘方案和世界地图素材缺口拖慢

### P6 收官

工作量：`S-M`

任务清单：

- 数据整理与填充
- UI 细修
- 新手引导与默认物品/装备发放
- 文案统一
- 补必要测试或最小回归脚本
- 调整数值节奏

交付标准：

- v2 功能闭环稳定
- 内容虽然不大，但体验完整

---

## Part 4: 用户需拍板清单

### 1. 属性维度

推荐默认值：`偏武侠风味，但保持通用 SRPG 骨架`

建议字段：

- 核心战斗：生命、攻击、防御、移动、速度
- 武侠味补充：`nei`（内力）或 `qi`（真气），二选一

不建议首版就上过多维度，例如：

- 根骨
- 悟性
- 身法
- 魅力
- 福缘

理由：

- 这些维度会直接拉高装备、技能、升级、UI 展示复杂度
- 当前代码并没有成长系统和二级公式，先上 6 维内更稳

推荐方案：

- `HP / 攻 / 防 / 速 / 移 / 气`

### 2. 装备槽位数量

推荐默认值：`4 槽`

- 武器
- 防具
- 饰品 1
- 饰品 2

理由：

- 既能体现 RPG build，又不至于把 UI 和掉落池做爆
- 比“武器/衣服/鞋/头/项链/戒指*2”更适合 v2 首版

备选保守方案：`3 槽`

- 武器 / 防具 / 饰品

如果 Manager 要求更快交付，可以退到 3 槽。

### 3. 初始物品种子

推荐默认值：

- `healing_herb` x5
- `revive_pellet` x1
- `iron_sword` x1
- `cloth_robe` x1
- `travel_token` x1 或剧情任务物品 x1

理由：

- 能同时验证：
  - 消耗品
  - 装备
  - 稀有一次性物品
  - 任务物品

### 4. 对话立绘方案

推荐默认值：`先不上半身立绘，先用对话框 + 名字牌 + 小头像`

实现建议：

- 对话框：`RegularPaper` / `SpecialPaper`
- 小头像：`Human Avatars` 或角色专属裁图
- 大立绘：v2 首版不做

理由：

- 这是当前素材最明显的缺口
- 若强上 AI 立绘，会引入角色风格统一、迭代成本、提示词管理等额外工作

---

## 建议的默认决策包

如果 Manager 和用户暂时不想开太多会，建议直接采用以下默认包：

- 属性：`HP / 攻 / 防 / 速 / 移 / 气`
- 槽位：`4 槽`
- 初始物品：`5 个草药 + 1 个复苏丹 + 2 件初始装备 + 1 个任务物品`
- 对话方案：`纸张对话框 + 小头像 + 纯文字`
- Overworld 范围：`一张村镇原型地图 + 2~3 个地标点`

---

## 关键结论

### 可行

- v2 的 RPG+SRPG 扩展在当前代码基线之上是可行的。
- 现有项目最适合先做“系统层重构”，再接 UI 和场景层。

### 可直接利用的素材优势

- UI 面板与按钮素材够用
- 村镇/城堡地标素材够用
- NPC / overworld walking sprite 够用

### 明确缺口

- 物品/装备图标体系不够
- 对话立绘没有
- 大世界地貌和区域化 tileset 不够

### 推荐推进顺序

- 先做 P1-P3
- 再做 P4
- 最后做 P5

这是当前风险最低、返工最少的路径。
