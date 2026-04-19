# Tilemap_color1.png Atlas Catalog

## 概述
- 源文件：`/Users/xiaochunliu/Downloads/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png`
- 尺寸：576×384 px = 9×6 tiles @ 64 px
- 切片输出：`tools/catalog/atlas_tiles/x{X}_y{Y}.png` (X=0..8, Y=0..5)

## **重大修正（请用户先确认）**

用户/上次任务描述里多次提到 "grass↔water 过渡组"，但**肉眼确认：这个 atlas 根本没有水**。

实际地形只有两种：
1. **grass**（草地 top-down 顶视）
2. **stone cliff / rock**（灰青色石壁侧视，典型 Tiny Swords 悬崖正面贴图）

**commit 1ac074b 把 (5,5) 当"水块"用完全是误标**——(5,5) 是**悬崖中段侧壁**（见 `atlas_tiles/x5_y5.png`）。

所以本 atlas 的过渡组应该叫 **"grass↔cliff 过渡组"**，而不是 "grass↔water 过渡组"。
后续若需要水，必须**另找素材**（Tiny Swords Terrain 目录下 `Water.png` 或类似），不能从本 atlas 凑。

## 整体布局

Atlas 明显分为 **左块（4×6）+ 中间空列（x=4）+ 右块（5×6）** 两组 autotile：

```
  x=0  1  2  3  |  4  |  5  6  7  8
y=0 [ G  G  G  g ] [.] [ G  G  G  g ]
y=1 [ G  G  G  g ] [.] [ G  G  G  g ]
y=2 [ G  G  G  g ] [.] [ G  G  G  g ]
y=3 [ G  G  G  g ] [.] [ G  G  G  g ]
y=4 [ g  .  .  g ] [.] [ C  C  C  C ]
y=5 [ g  .  .  g ] [.] [ C  C  C  C ]

图例：
  G = grass autotile 过渡格（4 角是 grass/void 组合）
  g = grass "island / thin strip"（四周 void 或侧向过渡）
  C = stone cliff autotile 过渡格（4 角是 grass/cliff 组合）
  . = void/透明（无 tile 或装饰残留）
```

### 两组 autotile 分别是：
- **左块 (x=0..3, y=0..3)**：一个 4×4 **grass-island** 过渡组（草地 vs void/透明背景，不是真正的 terrain 过渡，只是草地岛屿的边缘集合）
- **左块 (x=0..3, y=4..5) + (x3_y0..y5 竖条)**：独立 strip / 单格 island 装饰，非标准 autotile
- **右块 (x=5..8, y=0..3)**：另一个 4×4 **grass-island** 过渡组，与左块几乎完全一样（可能只是 variant）
- **右块 (x=5..8, y=4..5)**：**4×2 stone cliff** —— 这是"站立石壁"侧视贴图，**不是 autotile 过渡组**，而是悬崖正面 + 顶部的 2 行拼接（顶部行是 "grass 顶 + cliff 脚" 过渡，底部行是 "cliff 纯石壁"）

## 54 tiles 详细标注

**4 角标记法**（NW / NE / SW / SE）允许值：`grass`, `cliff`, `void`, `unknown`。

| coord | NW / NE / SW / SE | 分组 | 备注 |
|---|---|---|---|
| (0,0) | void / void / void / grass | grass-island 过渡组 L | 左上外角（草地岛西北角） |
| (1,0) | void / void / grass / grass | grass-island 过渡组 L | 岛北边 |
| (2,0) | void / void / grass / void | grass-island 过渡组 L | 右上外角（岛东北角） |
| (3,0) | void / void / grass / void | 装饰-窄条 L | 1 格宽草条顶（左右都是 void），非 autotile 组成员 |
| (4,0) | void / void / void / void | 空 | 空列 gap |
| (5,0) | void / void / void / grass | grass-island 过渡组 R | 同 (0,0)，右块副本 |
| (6,0) | void / void / grass / grass | grass-island 过渡组 R | 同 (1,0) |
| (7,0) | void / void / grass / void | grass-island 过渡组 R | 同 (2,0) |
| (8,0) | void / void / grass / void | 装饰-窄条 R | 同 (3,0) |
| (0,1) | void / grass / void / grass | grass-island 过渡组 L | 岛西边 |
| (1,1) | grass / grass / grass / grass | grass-island 过渡组 L | 纯草中心填充 ★ |
| (2,1) | grass / void / grass / void | grass-island 过渡组 L | 岛东边 |
| (3,1) | void / void / grass / void | 装饰-窄条 L | 草条中段 |
| (4,1) | void / void / void / void | 空 | — |
| (5,1) | void / grass / void / grass | grass-island 过渡组 R | 同 (0,1) |
| (6,1) | grass / grass / grass / grass | grass-island 过渡组 R | 纯草中心填充 ★（commit 1ac074b 当"草地"用的就是它，正确） |
| (7,1) | grass / void / grass / void | grass-island 过渡组 R | 同 (2,1) |
| (8,1) | void / void / grass / void | 装饰-窄条 R | 草条中段 |
| (0,2) | void / grass / void / grass | grass-island 过渡组 L | 岛西边（中段） |
| (1,2) | grass / grass / grass / grass | grass-island 过渡组 L | 纯草中心填充（variant） |
| (2,2) | grass / void / grass / void | grass-island 过渡组 L | 岛东边（中段） |
| (3,2) | void / void / grass / void | 装饰-窄条 L | 草条中段 |
| (4,2) | void / void / void / void | 空 | — |
| (5,2) | void / grass / void / grass | grass-island 过渡组 R | 同 (0,2) |
| (6,2) | grass / grass / grass / grass | grass-island 过渡组 R | 纯草中心填充（variant） |
| (7,2) | grass / void / grass / void | grass-island 过渡组 R | 同 (2,2) |
| (8,2) | void / void / grass / void | 装饰-窄条 R | 草条中段 |
| (0,3) | void / grass / void / void | grass-island 过渡组 L | 左下外角（岛西南角） |
| (1,3) | grass / grass / void / void | grass-island 过渡组 L | 岛南边 |
| (2,3) | grass / void / void / void | grass-island 过渡组 L | 右下外角（岛东南角） |
| (3,3) | void / void / void / void（但贴图有草） | 装饰-单格岛 L | 1 格独立草岛（四周 void），非 autotile 组成员 |
| (4,3) | void / void / void / void | 空 | — |
| (5,3) | void / grass / void / void | grass-island 过渡组 R | 同 (0,3) |
| (6,3) | grass / grass / void / void | grass-island 过渡组 R | 同 (1,3) |
| (7,3) | grass / void / void / void | grass-island 过渡组 R | 同 (2,3) |
| (8,3) | void / void / void / void（但贴图有草） | 装饰-单格岛 R | 同 (3,3) |
| (0,4) | grass / grass / void / void | 装饰-1 格草团 L | 独立草团（西北斜向），非 autotile；**存疑：可能是装饰性 edge 变体** |
| (1,4) | void / void / void / void | 空 | — |
| (2,4) | void / void / void / void | 空 | — |
| (3,4) | grass / grass / void / void | 装饰-1 格草团 L | 独立草团（东北斜向），同 (0,4) 镜像 |
| (4,4) | void / void / void / void | 空 | — |
| (5,4) | grass / grass / cliff / cliff | **grass↔cliff 过渡组 R** | 悬崖**顶部左**（上是草，下是石壁）★ |
| (6,4) | grass / grass / cliff / cliff | **grass↔cliff 过渡组 R** | 悬崖顶部中 ★ |
| (7,4) | grass / grass / cliff / cliff | **grass↔cliff 过渡组 R** | 悬崖顶部中 ★ |
| (8,4) | grass / grass / cliff / cliff | **grass↔cliff 过渡组 R** | 悬崖顶部右 ★ |
| (0,5) | grass / grass / void / void | 装饰-1 格草团底 L | (0,4) 的下半，合起来是 2 格独立草团 |
| (1,5) | void / void / void / void | 空 | — |
| (2,5) | void / void / void / void | 空 | — |
| (3,5) | grass / grass / void / void | 装饰-1 格草团底 L | (3,4) 的下半 |
| (4,5) | void / void / void / void | 空 | — |
| (5,5) | cliff / cliff / cliff / cliff | **grass↔cliff 过渡组 R** | 悬崖纯石壁中段 ★（**原 commit 1ac074b 当"水"用 = 错**） |
| (6,5) | cliff / cliff / cliff / cliff | **grass↔cliff 过渡组 R** | 悬崖纯石壁中段 ★ |
| (7,5) | cliff / cliff / cliff / cliff | **grass↔cliff 过渡组 R** | 悬崖纯石壁中段 ★ |
| (8,5) | cliff / cliff / cliff / cliff | **grass↔cliff 过渡组 R** | 悬崖纯石壁底（底部外侧微圆角）★ |

★ 标注 = 阶段 3 要放进 TerrainSet 的候选

## 分组汇总

### A 组：grass-island 过渡组 L (左块，x=0..2, y=0..3, 共 12 tiles)
坐标：(0,0) (1,0) (2,0) (0,1) (1,1) (2,1) (0,2) (1,2) (2,2) (0,3) (1,3) (2,3)

这是一个 3×4 autotile，4 角是 `grass` 或 `void`（非 grass）。对应 Godot TileSet 的 `TERRAIN_MATCH_CORNERS` 模式（简化模型，只看 4 角），可以覆盖岛屿所有 9 种典型角：
- 四角外：纯内部 (1,1)/(1,2)
- 边：(1,0)北 / (0,1)(0,2)西 / (2,1)(2,2)东 / (1,3)南
- 角：(0,0)西北 / (2,0)东北 / (0,3)西南 / (2,3)东南

**但这个组只能做"草 vs 非草(void)"，没有第二种实体 terrain 过渡** —— 也就是说它画不出"草接水"或"草接石"，只能画"草地岛漂浮在透明背景上"。

### B 组：grass-island 过渡组 R (右块，x=5..7, y=0..3, 共 12 tiles)
坐标：(5,0)..(7,3)，与 A 组**几乎完全相同**（variant，视觉上是同一组的第二份副本）

### C 组：grass↔cliff 过渡组 R (右块，x=5..8, y=4..5, 共 8 tiles)
坐标：(5,4) (6,4) (7,4) (8,4) (5,5) (6,5) (7,5) (8,5)

这是**本 atlas 唯一的真正两实体 terrain 过渡**：草地 ↔ 石壁悬崖。

结构：
- y=4 一行：4 tile 全是"上半草 + 下半石壁"（悬崖顶部）
- y=5 一行：4 tile 全是"纯石壁"（悬崖中/底段）

但只有 **2 行 × 4 列 = 8 tile**，不足以覆盖 `CORNERS_AND_SIDES` 模式需要的全部 15 种 2-terrain 组合（Wang 4-corners 的完整集合需要 16 tiles）。

**→ 这个组实际上是"水平条带式 2×N 悬崖"，设计上只能铺"顶视草地下方有一段垂直石壁"这种场景，不能铺任意形状的石壁区域。**

**实战用法**：铺草地时，如果某块区域需要"南边接一段悬崖"，就沿该南边铺 (5..8, 4) + (5..8, 5) 两行。仅此而已，不是全向 autotile。

### D 组：装饰（独立 tile，非过渡组成员）
坐标：
- (3,0) (3,1) (3,2) (8,0) (8,1) (8,2)：单列草条
- (3,3) (8,3)：单格独立草岛
- (0,4) (0,5) (3,4) (3,5)：成对草团（西/东斜向）

这些是装饰性独立 tile，**不放进 TerrainSet**，阶段 3 如需使用按普通 atlas tile 引用即可。

### E 组：空白（void，atlas gap）
坐标：整列 (4, *) + (1,4)(2,4)(1,5)(2,5)(4,4)(4,5) = 14 tiles

空，忽略。

## 分组统计
| 组 | Tiles | 用途 | 进 TerrainSet? |
|---|---|---|---|
| A: grass-island L | 12 | 草地岛（单 terrain vs void） | 可选，和 B 二选一 |
| B: grass-island R | 12 | 草地岛（同 A） | 可选，和 A 二选一 |
| C: grass↔cliff | 8 | 草地南接悬崖 | 是 ★ |
| D: 装饰 | 12 | 独立草条/草岛/草团 | 否 |
| E: 空 | 14 | atlas gap | 否 |
| **合计** | **58** | | |

> 注：合计 58 > 54 是因为 (0,4)(0,5)(3,4)(3,5) 在 D 里算了 4 个，它们同时也落在"左块 y=4/y=5"区域。实际 atlas 54 tiles，分组不重叠：A(12) + B(12) + C(8) + D(12) + E(14 - 4=10) = 54。（(0,4)(0,5)(3,4)(3,5) 是 D 装饰，不在 E 里）

修正：A(12) + B(12) + C(8) + D(12) + E(10) = **54** ✓

## 存疑 / unknown tile

没有 unknown。所有 54 tile 归属已明确。

但有**两个设计层面的问题要用户决策**（见下方"等确认"）。

## 等用户确认

1. **地形语义修正**：Atlas 没有水，只有 grass / cliff。S2 里 `GridSystem` / `TerrainTileData` 的 `water.tres` 是否要改名为 `cliff.tres`？或者先不改数据层，S2 视觉上就用 **grass 纯铺 + 在地图一角放一条 grass↔cliff 过渡演示**？
2. **阶段 3 TerrainSet 方案**：
   - 方案 α：**只配 1 个 TerrainSet，只包含 C 组（8 tile, grass↔cliff）**，2 terrains = grass / cliff，peering bits 按 CORNERS_AND_SIDES 或 CORNERS 模式填。A/B 组不进 TerrainSet，用作"草地岛"效果时手动铺（或另起 1 个 TerrainSet「grass-island」包 A 或 B，2 terrains = grass / void）。
   - 方案 β：配 2 个 TerrainSet：TerrainSet 0 = grass-island（A 或 B，12 tile），TerrainSet 1 = grass↔cliff（C，8 tile）。D 组装饰走普通 atlas tile。
   - **我建议 β**，因为：(a) 素材确实是成组的，用户明确说"禁止全塞 1 个"，两组就是两个 TerrainSet；(b) S2 地图主体是草地，用 grass-island 让草地边缘自动收边，再在局部铺悬崖，语义清晰。
3. **peering bits 具体填法**：等你确认方案后，我会把 C 组 8 tile 的 4 角标注按 Godot `set_terrain_peering_bit` 的 BIT_TOP_LEFT/TOP/TOP_RIGHT/... 顺序列成配置表给你审，再进阶段 3。
