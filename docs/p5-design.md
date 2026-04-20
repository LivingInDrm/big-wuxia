# P5 详细设计：大地图 + 对话系统

更新时间：2026-04-21
适用版本：big-wuxia v2（基于 P1-P4 已落地的战斗/物品/装备/UI 素材化之上）
前置文档：`docs/v2-audit.md`（素材盘点 + 基线审计）
约束遵守：本文档只描述设计，不包含任何实现代码；实际实现在 P5 各 Sprint 落地。

> 本文基于用户在任务拍板时已经决定的前置条件：
>
> 1. 大地图形态：玩家自由行走 overworld + 多个 POI 子地图，每个 POI 可进入/离开。
> 2. 首版 3 个 POI：**北凉王府、武当山、清凉山**。
> 3. 对话数据存储：`.tres`（Godot Resource，沿用项目现有 UnitData/ItemData/LevelData 做法）。
> 4. 剧情脚本由 AI 直接写，本文要给 AI 一个可复用的写作模板。
> 5. 任务系统不做，第一版靠对话 + flag 驱动线性推进。
>
> 两处由本文档决策：
>
> - **flag 持久化容器**（§4.2）：选择挂在 `GameState.dialogue_flags`，而非独立 Autoload。
> - **overworld ↔ POI ↔ battle 三层切换协议**（§5）：定义 `LocationStack` + `GameState.return_context`。
>
> 所有选型均附 2-3 个备选方案 + 理由。

---

## 0. Executive Summary

P5 在 v2 的收官阶段把 big-wuxia 从“纯战斗关卡循环”升级成“有世界感的武侠 SRPG”。核心交付是：

- 一张玩家自由走动的 `overworld.tscn`，摆 3 个 POI 地标。
- 每个 POI 独立 `.tscn`（**方案 A 胜出**，见 §1），内部摆 NPC。
- 一套以 `.tres` 承载的对话系统：支持说话人切换、分支选项、依赖 flag 的条件分支、写入 flag、触发事件（给物品、开启 POI、启动战斗）。
- 一个最小可玩主线闭环：**北凉王府（徐凤年出场对白）→ 武当山（遇洪洗象）→ 武当山触发 level_01 战斗 → 胜后返回武当山 → 解锁清凉山**。
- 供 AI 批量写分镜的 Markdown 剧本模板（§4.4）。

**显式不做**：主线任务面板、声望系统、动态天气、世界地图多区域、商店 NPC（P4 商店如有需要走 POI 内子面板而非新系统）。

**整体工作量**：`L`（与 audit 中的 P5 评估一致），建议拆成 5 个 Sprint（§8）。

---

## 1. 场景架构

### 1.1 场景层级总览

```
MainMenu (existing: scenes/main_menu/main_menu.tscn)
  └── [点击"继续旅程"] → Overworld
Overworld (new: scenes/overworld/overworld.tscn)
  ├── [与 POI Marker 交互] → POI Map
  └── [ESC/菜单] → MainMenu
POI Map (new: scenes/overworld/poi_map_<id>.tscn × N)
  ├── [与 NPC 交互] → Dialogue (覆盖层)
  ├── [对话触发 start_battle] → Battle
  └── [离开按钮 / 地图边缘] → Overworld
Battle (existing: scenes/battle/battle.tscn)
  ├── [胜利] → Victory → Overworld / POI（由 return_context 决定）
  └── [失败] → Defeat → POI 或 MainMenu（由 return_context 决定）
Dialogue (new: scenes/dialogue/dialogue_box.tscn，不是独立场景而是 CanvasLayer 覆盖层)
```

### 1.2 `overworld.tscn` 节点结构

```
Overworld (Node2D, script: overworld_root.gd)
├── Background                          (Sprite2D / TileMap，山水背景)
│   └── WorldTileMap                    (可选：用 Tilemap_color1.png 铺一层大地)
├── POINodes                            (Node2D 容器)
│   ├── POI_Beiliang                    (POIMarker 节点，挂 POIData)
│   ├── POI_Wudang                      (POIMarker 节点)
│   └── POI_Qingliang                   (POIMarker 节点，初始 locked)
├── OverworldNPCs                       (Node2D 容器，可选：路人)
├── Player                              (OverworldPlayer 节点，见 §1.4)
├── Camera2D                            (跟随 Player，限制在世界范围内)
└── UILayer (CanvasLayer)
    ├── LocationHint                    (显示当前附近的 POI 名字)
    ├── InteractionHintProxy            (统一"按 E"提示的路由层)
    └── PauseMenu                       (ESC 打开，返回主菜单)
```

**关键协作**：
- `POIMarker` 是一个带 `Area2D` 的节点（见 §2.3），玩家进入范围 → UILayer 显示"按 E 进入武当山"。
- `Camera2D` 的 `limit_*` 绑定到 `WorldTileMap` 的范围，玩家不能走出地图。

### 1.3 `poi_map_<id>.tscn` 模板（方案选择）

**方案 A：每个 POI 独立 `.tscn`**（✅ 选）
- 每个 POI 一个独立场景文件：`scenes/overworld/poi_map_beiliang.tscn`、`poi_map_wudang.tscn`、`poi_map_qingliang.tscn`。
- 共享一个基类脚本 `scripts/systems/poi_map_root.gd` 挂在根节点上（处理玩家生成、NPC 交互路由、离开逻辑）。
- 地图布局、建筑位置、NPC 摆放都在 Godot 编辑器里可视化编辑。

**方案 B：单一 `poi_map.tscn` + 从 POIData 读取布局**
- 所有 POI 共用一个 `.tscn`，根据 `POIData.layout_resource`（一个 Resource）动态生成建筑、NPC。
- 优点：零 scene 数量，扩展 10 个 POI 不膨胀文件数。
- 缺点：布局必须全部数据化，编辑器拖拽摆放的直观性丧失；3 个 POI 下开发效率明显更低。

**方案 C：TileMap 场景 + 运行时 instantiate**
- `.tscn` 只放 TileMap，NPC/建筑全部运行时 instantiate。
- 优点：随机化友好。
- 缺点：剧情驱动的场景需要确定性布局，这个优点没用。

**选 A 的理由**：
- 首版只有 3 个 POI，场景文件成本完全可控。
- 每个 POI 的地图语言差异大（王府 = 建筑 + 石板地；武当 = 山门 + 石阶；清凉山 = 荒地 + 乱石），数据化反而累。
- 未来若扩到 10+ POI 且布局高度同质化再重构为 B，成本是把 scene 节点反序列化为 `.tres`，不伤骨架。

### 1.4 玩家角色节点设计（沿用战斗 Unit 还是新建 OverworldPlayer？）

**方案 A：新建 `OverworldPlayer`**（✅ 选）
- 新建 `scenes/overworld/overworld_player.tscn`，根节点 `CharacterBody2D`。
- `AnimatedSprite2D` 复用 `warrior_sprite_frames.tres`（徐凤年的战斗 SpriteFrames 已有 idle/run 帧）。
- 只关心 2D 移动、方向、动画状态；不挂 HP、技能、属性。

**方案 B：复用 `scenes/unit/unit.tscn`**
- 把战斗 Unit 挪到 overworld，关闭其 SRPG 行为。
- 缺点：Unit 节点的 HP 血条、acted 遮罩、grid 坐标系全是战斗时设计，overworld 要么隐藏、要么断连，留一堆"仅战斗用"字段在运行时；且 overworld 是自由移动不是格子移动，坐标系就对不上。

**方案 C：做一个通用 `Character2D` 抽象，战斗和地图都复用**
- 工作量过大，偏离 P5 范围。

**选 A 的理由**：
- 战斗 Unit 是 grid-based，overworld 是自由走，两者操作模型不一样，强行合并会拉坏两边。
- SpriteFrames 资源（`resources/data/units/warrior_sprite_frames.tres`）可以复用，视觉统一，无额外美术成本。
- 第一版主角锁定为徐凤年；若后续支持多人同行，`OverworldPlayer` 再扩出 `PartyFollower` 节点即可。

### 1.5 场景切换状态机

```
             [New Game / Load]
                    │
                    ▼
            ┌──────────────┐
            │  MainMenu    │
            └──────┬───────┘
           Continue│
                    ▼
            ┌──────────────┐  ←───── Back from POI
            │  Overworld   │  ←───── Back from Battle (via POI)
            └──────┬───────┘
        Enter POI │
                    ▼
            ┌──────────────┐  ←───── Return from Battle
            │  POI Map     │
            └──────┬───────┘
    Dialogue trigger│
           battle   │
                    ▼
            ┌──────────────┐
            │   Battle     │
            └──────┬───────┘
           Win/Loss│
                    ▼
            ┌──────────────┐
            │ Victory/Defeat│ → POI or Overworld (by return_context)
            └───────────────┘
```

状态机由 `GameState.location` + `GameState.return_context`（§5.3）驱动，`SceneManager` 只负责淡入淡出切场景，不维护栈。

### 1.6 每层切换时 `GameState` 的快照/恢复策略

> 原则：**GameState 只持久化"纯数据"，scene 节点不进入 GameState**。

**Overworld → POI**：
- 写入 `GameState.overworld_player_position: Vector2`（当前世界坐标）。
- 写入 `GameState.location = { type: "poi", poi_id: <id> }`。
- `SceneManager.change_scene_to_file(poi.scene_path)`。

**POI → Overworld**：
- 读 `GameState.overworld_player_position`，POI 的离开点把玩家放回到对应 POI 图标旁边（略微偏移，避免立刻再次触发进入）。
- 清掉 `GameState.location.poi_id`。

**POI → Battle**：
- 写入 `GameState.return_context = { scene: poi.scene_path, poi_id, player_pos_in_poi, resume_dialogue_id, resume_node_id }`。
- `GameState.current_level = level_id`（走现有战斗进入逻辑）。
- `SceneManager.change_scene_to_file("res://scenes/battle/battle.tscn")`。

**Battle → POI**：
- Victory/Defeat 场景读取 `GameState.return_context`，`SceneManager.change_scene_to_file(return_context.scene)`。
- POI 根脚本在 `_ready()` 里检查 `return_context`：
  - 若存在 `resume_dialogue_id`，恢复对话并跳到 `resume_node_id`（典型用法：战斗胜利后继续对话）。
  - 把玩家放回 `player_pos_in_poi`。
  - 清掉 `return_context`。

**不保存的东西**（每次进 POI 重置）：
- POI 内 NPC 当前朝向、idle 动画相位。
- 背景随机云移动。

**保存的东西**：
- 所有 `dialogue_flags`（§4.2）——这是对话分支与 POI 解锁的唯一真相源。
- `overworld_player_position`、`location`、`return_context`。
- `completed_levels`（沿用现有字段）。
- 背包、装备（沿用 P2/P3）。

---

## 2. POI 系统

### 2.1 `POIData` Resource 字段设计

文件位置：`scripts/core/poi_data.gd`，`class_name POIData`。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | POI 唯一 id，snake_case，例 `wudang`、`beiliang_palace`、`qingliang_mountain` |
| `display_name` | `String` | 给玩家看的名字，例 `武当山` |
| `position_on_overworld` | `Vector2` | POI 在 overworld 地图上的像素坐标 |
| `scene_path` | `String` | 子地图 `.tscn` 路径，例 `res://scenes/overworld/poi_map_wudang.tscn` |
| `marker_sprite` | `Texture2D` | overworld 上显示的图标（见 §2.4） |
| `marker_label_offset` | `Vector2` | 名字 label 相对图标的位移 |
| `required_flags` | `Array[String]` | 解锁需要的 flag，全为 true 才显示/可进入；空数组 = 一开始就开 |
| `initial_visible` | `bool` | 是否初始显示图标（false 时配合 flag 解锁才出现，做"神秘地点"体验） |
| `entry_spawn_point` | `String` | 进入 POI 时玩家生成点的节点名（POI 内部场景里的 `Marker2D` 名字） |
| `overworld_return_offset` | `Vector2` | 离开 POI 回到 overworld 时玩家落位相对 POI 图标的偏移 |

**设计要点**：
- `required_flags` 与对话系统共享一套 flag 池（§4.2），做到"对话里写入 flag → overworld 立刻出现新 POI"。
- `position_on_overworld` 是像素坐标而不是 tile 坐标，避免被 TileMap 换皮卡住。

### 2.2 三个 POI 的具体配置（首版）

| POI | id | 位置（参考） | 进入方式 | 初始可见 | 初始 NPC |
| --- | --- | --- | --- | --- | --- |
| 北凉王府 | `beiliang_palace` | `(320, 600)` overworld 左下 | 接近 + 按 E | ✅ | 徐骁（父王，触发剧情开场对话）、家将赵洪 |
| 武当山 | `wudang` | `(960, 280)` overworld 上方 | 接近 + 按 E | ✅ | 洪洗象（小道童，触发初次偶遇 + 战斗）、小道人 |
| 清凉山 | `qingliang_mountain` | `(1500, 550)` overworld 右下 | 接近 + 按 E | ❌（需 `wudang.returned_victorious == true` 解锁） | 姜泥（被逼迫的亡国公主线入口，首版只挂一句引导对白） |

**POI 内建筑 / Tile 素材选型**（引用 `docs/v2-audit.md` §1D）：

- **北凉王府**：`Buildings/Yellow Buildings/Castle.png` 做主殿 + `House1-3.png` 做偏殿；`Terrain/Tileset/Tilemap_color1.png` 做石板地面；`Banner` 素材做王府旗帜。
- **武当山**：`Buildings/Blue Buildings/Monastery.png` 做主殿（最合适的道观外形）；`Tilemap_color2.png`（山地绿）铺地；`Terrain/Resources/Wood/Trees` 做山林装饰。
- **清凉山**：`Tilemap_color3.png`（偏灰黄）铺荒坡；`Decorations/Rocks` + 枯树做"凄凉"气质；先不放建筑，只摆姜泥一个 NPC + 一个告示牌提示玩家。

### 2.3 overworld 上 POI 的视觉呈现

```
POIMarker (Node2D, script: poi_marker.gd)
├── Sprite2D                 (显示 POIData.marker_sprite)
├── Label                    (显示 POIData.display_name，modulate 随是否已解锁变化)
├── InteractionArea (Area2D)
│   └── CollisionShape2D    (CircleShape2D, radius = 64px)
└── HintAnchor (Marker2D)   (供 UILayer 定位"按 E"提示)
```

**交互方式**：**接近 + 按 E**（或鼠标点击 Sprite2D 也可触发；两通道与 NPC 统一，见 §3.5）。

**视觉态**：
- 已解锁：全彩显示 + 名字 label 白色。
- 未解锁：`visible = false`（首版简化，不做灰色剪影态）。
- 附近（玩家进入 InteractionArea）：UILayer 在 HintAnchor 位置显示"按 E 进入 <display_name>"。

### 2.4 从 Tiny Swords 里选 POI marker 素材

| POI | 推荐 marker_sprite | 原因 |
| --- | --- | --- |
| `beiliang_palace` | `Buildings/Yellow Buildings/Castle.png`（缩放到 64x64） | 黄色=北凉王府色，城堡轮廓最有"王府"辨识度 |
| `wudang` | `Buildings/Blue Buildings/Monastery.png`（缩放到 64x64） | 监督像有十字/尖顶，在 Tiny Swords 里最贴近"道观" |
| `qingliang_mountain` | `Terrain/Decorations/Rocks/Rock1.png` + 一棵枯树叠层 | Tiny Swords 里没有"山"单独素材，用岩石+枯树手动复合一张临时图；后续补美术时换 |

**Overworld 大底图 tileset**：`Terrain/Tileset/Tilemap_color1.png`（绿色系）做主色。一张原型地图，不做多 biome。

---

## 3. NPC 系统

### 3.1 `NPCData` Resource

文件位置：`scripts/core/npc_data.gd`，`class_name NPCData`。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | NPC 唯一 id，例 `xu_xiao`、`hong_xixiang`、`jiang_ni_npc` |
| `display_name` | `String` | 给玩家看的名字 |
| `unit_id` | `String` | 可选，若复用某个 UnitData 的 sprite，则填其 unit_id；`UnitRegistry.get_data(unit_id).sprite_frames` 给视觉复用 |
| `sprite_frames` | `SpriteFrames` | 若不走 unit_id 复用，直接指资源；二选一，unit_id 优先 |
| `default_dialogue_id` | `String` | 默认要播放的 DialogueData id（参 §4.1） |
| `conditional_dialogues` | `Array[Dictionary]` | 条件对话列表，元素结构：`{ required_flags: [String], forbidden_flags: [String], dialogue_id: String }`，按顺序匹配第一个命中的 |
| `interaction_range` | `float` | Area2D 半径（默认 48px） |
| `modulate` | `Color` | 可选色调 |

**conditional_dialogues 匹配规则**（由 `NPCInteractor` 运行时决定用哪条）：

1. 遍历 `conditional_dialogues`，按顺序找第一条 `required_flags` 全命中且 `forbidden_flags` 全未命中的，用它。
2. 都不命中时，fallback 到 `default_dialogue_id`。
3. 例：洪洗象 NPC
   - `conditional_dialogues[0]` = `{ required_flags: ["wudang.returned_victorious"], dialogue_id: "wudang_hong_after_battle" }`
   - `default_dialogue_id` = `"wudang_hong_first_meet"`

### 3.2 NPC 节点结构

```
NPCNode (Node2D, script: npc_node.gd)
├── AnimatedSprite2D        (sprite_frames 来自 NPCData)
├── InteractionArea (Area2D)
│   └── CollisionShape2D   (CircleShape2D, radius = NPCData.interaction_range)
├── HintAnchor (Marker2D)  (位置在头顶正上方 ~40px)
└── NameLabel (Label)      (显示 display_name，默认隐藏；附近时弹出)
```

### 3.3 靠近判定与信号处理

- Area2D 的 `body_entered` / `body_exited` 信号绑定到 POI 根脚本（`poi_map_root.gd`）。
- POI 根脚本维护 `_near_npc: NPCNode` 和 `_near_poi: POIMarker`（overworld 上用）。
- 当 `body_entered` 触发：
  - 检查 body 是不是 `OverworldPlayer`。
  - 若是，更新 `_near_npc = this_npc`，让 UILayer 显示"按 E 交谈"。
- 当 `body_exited` 触发：
  - 若 `_near_npc == this_npc`，清空并隐藏提示。

**半径建议**：
- 普通 NPC `interaction_range = 48px`（玩家 sprite 大约 64x64，48 是"走到跟前"）。
- 首领级 NPC（徐骁、洪洗象）`64px`（更宽松，保证玩家第一次玩不会错过）。
- POI marker 用 `64px`。

**多 NPC 重叠情况**：
- 进入多个 Area2D 时，用"最后进入"覆盖 `_near_npc`；离开某一个时，`_near_npc` 仅在当前 NPC 等于 `_near_npc` 时才清空（防抖）。
- 极端情况下同一帧进入两个，取 `y` 较大的（更靠近画面下方，视觉上更"前景"）。

### 3.4 交互提示 UI

- `InteractionHint` 位于 UILayer，节点结构：
  ```
  InteractionHint (Control)
  ├── Panel (StyleBox: RegularPaper 小尺寸 9-slice)
  ├── KeyIcon (TextureRect, 按键图或文字 [E])
  └── HintLabel (Label, 文本 "交谈" / "进入" / "查看")
  ```
- 位置：每帧跟随 `_near_npc.HintAnchor.global_position`，转成 UI 坐标。
- 显隐：有 near 目标时显示，切场或对话打开时强制隐藏。

### 3.5 鼠标点击 + E 键双通道输入

**核心问题**：同一次玩家意图不能触发两次对话。

**方案**：
- `OverworldInputController`（挂在 `Overworld` / `POI` 根节点）统一处理输入：
  - `_unhandled_input` 监听 `ui_accept`（E / Enter）。
  - `InteractionArea` 同时监听 `input_event` 信号（鼠标点击）。
- 两条路径最终都调用 `interaction_router.try_interact(source)`：
  - `source` 区分 `"key"` 或 `"mouse"`。
  - 路由器内部有 `_busy` 标志位（对话开启中 / 刚触发过 300ms 内），避免双触发。
  - 鼠标点击时，若点击的 NPC 不是 `_near_npc`，要求玩家先走到范围内（首版简化：点击直接播对话，但要求点击位置在 Area2D 内；Area2D 的 `input_pickable = true`）。
- 对话开启期间：
  - `OverworldPlayer._input_enabled = false`。
  - `InteractionHint.visible = false`。
  - 所有 NPC Area2D 的 `monitoring = false`（可选优化，避免穿帮）。

### 3.6 首版每个 POI 的 NPC 配置

| POI | NPC id | 角色 | 初始对话 | 战斗触发？ |
| --- | --- | --- | --- | --- |
| `beiliang_palace` | `xu_xiao` | 徐骁（徐凤年父王） | `beiliang_opening` | ❌ |
| `beiliang_palace` | `zhao_hong` | 家将赵洪 | `beiliang_zhao_hong_chat` | ❌ |
| `wudang` | `hong_xixiang` | 洪洗象（小道童） | 默认 `wudang_hong_first_meet`（触发 level_01）；胜利后 `wudang_hong_after_battle` | ✅（level_01） |
| `wudang` | `wudang_disciple` | 小道人 | `wudang_disciple_chat` | ❌ |
| `qingliang_mountain` | `jiang_ni_npc` | 姜泥 | `qingliang_jiang_ni_intro` | ❌（首版只挂引导，下一 phase 扩） |

---

## 4. 对话系统（重点）

### 4.1 数据结构

**三个方案对比**：

| 方案 | 描述 | 优点 | 缺点 |
| --- | --- | --- | --- |
| **A：单个 `.tres` 内嵌 `Array[DialogueNode]` + next_id 指针** | 一个 DialogueData 资源包含一条完整对话，内部节点用字符串 id 互相跳转 | 1 个对话 = 1 个文件，编辑和 diff 友好；AI 生成一条对话直接写一个 .tres | 节点间跳转靠字符串 id，编辑器没法点击跳转 |
| **B：每个节点一个独立 `.tres`，相互引用** | DialogueNode 是一个 Resource 文件，通过 `ext_resource` 互相引用 | Godot 编辑器能可视化跳转 | 文件爆炸，10 个节点的对话 = 11 个文件；AI 批量生成成本高 |
| **C：Array[DialogueNode] 但 DialogueNode 是 class 不是 Resource** | 对话节点全部内嵌，但不是 Resource | 零文件开销 | Godot 编辑器完全无法编辑节点字段，只能在代码里初始化；违背".tres 做数据"的既定方向 |

**✅ 选方案 A**。理由：
- 用户已拍板 ".tres 做数据"，方案 C 直接淘汰。
- 方案 B 的优点（编辑器跳转）对"AI 直接写"场景价值极低，反而文件量爆炸。
- 方案 A 是绝大多数 RPG 对白系统的事实标准（Ink、Yarn、Dialogic 都走此路）。
- 字符串 id 跳转的"缺乏静态检查"问题，靠一个一次性校验工具（§6.3）在加载时跑就够了。

#### 4.1.1 `DialogueData` 顶层 Resource

文件位置：`scripts/core/dialogue_data.gd`，`class_name DialogueData`。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | DialogueData 唯一 id（全局，例 `wudang_hong_first_meet`） |
| `entry_node_id` | `String` | 入口节点 id，默认 `"start"` |
| `nodes` | `Array[DialogueNode]` | 节点数组（内嵌 Resource） |
| `meta` | `Dictionary` | 自由元数据（例 `author: "ai"`, `revision: 3`），不进入运行逻辑 |

#### 4.1.2 `DialogueNode` 子 Resource（内嵌）

文件位置：`scripts/core/dialogue_node.gd`，`class_name DialogueNode`。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `node_id` | `String` | 节点 id，对话内唯一 |
| `speaker_id` | `String` | 说话人 id（配合 §4.3 portrait 查找） |
| `speaker_name_override` | `String` | 若非空，UI 显示此名而不是 speaker_id 对应的默认名（用于"神秘人"之类） |
| `text` | `String` | 说话文本，支持 `\n` 换行 |
| `choices` | `Array[DialogueChoice]` | 选项数组；若为空 = 单方向推进（点击推进到 next_node_id） |
| `next_node_id` | `String` | 无选项时的默认下一节点 id；空字符串 = 对话结束 |
| `on_enter_actions` | `Array[DialogueAction]` | 进入节点时立即执行 |
| `on_exit_actions` | `Array[DialogueAction]` | 离开节点时执行（包括通过选项离开） |
| `required_flags` | `Array[String]` | 所有 flag 均为 true 时节点才可达；否则被 `runtime resolver` 跳过（用 next_node_id 或第一个可达选项） |
| `forbidden_flags` | `Array[String]` | 所有 flag 均为 false 时才可达 |

#### 4.1.3 `DialogueChoice` 子 Resource（内嵌）

文件位置：`scripts/core/dialogue_choice.gd`，`class_name DialogueChoice`。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `text` | `String` | 选项显示文本 |
| `next_node_id` | `String` | 选中后跳转 |
| `required_flags` | `Array[String]` | 需要的 flag 全 true 才显示 |
| `forbidden_flags` | `Array[String]` | 需要的 flag 全 false 才显示 |
| `actions` | `Array[DialogueAction]` | 点击选项时立即执行（发生在目标节点的 on_enter 之前） |

#### 4.1.4 `DialogueAction` 子 Resource（内嵌）

文件位置：`scripts/core/dialogue_action.gd`，`class_name DialogueAction`。

单字段 `type: String` + 若干 payload 字段。用 `type` 枚举字符串而非 enum，便于 AI 直接写 .tres：

| type | payload 字段 | 语义 |
| --- | --- | --- |
| `set_flag` | `flag: String`, `value: bool` | 写入 flag；`value` 默认 true |
| `give_item` | `item_id: String`, `count: int` | 通过 `GameState.inventory.add(item_id, count)` 发放 |
| `give_equipment` | `item_id: String`, `equip_to: String`, `slot: int` | 生成装备实例；`equip_to` 给 char_id 则自动穿上，否则放背包 |
| `unlock_poi` | `poi_id: String` | 等价于 `set_flag("poi." + poi_id + ".unlocked", true)`；同时立刻刷新 overworld POI 可见性（若当前在 overworld） |
| `start_battle` | `level_id: String`, `resume_dialogue_id: String`, `resume_node_id: String` | 关闭对话 → 设置 return_context → 切到 Battle |
| `play_sfx` | `path: String` | 可选，首版留接口不实现 |
| `end_dialogue` | — | 显式终止对话（等价于 next_node_id = ""） |

**设计要点**：
- `start_battle` 的 `resume_dialogue_id` 和 `resume_node_id` 允许战后回到本对话的某个节点，实现"战后继续讲"。
- `give_equipment` 与 P3 装备系统对接，复用 `GameState.equip`。

### 4.2 DialogueFlags 持久化

**方案选择**：

| 方案 | 描述 | 优缺点 |
| --- | --- | --- |
| **A：`GameState.dialogue_flags: Dictionary`** | 挂在 GameState，一起存档 | 复用 GameState 的存档路径；与 `completed_levels`、`inventory` 同级，符合"GameState = 全局数据"定位 |
| **B：独立 `DialogueFlags` Autoload** | 新开一个单例 | 职责隔离更彻底；存档时要额外协调两个 Autoload 的序列化 |
| **C：对话系统内部 `DialogueSystem._flags`** | 完全不是单例数据 | 其他系统（POI 解锁、NPC 条件对话）要用 flag 还得转一手，耦合反而重 |

**✅ 选方案 A：`GameState.dialogue_flags: Dictionary`**。理由：
- `GameState.complete_level` 已经是"剧情状态"的承载点，flag 和 completed_levels 性质相同，没必要拆开。
- v2 尚无完整存档系统，若以后补存档（序列化 GameState 为 JSON），flag 天然跟随走，无需额外 migration。
- 方案 B 的"职责隔离"在 flag 写入点极少的 RPG 里是过度工程。
- POI `required_flags`、NPC `conditional_dialogues`、Dialogue `required_flags` 三处都要读 flag，集中在 GameState 查询路径最短。

**API 设计**（挂在 GameState）：

```
# 概念 API，不是实现
GameState.dialogue_flags: Dictionary  # flag_name -> bool
GameState.set_flag(name: String, value: bool = true) -> void
GameState.get_flag(name: String) -> bool  # 默认 false
GameState.has_all_flags(names: Array[String]) -> bool
GameState.has_none_flags(names: Array[String]) -> bool
signal flag_changed(name: String, value: bool)
```

**`flag_changed` 信号的作用**：overworld 在 `_ready` 里订阅它，用于 POI `required_flags` 发生变化时实时刷新图标显隐。

#### 4.2.1 flag 命名约定

**格式**：`<namespace>.<snake_case_name>`

**规则**：
- `namespace` 必须非空且为小写字母开头，只含 `[a-z0-9_]`。
- `name` 同上。
- 全局共享命名空间：`global`（跨 POI 的剧情里程碑）。
- 每个 POI 一个 namespace：与 POI id 同名（`beiliang_palace`, `wudang`, `qingliang_mountain`）。
- POI 解锁约定：`poi.<poi_id>.unlocked`。
- 角色相关：`char.<char_id>.<event>`。

**示例 flag 列表**（首版真实会用到的）：

| flag | 写入时机 | 读取位置 |
| --- | --- | --- |
| `beiliang.met_xu_feng_nian` | 北凉开场对话播完 | 暂无消费者，留作档案 |
| `beiliang.opening_done` | 北凉开场对话结束 | Overworld 显示"去武当"提示的条件 |
| `wudang.first_meet_hong` | 武当首次与洪洗象交谈 | 武当 level_01 的 dialogue 进入条件 |
| `wudang.returned_victorious` | level_01 胜利后返回武当 + 与洪洗象再次对话 | `qingliang_mountain` 的 `required_flags`；洪洗象 `conditional_dialogues` |
| `poi.qingliang_mountain.unlocked` | 等价于上条，或单独写入都可 | overworld POIMarker 可见性 |
| `char.xu_fengnian.blade_style_hinted` | 徐骁对话中提示春秋刀法 | 武当对话里洪洗象的特殊回应 |

**防呆**：
- 约定 `namespace` 列表在 `scripts/systems/dialogue_system.gd` 顶部写死（`ALLOWED_NAMESPACES = ["global", "beiliang_palace", "wudang", "qingliang_mountain", "poi", "char"]`），运行时校验；命名错误立即 push_warning。
- 工具 `tools/validate_dialogues.gd`（可选，§6.3）离线跑一遍全部 `.tres`，列出所有被写入/读取的 flag，发现 typo 直接报。

#### 4.2.2 存盘格式

沿用 `GameState` 整体序列化，`dialogue_flags` 天然是 `Dictionary[String, bool]`，`JSON.stringify` 原生支持。

首版无 UI 存档，重启游戏后 flag 归零（与 `completed_levels` 行为一致）。P6 或后续补存档时一起处理。

### 4.3 演出组件

#### 4.3.1 `dialogue_box.tscn`

文件位置：`scenes/dialogue/dialogue_box.tscn`，根节点 `CanvasLayer`（确保覆盖任何场景）。

```
DialogueBox (CanvasLayer, layer=100, script: dialogue_box.gd)
└── Root (Control, anchor 铺满)
    ├── Backdrop (ColorRect)              # 半透明遮罩，modulate 0.3，吸收点击
    ├── Frame (NinePatchRect)             # RegularPaper 9-slice 底板
    │   ├── PortraitBox (TextureRect)     # 左下 96x96 小头像
    │   ├── NameTag (Panel + Label)       # SpecialPaper 小方块 + 名字
    │   ├── TextLabel (RichTextLabel)     # 对话正文，开启 BBCode
    │   └── ContinueIndicator (Label)     # 右下角 ">" 闪烁，提示可推进
    └── ChoicesPanel (VBoxContainer)      # 节点有 choices 时显示
        └── ChoiceButton × N              # 9-slice 小按钮，动态生成
```

**布局规格**：
- DialogueBox 位置：屏幕下方，距底 48px，左右各留 96px 边距。
- Frame 高度 180px。
- PortraitBox 96x96，嵌在 Frame 左下。
- NameTag 在 Frame 左上角外突出（经典 JRPG 名字牌）。
- TextLabel 字体沿用 `resources/fonts/NotoSerifCJKsc-Regular.otf`，字号 24。

#### 4.3.2 推进控制

- **有选项时**：点击选项按钮推进，空格/回车不生效（防误推）。
- **无选项时**：空格 / 回车 / 鼠标左键（点在 DialogueBox 上）推进到 `next_node_id`。
- **逐字显示动画播放中**：任何推进输入都先把文字一次性显示完（不跳 node）；再按一次才推进。

#### 4.3.3 文字逐字显示动画

**推荐开启**，速度 40 字/秒（约 25ms/字），BBCode 标签不计入字符。

实现思路：`RichTextLabel.visible_characters` 逐帧递增。

**跳过键**：按下推进键时立即置 `visible_characters = -1`（全显示）。

#### 4.3.4 头像资源命名约定

**路径**：`resources/ui/portraits/{speaker_id}.png`

**格式**：96x96 正方形 PNG，透明背景。

**fallback 规则**（从上到下找到第一个命中）：
1. `resources/ui/portraits/{speaker_id}.png`
2. 若 speaker_id 对应某 UnitData，且有 `sprite_frames`：运行时从 SpriteFrames 取第一帧缩放到 96x96（临时方案，首版可用）。
3. `resources/ui/portraits/_default.png`（占位头像，用 `Human Avatars/Avatars_01.png` 裁切）。

**首版 portrait 清单**：
- `xu_fengnian.png`（徐凤年，从 warrior sprite 裁）
- `xu_xiao.png`（徐骁，用 `Avatars_10.png` 或类似成年武将头像占位）
- `hong_xixiang.png`（洪洗象，用 `Avatars_05.png` 僧侣/道童风格占位）
- `jiang_ni_npc.png`（姜泥，用 `Avatars_15.png` 女性角色占位）
- `zhao_hong.png`（赵洪，用 `Avatars_08.png` 武士占位）
- `wudang_disciple.png`（小道人，复用 `hong_xixiang.png` 或用另一个 Avatars）
- `_default.png`

所有占位 portrait 在 P5 结束前保持"Tiny Swords Avatars 头像"风格，不抢剧情风格。P6 或未来补真立绘时，只需替换同路径图片。

### 4.4 AI 写剧情的 Markdown 模板

#### 4.4.1 写作模板（AI 读这个）

```markdown
# Dialogue: <dialogue_id>

## Meta
- poi: <poi_id>
- npc: <npc_id>
- entry_condition: <flag 列表，空=无条件>
- on_complete_flags: <写入哪些 flag>
- word_budget: <约 80-200 字，首版硬上限 400 字>
- tone: <庄重 / 诙谐 / 肃杀 / 冷峻 / 悲悯>

## Cast
- <speaker_id>: <角色简述 + 说话风格一句>
- <speaker_id>: ...

## Scene Context (给 AI 知道 but 不进入对话文本)
<2-3 句：时间、地点、NPC 现在在做什么、玩家为什么找上来>

## Script

### start (default entry)
**<speaker_id>**: <台词>
→ next: <node_id>

### <node_id>
**<speaker_id>**: <台词>
[choice] "<选项文本>" → <node_id> (需要: flag_a, !flag_b)
[choice] "<选项文本>" → <node_id>

### <node_id>
on_enter: set_flag(<flag_name>) / give_item(<item_id>, <n>) / start_battle(<level_id>, resume=<node_id>)
**<speaker_id>**: <台词>
→ next: <node_id 或 END>

## Constraints
- 单节点台词不超过 2 句话，不超过 60 字。
- 分支选项 ≤ 3 条。
- 每条对话分支深度 ≤ 5 层。
- 关键 flag 只允许在声明过的 Meta.on_complete_flags 列表里写入。
- 风格要求：武侠语境；不用现代化网络用语；偶尔半文言半白话，不过量（每段最多 1 处）。
```

#### 4.4.2 完整示例：武当偶遇洪洗象

```markdown
# Dialogue: wudang_hong_first_meet

## Meta
- poi: wudang
- npc: hong_xixiang
- entry_condition: (none)
- on_complete_flags: wudang.first_meet_hong
- word_budget: ~160 字
- tone: 诙谐中带肃杀

## Cast
- xu_fengnian: 徐凤年，北凉世子；嘴硬心软，爱装游手好闲。
- hong_xixiang: 洪洗象，武当小道童，外表稚气，实则境界深不可测；说话慢半拍，但每句都稳。

## Scene Context
徐凤年沿青石阶上武当，半山遇一扫地小道童。道童手中一柄扫帚不及胸高，却在山风里一动不动。徐凤年刚想开个玩笑，脚下忽觉一股气劲逼来。

## Script

### start
**hong_xixiang**: 山门重地，施主请留步。
→ next: ask_who

### ask_who
**xu_fengnian**: 一个扫地的，倒管起来了。你叫什么？
[choice] "报上名来" → reveal_name
[choice] "懒得问，借过" → provoke

### reveal_name
**hong_xixiang**: 贫道洪洗象。施主若只是上山，便请。若是想讨教，便得先过我这把扫帚。
→ next: decide_fight

### provoke
**hong_xixiang**: 施主的步子，下山比上山沉。这一步若迈出，便不是借过了。
→ next: decide_fight

### decide_fight
**xu_fengnian**: ……行，试试你这把扫帚。
[choice] "动手" → trigger_battle

### trigger_battle
on_enter: set_flag(wudang.first_meet_hong), start_battle(level_01, resume=after_battle)
**hong_xixiang**: 请。
→ next: END

### after_battle  (战后 resume 落点)
on_enter: set_flag(wudang.returned_victorious), unlock_poi(qingliang_mountain)
**hong_xixiang**: 施主的刀，比山风利。清凉山的路，自此应为施主开一条。
→ next: farewell

### farewell
**xu_fengnian**: 清凉山……行，我记下了。
→ next: END
```

该示例同时示范：
- 分支选项（ask_who → reveal_name / provoke）
- flag 写入（`wudang.first_meet_hong`、`wudang.returned_victorious`）
- POI 解锁（`unlock_poi(qingliang_mountain)`）
- 战斗触发 + 战后 resume（`start_battle(level_01, resume=after_battle)`）

---

## 5. 战斗衔接协议（本文档拍板）

### 5.1 对话节点如何触发战斗

- `DialogueAction.type == "start_battle"`：
  ```
  payload: {
      level_id: String,
      resume_dialogue_id: String,  # 可选，默认当前对话 id
      resume_node_id: String,       # 可选，默认 ""（战后不自动恢复对话）
  }
  ```
- 执行流：
  1. 关闭 DialogueBox（立即隐藏，不播淡出，避免战斗场景出现两层 UI）。
  2. 调用 `GameState.begin_battle_from(level_id, resume_dialogue_id, resume_node_id)`：
     - 写入 `GameState.current_level = level_id`
     - 写入 `GameState.return_context`（§5.3）
  3. `SceneManager.change_scene_to_file("res://scenes/battle/battle.tscn")`。

### 5.2 战斗胜/败后回到哪里

**协议：`return_context` 驱动，不用显式 stack**（方案选择见 §5.4）。

**胜利流**：
1. `BattleController` 触发 `victory` → 切到 `scenes/victory/victory.tscn`。
2. `victory.gd` 在"继续"按钮后调用 `GameState.resume_from_battle()`，该方法：
   - 切回 `GameState.return_context.scene`（即来源 POI）。
   - 若 `resume_dialogue_id` 非空，POI 场景在 `_ready` 时自动再开对话并跳到 `resume_node_id`。
   - 清空 `return_context`。

**失败流**：
1. `BattleController` 触发 `defeat` → 切到 `scenes/defeat/defeat.tscn`。
2. `defeat.gd` 提供两个选项：
   - 「重试」：直接重载 `battle.tscn`，`return_context` 保留。
   - 「返回」：调用 `GameState.abort_battle()` 切回 POI，不 resume 对话。
3. 首版不做"战败惩罚"（不扣物品），因为无任务系统。

### 5.3 `GameState` 字段扩展

新增字段（在现有 game_state.gd 基础上）：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `dialogue_flags` | `Dictionary[String, bool]` | §4.2 |
| `location` | `Dictionary` | 结构 `{ type: "main_menu" / "overworld" / "poi" / "battle", poi_id: String }` |
| `overworld_player_position` | `Vector2` | overworld 当前世界坐标 |
| `return_context` | `Dictionary` | 结构见下 |

`return_context` 结构：
```
{
    "scene": String,              # 要回到的 .tscn 路径
    "poi_id": String,             # POI id（诊断/日志用）
    "player_pos_in_poi": Vector2, # POI 内玩家坐标
    "resume_dialogue_id": String, # 空字符串 = 不恢复对话
    "resume_node_id": String,     # 空字符串 = 不恢复对话
}
```

新增方法（概念 API）：

```
GameState.begin_battle_from(level_id, resume_dialogue_id, resume_node_id) -> void
GameState.resume_from_battle() -> void      # victory 走这个
GameState.abort_battle() -> void             # defeat 返回走这个
GameState.enter_poi(poi_id) -> void
GameState.leave_poi() -> void
GameState.set_flag(name, value=true) -> void
GameState.get_flag(name) -> bool
```

### 5.4 协议选型：`return_context` vs scene stack vs callback

| 方案 | 描述 | 优缺点 |
| --- | --- | --- |
| **A：单层 `return_context`（✅ 选）** | 只记一层返回信息 | POI → Battle → POI 是 RPG 里 99% 的路径；实现最简 |
| **B：scene stack `Array[Dictionary]`** | 多层栈，支持 POI → Battle → 过场动画 → Battle → POI | 首版用不上；增加序列化复杂度 |
| **C：callback 闭包注册** | 战斗进入前注册 Callable，战后调用 | GDScript 下 Callable 的存活周期管理痛苦；跨场景切换时 Node 被销毁，Callable 失效 |

选 A 的理由：
- 首版明确主线不存在"战斗中套战斗"。
- `return_context` 可以直接写进 Dictionary，未来若要升栈直接扩成 Array[Dictionary]，代价是把 `GameState.return_context` 改成 `Array` + 提供 `push/pop`，改造成本可控。

---

## 6. 资源清单与目录结构

### 6.1 新增目录

```
scripts/
├── core/
│   ├── poi_data.gd              # §2.1
│   ├── npc_data.gd              # §3.1
│   ├── dialogue_data.gd         # §4.1.1
│   ├── dialogue_node.gd         # §4.1.2
│   ├── dialogue_choice.gd       # §4.1.3
│   └── dialogue_action.gd       # §4.1.4
├── systems/
│   ├── dialogue_system.gd       # 对话调度（见 §6.2）
│   ├── poi_map_root.gd          # POI 根脚本基类
│   ├── overworld_root.gd        # overworld 根脚本
│   ├── npc_interactor.gd        # §3.3/§3.5 交互路由
│   └── registries/
│       ├── dialogue_registry.gd  # §6.2
│       ├── poi_registry.gd       # §6.2
│       └── npc_registry.gd       # §6.2

scenes/
├── overworld/
│   ├── overworld.tscn
│   ├── overworld_player.tscn
│   ├── poi_marker.tscn          # §2.3
│   ├── npc_node.tscn            # §3.2
│   ├── poi_map_beiliang.tscn
│   ├── poi_map_wudang.tscn
│   └── poi_map_qingliang.tscn
└── dialogue/
    └── dialogue_box.tscn        # §4.3.1

resources/
├── data/
│   ├── overworld/
│   │   ├── poi_beiliang_palace.tres   # POIData
│   │   ├── poi_wudang.tres
│   │   ├── poi_qingliang_mountain.tres
│   │   ├── npc_xu_xiao.tres          # NPCData
│   │   ├── npc_zhao_hong.tres
│   │   ├── npc_hong_xixiang.tres
│   │   ├── npc_wudang_disciple.tres
│   │   └── npc_jiang_ni_npc.tres
│   └── dialogues/
│       ├── beiliang_palace/
│       │   ├── beiliang_opening.tres
│       │   └── beiliang_zhao_hong_chat.tres
│       ├── wudang/
│       │   ├── wudang_hong_first_meet.tres
│       │   ├── wudang_hong_after_battle.tres
│       │   └── wudang_disciple_chat.tres
│       └── qingliang_mountain/
│           └── qingliang_jiang_ni_intro.tres
└── ui/
    └── portraits/
        ├── xu_fengnian.png
        ├── xu_xiao.png
        ├── hong_xixiang.png
        ├── jiang_ni_npc.png
        ├── zhao_hong.png
        ├── wudang_disciple.png
        └── _default.png
```

### 6.2 Registry 模式

沿用并行任务已落地的 `UnitRegistry` / `ItemRegistry` / `SkillRegistry` 模式（参 `scripts/systems/registries/unit_registry.gd`），新增三个 Registry：

| Registry | 扫描目录 | API 对齐点 |
| --- | --- | --- |
| `POIRegistry` | `res://resources/data/overworld/poi_*.tres` | `get_data(id)`, `all()`, `all_ids()` |
| `NPCRegistry` | `res://resources/data/overworld/npc_*.tres` | 同上 |
| `DialogueRegistry` | `res://resources/data/dialogues/**/*.tres` | 递归扫描；`get_data(dialogue_id)` |

注册为 Autoload（在 `project.godot` [autoload] 下追加），排在现有 Registry 之后：

```
POIRegistry="*res://scripts/systems/registries/poi_registry.gd"
NPCRegistry="*res://scripts/systems/registries/npc_registry.gd"
DialogueRegistry="*res://scripts/systems/registries/dialogue_registry.gd"
```

### 6.3 对话调度单例 `DialogueSystem`

也注册为 Autoload。核心职责：

- 管理当前对话运行时状态（`_current_dialogue`, `_current_node`）。
- 从 `DialogueRegistry.get_data(id)` 取数据，实例化 `DialogueBox` 到树。
- 执行 `DialogueAction`（与 GameState、SceneManager、Inventory 协作）。
- 发出信号：
  - `dialogue_started(dialogue_id)`
  - `dialogue_ended(dialogue_id)`
  - `node_entered(node_id)`

对外 API（概念）：

```
DialogueSystem.start(dialogue_id: String, resume_node_id: String = "") -> void
DialogueSystem.is_active() -> bool
DialogueSystem.force_close() -> void
```

### 6.4 可选工具：`tools/validate_dialogues.gd`

离线脚本（Godot EditorScript 或命令行 `--headless --script`），跑一遍全部 DialogueData 做静态校验：

- 所有 `next_node_id` 指向存在的节点
- 所有 `DialogueAction` 引用的 item_id/level_id 在对应 Registry 里存在
- 所有 flag 命名符合 §4.2.1 约定
- 检测死循环（BFS 找不到 END）

首版可人肉，P6 前补。

---

## 7. 最小可玩版（MVP）范围

### 7.1 包含内容

- **3 个 POI**：北凉王府、武当山、清凉山。
- **5 个 NPC**（见 §3.6）。
- **5 段初始对话**：
  - `beiliang_opening`（北凉开场）
  - `beiliang_zhao_hong_chat`（家将闲聊）
  - `wudang_hong_first_meet`（武当偶遇，触发 level_01）
  - `wudang_hong_after_battle`（战后续对话，解锁清凉山）
  - `qingliang_jiang_ni_intro`（清凉山首段）
- **1 条闭环主线**：
  ```
  新游戏 → Overworld（只有北凉王府高亮）
      → 进北凉王府 → 与徐骁对话 → set_flag(beiliang.opening_done)
      → 离开北凉 → Overworld（武当山一直可见，提示更明显）
      → 进武当山 → 与洪洗象对话 → start_battle(level_01)
      → 战斗胜利 → 返回武当山 → 自动继续对话 → unlock_poi(qingliang)
      → 离开武当 → Overworld（清凉山出现）
      → 进清凉山 → 与姜泥对话 → MVP 结束提示"更多剧情，敬请期待"
  ```
- **对话框 UI**：纸张底板 + 名字牌 + 小头像 + 纯文字 + 选项 + 逐字动画。
- **战斗衔接**：start_battle + resume 全链路。
- **POI 解锁**：靠 flag 驱动。

### 7.2 显式不做

- ❌ 主线任务面板 / Quest UI
- ❌ 声望 / 好感度系统
- ❌ 动态天气 / 日夜循环
- ❌ 商店 NPC（若要补，走 POI 内部按钮开现有 Inventory 面板，不是新系统）
- ❌ 队友跟随 / 组队展示
- ❌ 多层对话嵌套（对话中开对话）
- ❌ 配音 / 语音
- ❌ 存档 UI（用 GameState 内存态，重启归零）
- ❌ 地图可视化小地图（有 overworld 就够了）

---

## 8. 开发 Sprint 拆分建议

### Sprint P5-S1：数据骨架 + Registry（Size: S-M）

**交付**：
- 新增 Resource 脚本：`POIData`、`NPCData`、`DialogueData`、`DialogueNode`、`DialogueChoice`、`DialogueAction`。
- 新增 Autoload：`POIRegistry`、`NPCRegistry`、`DialogueRegistry`（复用 UnitRegistry 模板）。
- GameState 扩展：`dialogue_flags`、`location`、`overworld_player_position`、`return_context` 字段 + API。
- 手写 1 个样例 `poi_wudang.tres` + 1 个样例 `dialogue_*.tres`（最小可解析）。

**ACCEPT 标准**：
- Registry 启动后能 `get_data("wudang")` 拿到 POIData。
- `GameState.set_flag("test.flag")` + `get_flag("test.flag")` 闭环。
- `DialogueRegistry` 能递归扫描 `dialogues/**/*.tres`。
- 现有战斗关卡（level_01, level_02）仍能通关（零回归）。
- 新增一个 `tests/test_p5_registries.gd` 覆盖 3 个 Registry 的基本查询。

### Sprint P5-S2：对话 UI + 调度器（Size: M）

**交付**：
- `dialogue_box.tscn`（纸张底板 + 名字牌 + 头像 + 文本 + 选项 + 推进指示）。
- `DialogueSystem` Autoload：start/推进/选项/结束/action 执行。
- 7 种 DialogueAction 全部实现（`set_flag`、`give_item`、`give_equipment`、`unlock_poi`、`start_battle`、`play_sfx` 占位、`end_dialogue`）。
- 逐字显示动画 + 跳过。
- 占位 portrait 资源全部就位（`_default.png` 必须有）。

**ACCEPT 标准**：
- 从 `BattleController` 的测试场景里手动调 `DialogueSystem.start("wudang_hong_first_meet")` 能跑通整段对话。
- 点选项能正确跳转。
- `set_flag` + `required_flags` 分支逻辑正确。
- 写一个 `tests/test_p5_dialogue_flow.gd` 模拟"开始 → 选项 → 结束 → flag 生效"。

### Sprint P5-S3：Overworld + POI 场景（Size: M）

**交付**：
- `overworld.tscn`（背景 + 3 个 POI Marker + Player + Camera）。
- `poi_map_beiliang.tscn`、`poi_map_wudang.tscn`、`poi_map_qingliang.tscn`。
- `OverworldPlayer`（自由 2D 移动，WASD/方向键；复用 warrior_sprite_frames）。
- `POIMarker` 节点 + 交互（E / 鼠标点击进入）。
- `NPCNode` + 交互提示 UI。
- overworld ↔ POI 切场景，GameState 快照正确。

**ACCEPT 标准**：
- 新游戏从主菜单"继续旅程"进 overworld。
- 能走动、靠近 POI、按 E 进入、在 POI 里走、按"离开"回到 overworld 并落在 POI 图标旁。
- overworld Player 坐标在 POI 往返中保留。
- `qingliang_mountain` POI 初始不可见（flag 未解锁）。
- 写 `tests/test_p5_overworld_nav.gd` 模拟进入/离开。

### Sprint P5-S4：战斗衔接 + 主线闭环（Size: M）

**交付**：
- `start_battle` DialogueAction → GameState.begin_battle_from → SceneManager → Battle。
- Victory.gd 的"继续"按钮走 `GameState.resume_from_battle`。
- Defeat.gd 的"返回"按钮走 `GameState.abort_battle`。
- POI 根脚本在 `_ready` 识别 `return_context` 并恢复对话。
- 5 段对话 `.tres` 全部写完（AI 按 §4.4 模板产出，人工精修）。
- 5 个 NPC `.tres` 全部挂对。

**ACCEPT 标准**：
- 从新游戏开始，能完整跑完 §7.1 的主线闭环。
- 战斗胜利后回到武当山，自动接上"after_battle"节点并解锁清凉山。
- 战斗失败"返回"能回到武当山（非继续对话，NPC 恢复为可再次交互）。
- 所有 portrait 正确加载；缺失的走 fallback。

### Sprint P5-S5：打磨 + 校验工具（Size: S）

**交付**：
- `tools/validate_dialogues.gd`（§6.4），CI/本地手动跑。
- 对话文本润色（AI 产出 + 人工一遍）。
- UI 细节：选项 hover 效果、文字速度可配置（DialogueSystem 上的常量）、ESC 退出对话（弹确认）。
- Overworld UI：当前附近 POI 名字显示在顶部。
- 文档更新：`docs/p5-design.md` 本身标记"已落地版本"，并追加"已知局限"小节。

**ACCEPT 标准**：
- `validate_dialogues` 无 error、无 warning。
- 主线完整通关体验 ≥ 3 分钟（含战斗），玩家不会卡死。
- 无已知回归。
- 所有相关 todo 清零。

---

## 9. 已知风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| AI 写剧情偏离武侠语感 | 中 | 模板 §4.4 强约束 tone + 样例；人工过一遍 |
| 3 张 POI 地图摆放同质化 | 低 | 刻意用不同 Tilemap_color + 不同建筑轮廓区分 |
| Portrait 占位 Avatars 风格与战斗 sprite 风格脱节 | 中 | 首版接受，P6 或未来补画 |
| overworld Player 与战斗 Unit 外观不统一 | 低 | 两者都走 warrior_sprite_frames，视觉连贯 |
| DialogueAction 字段膨胀 | 中 | 用 `type: String + payload dict` 模式，扩展零 schema 变更 |
| flag 命名冲突 / typo | 高 | §4.2.1 namespace 约束 + §6.4 校验脚本 |
| 战斗失败"返回"后 NPC 状态需要回滚？ | 中 | 首版 NPC 状态=只依赖 flag，失败不写 flag 所以天然回滚；不需要额外快照 |

---

## 10. 开放问题（后续 Phase 追加）

- 存档与章节管理（目前 dialogue_flags 重启归零）。
- 多人对话（多说话人同框，目前只支持单人）。
- 对话中的过场动画 / 镜头动画。
- Overworld 多区域（跨 biome 旅行）与大地图素材扩充。
- 姜泥线的战斗 / 分支剧情（MVP 只留入口）。

---

## 附录 B：关键引用

- 素材盘点：`docs/v2-audit.md` §1（UI/图标/sprite/地图/对话框）
- 现有 Registry 模板：`scripts/systems/registries/unit_registry.gd`
- 现有 GameState：`autoload/game_state.gd:1-187`
- 现有 SceneManager：`autoload/scene_manager.gd:14-43`
- 现有 LevelData 作对比：`scripts/core/level_data.gd`
- 现有战斗入口：`scenes/battle/battle_controller.gd:478-486`（`GameState.current_level` 驱动）

---

*End of p5-design.md*

## 附录 A — 已落地版本（v0.2 开发中）

本节由 Sprint P5-S5 收官时自动追加。

### 已实现
- P5-S1：POI / NPC / Dialogue 三套 Resource 与 Registry，GameState 增补 `dialogue_flags`、`location`、`overworld_player_position`、`return_context`
- P5-S2：`DialogueSystem` + `dialogue_box.tscn`，支持逐字显示、跳过、分支选项、条件分支、portrait fallback
- P5-S3：`overworld.tscn`、3 个 POI 场景、`OverworldPlayer`、`POIMarker`、`NPCNode`、overworld ↔ POI 往返
- P5-S4：`start_battle` / Victory / Defeat / `return_context` 闭环，战后恢复 POI 与后续对话
- P5-S5：`validate_dialogues.gd`、文字速度设置、ESC 返回主菜单确认框、hover/呼吸动画、Overworld 顶部 POI 名提示
- 3 个 POI（北凉/武当/清凉）+ 主线闭环
- 5 段正式剧情 `.tres`（共 25 个 DialogueNode / 8 个 DialogueChoice）
- 7 种 DialogueAction 全实装
- Registry 系统（POI/NPC/Dialogue）
- `validate_dialogues` 校验工具

### 已知局限
- OverworldPlayer 四方向仅用 flip/modulate，无独立上下帧美术
- 主菜单→overworld 异步淡入在 `SceneTree --script` 模式存在时序抖动（E2E 用直接切场兜底）
- ObjectDB leaked at exit（项目既有，非本阶段引入）
- 对话不能回放已读剧情（无 replay）
- 战斗中无法存档（战斗内状态）

### 建议的 P6 入口
- 更多 POI / NPC / 剧情
- 对话存档 / 回放
- UI 文字速度 cfg 的设置页最终入口（当前放在 settings_menu，可独立成对话设置）
- NPC 动画系统（四方向美术）
- 战斗中存档
