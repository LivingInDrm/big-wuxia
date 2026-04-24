# Unity Isometric Map -> Godot 4 TileMap 调研

调研日期：2026-04-25

范围：
- 外部调研：Unity 2D Tilemap -> Godot 4、Tiled 中间格式、Godot 4 isometric / TileSet / TileMapLayer 实践、SRPG 地图导入做法
- 本地实测：`wulinsh-assets/maps/scenes/Map_10020`、`Map_10040`、`Map_10060`
- 目标：为 big-wuxia 设计可实施的地图转换方案，不写转换代码

## TL;DR

- **推荐方案：B. 离线预编译成 Godot 原生资源，保留 isometric 视觉与网格坐标，但把寻路逻辑从“地形 layer”解耦到“walkability layer / LevelData”。**
- **不推荐直接保持现有 64x64 正交 TileSet 然后做坐标映射。** 这会把渲染、碰撞、寻路、点击换算全部变成自定义约定，长期成本高于一次性切到 Godot isometric。
- **Tiled 适合作为参考模型，不适合作为主产物。** 社区和插件生态证明了 `.tmx/.tmj -> Godot` 这条链可行，但你们当前源数据已经是解包 JSON，不是 Unity 官方 `.unity` / `.prefab` / `.asset`；再绕一层 Tiled 只会增加一个需要维护的格式。
- **数据上存在一个必须前置处理的风险：并非所有 tile 都能从 `tiles/sprites.json` 回查到 texture 和 rect。** `Map_10040` 有 7,908 个 tile、`Map_10060` 有 331 个 tile 只有 `spr_*` 名称，没有 texture / sprite_rect；这些层主要出现在 `TopRoof` / 部分 `Ground1/2/3`。

## 1. 行业方案调研

### 1.1 Unity 2D Tilemap -> Godot 4：现成工具现状

结论：
- **没有发现成熟、专门做 Unity 2D Tilemap -> Godot 4 TileMap 的开源转换器。**
- 能找到的“Unity -> Godot”工具更偏通用资源导入，不是专门解决 2D Tilemap 数据模型转换。
- 社区中更常见的稳定做法是：**先转到 Tiled / LDtk / 自定义 JSON，再进 Godot**。

证据：
- `V-Sekai/unidot_importer` 是通用 `.unitypackage` / `.unity` / `.prefab` 转译器，重点在场景、prefab、mesh、material、anim，不是 Tilemap 专项转换器。  
  Source: https://github.com/V-Sekai/unidot_importer
- Godot 侧成熟地图导入插件主要围绕 **Tiled** 和 **LDtk**，不是 Unity Tilemap 原生格式。  
  Sources:
  - https://github.com/Kiamo2/YATI
  - https://github.com/vnen/godot-tiled-importer
  - https://github.com/heygleeson/godot-ldtk-importer

判断：
- 对你们这批已经“解包成 JSON + sprites.json + textures/”的 Unity 数据，**自己做离线转换器**比试图找“Unity -> Godot”现成工具更现实。

### 1.2 Tiled 作为中间格式是否可行

结论：
- **可行，但更适合作为验证/编辑中间格式，不适合作为最终长期主链路。**

为什么可行：
- Tiled 官方文档明确说明，**Godot 4 已有对应导出插件**。  
  Source: https://doc.mapeditor.org/en/latest/manual/export-tscn/
- `YATI` 支持把 `.tmx/.tmj` 导入 Godot 4。  
  Source: https://github.com/Kiamo2/YATI
- `vnen/godot-tiled-importer` 支持 isometric / staggered / hexagonal，并能把每层导入为 Godot TileMap。  
  Source: https://github.com/vnen/godot-tiled-importer

为什么不建议做主链路：
- 你们的输入已经不是 Unity 编辑器资产，而是**自定义解包 JSON**。转成 TMX 只是为了再被 Godot 插件读一次，价值有限。
- Godot 4 自己的 TileMap / TileSet 数据模型已经变动过一次，依赖第三方导入插件会引入额外升级面。
- 你们还需要写入 `custom_data`、`walkable`、`terrain_type`、`LevelData`、战斗专用逻辑；这些都比单纯“把图摆出来”多一层业务语义，最终仍然要有自己的后处理。

建议：
- **把 Tiled 当“比照格式”而不是“运行产物”。**
- 如果后续要给关卡设计师提供人工修图入口，可以考虑“导出 TMJ + Tiled 编辑 + 再回 Godot”的旁路，但不建议让运行时依赖它。

### 1.3 Unity Tilemap 和 Godot TileMap 的数据模型差异

结论：
- **两边都能表达网格 + 图块 + 层，但 Godot 4 把更多 tile 语义前置到了 TileSet。**
- 这意味着从 Unity 过来时，不只是搬 cell，还要重建 TileSet 里的 tile metadata。

Godot 4 侧要点：
- `TileMapLayer` 现在是一层一个节点；官方明确说 `TileMap` 已废弃，推荐多个 `TileMapLayer`。  
  Source: https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- TileSet 负责 tile shape、layout、atlas source、custom data、physics/navigation/occlusion。  
  Sources:
  - https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html
  - https://docs.godotengine.org/en/4.0/classes/class_tilesetatlassource.html
- Godot 4 还把很多 per-tile 属性从 TileMap 移到 TileSet。  
  Source: https://docs.godotengine.org/en/4.0/tutorials/2d/using_tilemaps.html

对当前项目的影响：
- 不能只把 Unity layer JSON 直接映射成 `set_cell()`。
- 还需要生成：
  - TileSet atlas source
  - 每个 tile 的 `custom_data`
  - 必要时的 navigation / collision / occlusion layer
  - 每层的 y-sort / z-index 策略

### 1.4 社区里的常见做法

结论：
- **多层地图：多个 `TileMapLayer` 节点。**
- **外部编辑器导入：Tiled / LDtk。**
- **isometric 排序：依赖 Y-sort，但多层立体遮挡仍然是一个高频痛点。**

证据：
- Godot 官方文档明确说可用多个 `TileMapLayer` 达成旧 `TileMap` 的多层效果。  
  Source: https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- Tiled / LDtk 插件都把“分层导入 + post-import 脚本 + TileSet custom data”作为标准工作流。  
  Sources:
  - https://github.com/Kiamo2/YATI
  - https://github.com/heygleeson/godot-ldtk-importer
- Godot Forum 上关于 isometric layer stacking / YSort 的讨论很多，问题集中在“层内 Y-sort 正常，但跨层立体遮挡很难自动正确”。  
  Sources:
  - https://forum.godotengine.org/t/how-do-i-correctly-stack-isometric-tilemaplayers/113870
  - https://forum.godotengine.org/t/best-practice-for-stacking-tilemaplayer-nodes-with-ysort-in-godot-4-4/120306

对本项目的启示：
- 你们不应尝试把 6~13 个逻辑层“压扁成一个 Godot TileMapLayer”。
- 更合理的是：**按渲染职责拆层，再单独提炼 walkability 数据。**

## 2. Godot 4 Isometric TileMap 最佳实践

### 2.1 应该用 Godot isometric 还是继续正交

结论：
- **推荐直接使用 Godot 的 isometric TileSet / TileMapLayer。**

理由：
- 官方 TileSet 支持 `TILE_SHAPE_ISOMETRIC`，并提供 `Tile Layout` / `Tile Offset Axis`。  
  Source: https://docs.godotengine.org/en/latest/classes/class_tileset.html
- 现有素材本身就是菱形 isometric footprint，主地面 tile 高频尺寸就是 `66x43` / `66x36`，天然对应 isometric 渲染。
- 如果继续保留正交逻辑：
  - 鼠标点击 -> cell 反算要自写
  - Unit 排序和遮挡要自写
  - Tile footprint 和 texture origin 要自写
  - GridSystem 里“4 邻格”与“屏幕方向”会长期反直觉

保留 isometric 并不会破坏战棋逻辑：
- `GridSystem` 现在只依赖 `Vector2i` 网格坐标和 `get_used_cells()`；它并不真的要求画面是正交。
- 只要 `cell -> logical coord` 保持一致，A* / move range 仍然是 4 邻格，只是视觉上变成菱形。

### 2.2 cell_size 如何对应 Unity 的 `[1.0, 0.5, 1.0]`

结论：
- Unity 的 `cell_size [1.0, 0.5, 1.0]` 表示“纵向半高”的 isometric grid。
- 对你们这批贴图，**像素投影更接近 `half_width = 33px`、`half_height = 21px~21.5px`，即 tile footprint 约 `66x42~43`。**

本地验证：
- 用公式

```text
screen_x = (x - y) * 33 + offset_x
screen_y = (x + y) * 21 + offset_y
```

对 `Map_10020` 和 `Map_10040` 重算所有“有 texture + sprite_rect”的 tile 边界框，得到的总宽度与 `composite.png` **完全一致**，总高度只差 `14~20px`。

- `Map_10060` 用 `screen_y = (x + y) * 21.5 + offset_y` 时，重建边界框与 `composite.png` 的总尺寸只差 `6.5px`。

说明：
- 这里的差值很小，且主要来自 sprite pivot / 顶部装饰高度 / 缺失 `spr_*` tile。
- 足以说明这批地图不是“64x64 正交格伪装成斜视图”，而是真正的 isometric cell 投影。

建议：
- Godot TileSet 的 `tile_shape` 设为 isometric。
- `tile_size` 不要继续沿用现有 `64x64` 战斗草地图，而应为**新建 battle isometric tileset**，以 `66x43` 作为主 footprint 标尺。

### 2.3 多层渲染排序

结论：
- **底层地面层可固定 z-index；会与角色发生遮挡的层才启用 Y-sort。**

Godot 官方相关能力：
- TileMapLayer 有 `y_sort_origin`、`x_draw_order_reversed`、`rendering_quadrant_size`。  
  Source: https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- 官方 TileSet 文档明确指出：**isometric TileSet 最好让 sibling TileMapLayer 和其父 Node2D 开启 Y-sort。**  
  Source: https://docs.godotengine.org/en/latest/classes/class_tileset.html

但社区反馈也说明：
- 多个 Y-sorted TileMapLayer 之间做“真正三维柱体式遮挡”并不完美，是常见痛点。  
  Sources:
  - https://forum.godotengine.org/t/how-do-i-correctly-stack-isometric-tilemaplayers/113870
  - https://forum.godotengine.org/t/best-practice-for-stacking-tilemaplayer-nodes-with-ysort-in-godot-4-4/120306

对 big-wuxia 的落地建议：
- `Ground*`：不需要和角色做高低遮挡，可固定在角色下方。
- `Wall` / `BuildingFront` 一类：如果要让单位“走到建筑后方”，这些层需要和单位共同参与 Y-sort。
- `TopRoof`：优先作为独立 overlay 层，不参与寻路。
- `_Block`：不渲染或只做 debug overlay；它本质是逻辑阻挡层。

### 2.4 性能：553 场景、10000+ 格可否承受

结论：
- **可以，但前提是离线预编译、按需加载单张战斗地图，而不是运行时动态从 JSON 全量构建。**

依据：
- Godot 官方一直把 TileMapLayer定位为“大量网格 tile 的优化渲染节点”。  
  Source: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html
- `TileMapLayer` 有 `rendering_quadrant_size` / `physics_quadrant_size`；说明底层就是按 quadrant 批渲染。  
  Source: https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- 但同一文档也说明：**Y-sorted TileMapLayer 不使用 quadrant 这一优化路径。**

因此：
- 553 不是同时在线数量，只是离线资源总数，问题不大。
- 单图 5k~26k tile 也不是问题，问题在于：
  - 是否每次进战斗都要解析 JSON + 建 TileSet
  - 是否把所有上层装饰层都做成 Y-sort
  - 是否引入 scene tiles / 运行时 collision rebuild

推荐做法：
- **离线生成 `.tres/.tscn`，运行时只 load 已编译资源。**
- 地面层尽量非 Y-sort；只让必须和单位互相遮挡的层启用 Y-sort。

## 3. 瓦片图集（Atlas）转换

### 3.1 Unity sprite atlas -> Godot TileSetAtlasSource 的映射

结论：
- **技术上可以一一映射。**

映射关系：
- Unity `texture` -> Godot `TileSetAtlasSource.texture`
- Unity `sprite_rect(x,y,w,h)` -> Godot atlas 中 tile 的 texture region
- Unity `pivot_x/pivot_y` -> Godot tile 的 `texture_origin`
- Unity `sprite_name` -> tile custom data / 命名表

Godot 侧能力：
- 一个 TileSet 可以包含多个 atlas source。  
  Source: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html
- `TileSetAtlasSource` 允许通过 atlas 坐标和 alternative tile 写 TileData。  
  Source: https://docs.godotengine.org/en/4.0/classes/class_tilesetatlassource.html

对当前数据的现实情况：
- 在 3 张样本图里，**76 张 texture 对应 120 个 sprite**。
- 其中 **59 张 texture 只含 1 个 sprite**，`12` 张 texture 含 `3` 个 sprite，`4` 张 texture 含 `2` 个 sprite，`1` 张 texture 含 `4` 个 sprite。
- 这说明当前解包库并不是“统一大图集”，而是“很多已经被拆散的小 PNG + 少量仍带切片关系的小 atlas”。

### 3.2 非标准尺寸怎么办

结论：
- **不能指望所有 sprite 共用同一个固定 `texture_region_size`。**
- 最稳妥做法是：**按“footprint 规格”分 TileSetAtlasSource，而不是按整图一个 atlas。**

样本里的高频尺寸：
- `66x43`：主地面
- `66x36`：TopRoof / 某些地面
- `62x32`：Block / 阻挡格
- `70~80 x 118~130`：墙体 / 高物件
- 还有 `43x120`、`33x69`、`48x25` 等少量长条或碎片

Godot 文档也明确提醒：
- TileSet 编辑流默认假设 tilesheet 中 tile 尺寸一致；大对象通常需要拆成多个 tile。  
  Source: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html

因此在你们的转换器里，应该区分两类：
- **规则 footprint tile**：地面、block、大部分 roof，适合放进统一 TileSetAtlasSource
- **不规则高物件**：墙、柱、长条装饰，更适合：
  - 作为 atlas 中“带 `texture_origin` 偏移”的 tile
  - 或者转成独立 decoration layer / Sprite2D batch

### 3.3 要不要重新打成统一 atlas PNG

结论：
- **建议重新打包，但只做“转换产物 atlas”，不要改原素材库。**

原因：
- Godot 一个 TileSet 支持多个 atlas，没有硬性要求“一张大图”。
- 但当前素材过于碎片化，运行时如果直接引用大量小纹理：
  - TileSet 管理复杂
  - 导入产物膨胀
  - 后续人工编辑困难

推荐策略：
- 原始 `wulinsh-assets/` 保持只读。
- 转换器输出到项目资源目录时，做一次**稳定、可复现的 repack**：
  - `battle_iso_ground_atlas.png`
  - `battle_iso_wall_atlas.png`
  - `battle_iso_overlay_atlas.png`
- 同时输出 `sprite_name -> atlas_source_id / atlas_coords / texture_origin` 索引表。

## 4. 战术 / 回合制地图系统设计参考

### 4.1 同类 Godot 项目的常见做法

结论：
- **地图导入和战斗逻辑通常分层。**
- 地图资源负责“长什么样 + 哪些格存在”，战斗系统自己维护“可走 / 地形 / 占用 / 高度 / 事件”。

证据：
- Godot 官方 RPG / Grid-based navigation 示例都把 TileMap 当“底层空间表达”，路径逻辑仍在脚本层。  
  Source: https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- LDtk / Tiled 导入插件都强调 post-import、custom data、entity layer，说明行业常规做法不是把所有 gameplay 都压在 tile 渲染层里。  
  Sources:
  - https://github.com/heygleeson/godot-ldtk-importer
  - https://github.com/vnen/godot-tiled-importer

对 big-wuxia 的含义：
- `TerrainLayer` 不应该再承担“既是渲染、又是唯一寻路真相”的职责。
- 更稳的是：
  - TileMapLayer：渲染与 editor 可视化
  - `LevelData`：战斗语义数据
  - `GridSystem`：运行时网格状态

### 4.2 哪些插件 / addon 值得参考

可参考，但不建议直接变成主依赖：
- `YATI`：看它如何把 Tiled map 变成 Godot 4 资源。  
  Source: https://github.com/Kiamo2/YATI
- `godot-ldtk-importer`：看它如何做 post-import、custom data、可编辑 TileSet 保持。  
  Source: https://github.com/heygleeson/godot-ldtk-importer
- `better-terrain`：可参考其对 Godot 4 terrain API 的批评，说明不要过度依赖运行时 terrain connect。  
  Source: https://github.com/Portponky/better-terrain

对当前项目的结论：
- 这些插件更适合借鉴“资源生成流程”，不适合作为 battle map 的核心运行时依赖。

### 4.3 运行时动态加载 vs 预编译 `.tscn`

结论：
- **推荐预编译；运行时动态加载只保留给 debug / tools。**

对比：

| 方案 | 优点 | 缺点 | 适合度 |
| --- | --- | --- | --- |
| 运行时读 JSON + 程序化建 TileMap | 迭代快、无需预处理 | 首次加载慢、debug 难、资源不可见、TileSet 每次构建昂贵 | 低 |
| 离线转 `.tscn/.tres`，运行时直接 `load()` | 加载稳定、Godot 原生、可在 editor 检查、易做缓存 | 需要写一次转换器和资源版本管理 | 高 |

推荐：
- 正式链路：预编译 `.tscn/.tres`
- 开发链路：保留一个“从 JSON 直接预览”的工具脚本，只用于分析和回归验证

## 5. 本地数据分析：3 张样本地图

### 5.1 场景概况

| Map | 总 tile 数 | layer 数 | scene bounds | composite 大小 |
| --- | ---: | ---: | --- | --- |
| `Map_10020` | 5,842 | 6 | `x 0..61`, `y 0..60` | `3960x2623` |
| `Map_10040` | 20,145 | 8 | `x -16..118`, `y -3..78` | `5511x4235` |
| `Map_10060` | 26,215 | 13 | `x -1..98`, `y -4..106` | `6501x4235` |

观察：
- 样本跨度已经覆盖了“小型单院落图”、“大屋顶城建图”、“多层地形台阶图”三类。
- `Map_10040` / `Map_10060` 都出现了 `TopRoof`，而 `Map_10020` 没有。
- `Map_10060` 的 `_Block` 高达 `7,366`，说明它很可能是“可走区域裁剪层”，不是点缀。

### 5.2 坐标系分析

#### 分布

`Map_10020`
- `Ground0`: `x 0..60`, `y 0..59`
- `Wall`: `x 0..61`, `y 0..59`
- `_Block`: `x 0..60`, `y 0..60`

`Map_10040`
- `Ground0`: `x -10..116`, `y -1..74`
- `TopRoof`: `x -16..118`, `y -3..78`
- `Wall`: `x -15..114`, `y -1..67`
- `_Block`: `x 0..115`, `y 6..66`

`Map_10060`
- `Ground0`: `x 0..94`, `y 0..101`
- `TopRoof`: `x 0..98`, `y -4..106`
- `Wall`: `x 0..95`, `y -3..101`
- `_Block`: `x -1..94`, `y 3..103`

结论：
- layer 的 `origin` / `size` 可视为 envelope，不是最终逻辑坐标真相；真正可靠的是 tile 列表里的 `x/y`。
- 所有层共享同一组 isometric grid 坐标，没有看到“某层独立局部坐标”的情况。

#### Unity isometric -> Godot isometric 转换公式

推荐采用：

```text
godot_cell = Vector2i(unity_x, unity_y)
screen_x = (unity_x - unity_y) * 33 + offset_x
screen_y = (unity_x + unity_y) * 21~21.5 + offset_y
```

解释：
- `Vector2i` 网格坐标本身可以不改。
- 视觉投影由 Godot isometric TileSet 决定。
- `offset_x / offset_y` 是每张地图的整体平移，不应编码进单 tile。

#### 和 composite.png 的验证

使用上面的像素投影并结合 `pivot_x/pivot_y` 还原 tile 边界框，结果如下：

| Map | 用于验证的投影 | 还原 bbox | composite | 误差 |
| --- | --- | --- | --- | --- |
| `Map_10020` | `33 / 21` | `3960 x 2603` | `3960 x 2623` | `0 / -20` |
| `Map_10040` | `33 / 21` | `5511 x 4221` | `5511 x 4235` | `0 / -14` |
| `Map_10060` | `33 / 21.5` | `6501 x 4228.5` | `6501 x 4235` | `0 / -6.5` |

结论：
- **宽度完全匹配，说明横向 footprint 的 `66px` 非常稳定。**
- 高度误差很小，足以验证主投影是 isometric，不是正交重采样。

### 5.3 瓦片多样性分析

#### 3 图合计

- 不同 `texture PNG`：`76`
- 不同 `sprite_name`：`120`
- 高频尺寸：
  - `66x43`: `21,424`
  - `62x32`: `9,108`
  - `66x36`: `7,765`
  - `76x125`: `1,729`
  - `76x128`: `1,313`

#### 每图

| Map | texture 数 | sprite 数 | 备注 |
| --- | ---: | ---: | --- |
| `Map_10020` | 32 | 40 | 全部 tile 都能回查 texture + rect |
| `Map_10040` | 28 | 39 | 有 7,908 个 `spr_*` tile 无 texture/rect |
| `Map_10060` | 18 | 43 | 有 331 个 `spr_*` tile 无 texture/rect |

#### sprite 尺寸能否统一

结论：
- **不能统一成一个单一 tile region size。**
- 但可以按用途聚类：
  - `66x43`：地面主 footprint
  - `66x36`：roof / 某类地砖
  - `62x32`：block / 占位逻辑砖
  - `70~80 x 120+`：墙体和竖向物件

这意味着转换器需要支持：
- 多 atlas source
- 非统一 tile region size
- texture origin / pivot 写入

#### layer 语义推断

从命名和分布推断：
- `Ground0/1/2/3/4/6/7/8`：地面或地势台阶，默认可走候选
- `Wall`：墙体，通常阻挡
- `WallCorner`：墙角补片，多数是装饰，但常与 `Wall` 同语义
- `WallThing`：高物件 / 墙上附着物，应视具体 tile 决定是否阻挡
- `BuildingStatic`：纯装饰概率高
- `TopRoof`：屋顶覆盖层，应与 walkability 解耦
- `_Block`：显式阻挡层
- `_ShaftWay`：特殊交互 / 事件标记层，样本太少，暂不定义

### 5.4 层级与排序分析

#### `Map_10020`

排序顺序：
1. `Ground0`
2. `Ground1`
3. `Wall`
4. `WallCorner`
5. `BuildingStatic`
6. `_Block` (`sorting_order = 100`)

解释：
- `_Block` 明显不是渲染主层，更像逻辑覆盖层。
- `Wall` / `WallCorner` 在视觉上位于地面之上。

#### `Map_10040`

排序顺序：
1. `Ground0`
2. `TopRoof`
3. `Ground1`
4. `Wall`
5. `Ground2`
6. `Ground3`
7. `_Block`
8. `_ShaftWay`

解释：
- `TopRoof` 的 `sorting_order = 0` 但坐标范围最大，说明它更像“预先铺好的屋顶覆盖图层”，不代表 walkability。
- `_ShaftWay` 是高优先级逻辑标记。

#### `Map_10060`

排序顺序：
1. `Ground0`
2. `TopRoof`
3. `Ground1`
4. `Wall`
5. `WallCorner`
6. `WallThing`
7. `Ground2`
8. `Ground7`
9. `Ground8`
10. `Ground3`
11. `Ground4`
12. `Ground6`
13. `_Block`

解释：
- `Ground1~Ground8` 不是简单“装饰地面”，而像多级台阶 / 高差补层。
- `TopRoof` 仍应视为覆盖层，而不是寻路依据。

#### 哪些层影响寻路

推荐初版规则：
- 必定阻挡：`_Block`
- 默认阻挡：`Wall`
- 默认不阻挡：`TopRoof`、`BuildingStatic`
- 待人工审校：`WallCorner`、`WallThing`
- 可走候选：全部 `Ground*`

原因：
- 样本里 `Ground*` 与 `_Block` 大量重叠，说明 `_Block` 是在地面上“扣掉不可走格”。
- 这比“只看是否铺了 Ground tile”更接近战斗图的逻辑。

## 6. 推荐方案设计

### 6.1 A / B / C 方案对比

#### A. 保持当前正交战斗系统，只把 Unity isometric 坐标投影成正交逻辑

做法：
- 继续用当前 64x64 正交 TileMap
- Unity `x/y` 转成自定义正交格坐标
- 背景大图或多 Sprite2D 负责表现原始地图

优点：
- 改动 `GridSystem` 最少
- 战斗逻辑几乎不动

缺点：
- 地图不是 TileMap 原生渲染
- 遮挡 / 点击 / 对齐 / 相机边界 / 角色排序都要手写
- 后续任何地图编辑都会越来越难

结论：
- **不推荐。** 这是短期省事、长期吃债。

#### B. 离线转换为 Godot isometric TileSet + 多个 TileMapLayer + 扩展 LevelData

做法：
- 生成 battle 专用 isometric TileSet
- 每个渲染职责一个 TileMapLayer
- `LevelData` 单独记录 walkable / terrain / blockers
- 运行时直接 load `.tscn/.tres`

优点：
- 最符合 Godot 4 模型
- 渲染与逻辑边界清楚
- 可在 editor 里直接检查结果
- 便于后续追加碰撞、导航、地形属性

缺点：
- 初次转换器投入较大
- 需要小改 `BattleController` / `GridSystem` / `LevelData`

结论：
- **推荐方案。**

#### C. 先转 Tiled，再靠 YATI / Tiled importer 进 Godot

做法：
- Unity JSON -> TMJ/TMX
- Tiled 或 Godot 插件导入
- 再写 post-import 适配 battle 逻辑

优点：
- 借用成熟外部生态
- 如果未来需要人工地图编辑，Tiled 更友好

缺点：
- 增加一个额外格式层
- 仍要解决 `spr_*` 缺失 tile、custom data、LevelData 适配
- 对你们当前纯程序化战斗场景收益不够高

结论：
- **可作为辅助验证链路，不作为主方案。**

### 6.2 推荐方案：B 的具体设计

#### a) 转换管线架构

输入：
- `wulinsh-assets/maps/scenes/Map_XXXXX/`
- `wulinsh-assets/maps/tiles/sprites.json`
- `wulinsh-assets/maps/tiles/textures/*.png`

输出：
- `res://resources/maps/imported/<map_id>/<map_id>_tileset.tres`
- `res://resources/maps/imported/<map_id>/<map_id>_battle_map.tscn`
- `res://resources/data/levels/<map_id>.tres`
- 可选：`res://resources/maps/imported/<map_id>/manifest.json`

步骤：
1. 读取 `scene.json` 和 layer JSON
2. 解析全部 `sprite_name -> texture/rect/pivot`
3. 检测缺失 `spr_*` tile 并分类
4. 构建 atlas repack 清单
5. 生成 TileSet
6. 生成多个 TileMapLayer
7. 提取 walkable / blockers / terrain tags
8. 生成 `LevelData`
9. 产出验证图和差异报告

#### b) TileSet 策略

推荐：
- **每个地图一个 TileSet，外加共享“battle_common” TileSet 模板。**

为什么不是一个全局大 TileSet：
- 全库是 `6211` 张 texture、`11489` 个 sprite；对战斗场景来说太大。
- 样本图单图只用 `18~32` 张 texture，局部 TileSet 更轻。

为什么不是“完全每层一个 TileSet”：
- 管理过碎，不利于共享 metadata 和后续审校。

建议 custom data：
- `tile_id`: 原始 `sprite_name`
- `source_texture`: 原始 texture 文件名
- `layer_role`: `ground / wall / roof / block / deco`
- `walkable`: bool
- `terrain_type`: `ground / stairs / wall / roof / block / deco`
- `height_level`: int，可选

#### c) TileMapLayer 策略

推荐按职责生成，而不是 1:1 复制所有 Unity layer：

| Godot 层 | 来源 | 说明 |
| --- | --- | --- |
| `GroundBaseLayer` | `Ground0` | 主地表 |
| `GroundDetailLayer` | 其余 `Ground*` | 台阶、补层、特殊地表 |
| `ObstacleLayer` | `Wall` + 部分 `WallCorner/WallThing` | 会与角色形成遮挡的高物件 |
| `RoofOverlayLayer` | `TopRoof` | 屋顶覆盖层 |
| `DecorationLayer` | `BuildingStatic` + 非阻挡 `WallCorner/WallThing` | 装饰 |
| `DebugBlockLayer` | `_Block` / `_ShaftWay` | 默认隐藏，仅 debug |

原因：
- Unity 原 layer 名里混有“渲染语义”和“逻辑语义”，不适合直接照搬到 battle scene。
- battle 运行时更需要稳定职责边界。

isometric 参数：
- TileSet 设为 isometric
- 主 footprint 以 `66x43` 为基准
- 角色和 `ObstacleLayer` 放在同一个启用 Y-sort 的父节点下

#### d) LevelData 集成

现状：
- `LevelData` 只有 `map_layout`，不足以表达这批地图。

建议新增字段：

```gdscript
@export var walkable_cells: PackedVector2Array
@export var blocked_cells: PackedVector2Array
@export var terrain_by_cell: Dictionary
@export var map_scene: PackedScene
@export var map_id: String
@export var render_origin: Vector2i
```

`map_layout` 的定义也应改成：
- **从 `walkable_cells` 兼容生成**
- 不再默认等于“所有画了地面的格子”

walkable 提取初版规则：
- `Ground*` union
- 再减去 `_Block`
- 再减去 `Wall`
- `WallCorner/WallThing` 走白名单或人工审校

#### e) 运行时加载

推荐：
- **正式环境：预编译方案**
- **工具环境：动态预览方案**

正式环境流程：
1. 读取 `LevelData`
2. 实例化 `map_scene`
3. `GridSystem.init_from_level_data(level_data)` 或 `init_from_walkability(tilemap, level_data)`
4. 再放置单位

不推荐运行时直接读原始 JSON 的原因：
- 解析 + TileSet 构造 + atlas 创建都在热路径
- 你们未来还需要版本管理和可视化校验

## 7. 对当前代码架构的影响

### 7.1 现状限制

当前 `battle_controller.gd`：
- `_paint_map()` 从 `LevelData.map_layout` 铺统一 grass terrain
- `GridSystem.init_from_tilemap(terrain_layer)` 只看一个 `TileMapLayer`

当前 `GridSystem`：
- 依赖 `tile_id` custom data
- 假设寻路层和渲染层是同一层

问题：
- 这套结构对“多层 isometric 地图”表达力不够。

### 7.2 最小必要调整

推荐把 battle map 拆成两条数据流：

1. 渲染流
- `battle_map_root.tscn`
- 多个 `TileMapLayer`

2. 逻辑流
- `LevelData.walkable_cells`
- `LevelData.terrain_by_cell`
- `LevelData.blocked_cells`

然后：
- `GridSystem` 不再从“主渲染层 used_cells”推导整个世界
- 而是优先从 `LevelData.walkable_cells` 初始化
- TileMapLayer 只作为可视化和少量 metadata 的补充来源

这是本方案里最重要的架构调整。

## 8. 风险与未决问题

### 高风险

1. `spr_*` 缺失 tile
- `Map_10040`: `7,908` tile 无 texture / rect
- `Map_10060`: `331` tile 无 texture / rect
- 这些 tile 也不在 `tiles/sprites.json` 中

可能解释：
- 来自 Unity 内部生成 sprite
- 来自另一个未被当前解包脚本覆盖的 atlas / SpriteLibrary
- 或原本就是 composite-only layer

影响：
- 如果不先澄清，无法无损还原 `TopRoof` 和部分细节地面层

建议：
- 先做一次全库追查：这些 `spr_*` 是否存在于其他目录或 `.meta`
- 若追查不到，battle 版可先把这类层降级为“忽略 / 使用 composite 备份叠层”

2. 墙角 / 墙上物件的阻挡语义不完全可靠
- 单靠 layer 名很难 100% 判断
- 需要至少一轮 tile 白名单/黑名单审校

### 中风险

1. Y-sort 多层遮挡
- Godot 4 能做，但不是零成本
- 需要在角色与高物件的层级结构上收敛设计

2. Ground 多层可能隐含高差
- `Map_10060` 的 `Ground1~Ground8` 很像台阶 / 平台
- 当前战斗系统还没有高度系统

建议：
- 第一版先把它们都视作“同平面地表”
- 后续若要做高度差，再在 `terrain_by_cell` 增加 `height_level`

## 9. 最终建议

明确推荐：
- **选择方案 B：离线预编译为 Godot isometric 地图资源。**

推荐理由：
1. 它和 Godot 4 的 TileSet / TileMapLayer 模型一致。
2. 它允许保留当前 Unity 解包数据的 isometric 视觉关系。
3. 它能把 `LevelData` 从“只有一块草地”升级成真正可承载战斗地图语义的数据资源。
4. 它把风险收敛在离线转换期，而不是把问题拖到运行时。

明确不推荐：
- 不要继续让 battle 系统长期依赖“正交 TileMap + 自定义 isometric 假投影”。
- 不要把 `_Block`、`Wall`、`Ground` 混成单个 TileMapLayer 再反推寻路。

## 10. 实施计划

### Phase 1. 资源追查与验证

1. 全库搜索 `spr_*` 缺失 tile 的来源
2. 统计所有地图的 layer 名、尺寸、缺失纹理比例
3. 确认 `TopRoof` 是否允许 battle 版降级为 overlay / 忽略

### Phase 2. 目标数据模型落地

1. 扩展 `LevelData`
2. 设计 `ImportedBattleMap` 目录结构
3. 确定 `layer_role` / `terrain_type` / `walkable` 枚举

### Phase 3. 离线转换器

1. 读取 scene/layer/sprite 数据
2. 构建 repacked atlas
3. 生成 TileSet
4. 生成 TileMapLayer 场景
5. 生成 LevelData
6. 导出验证日志和预览图

### Phase 4. 战斗系统接入

1. `battle_controller.gd` 改为实例化导入地图场景
2. `GridSystem` 改为优先从 `LevelData.walkable_cells` 初始化
3. 单位点击、移动、攻击范围在 isometric 坐标下回归测试

### Phase 5. 校验与人工审图

1. 抽检 10 张代表地图
2. 核对 walkable / blocked 是否符合视觉直觉
3. 为特殊 tile 建立白名单 / 覆盖表

## Sources

- Godot TileMapLayer: https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- Godot Using TileSets: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html
- Godot Using TileMaps: https://docs.godotengine.org/en/4.0/tutorials/2d/using_tilemaps.html
- Godot TileSetAtlasSource: https://docs.godotengine.org/en/4.0/classes/class_tilesetatlassource.html
- Godot TileSet enum docs: https://docs.godotengine.org/en/latest/classes/class_tileset.html
- Tiled Godot 4 exporter docs: https://doc.mapeditor.org/en/latest/manual/export-tscn/
- YATI: https://github.com/Kiamo2/YATI
- Tiled Map Importer: https://github.com/vnen/godot-tiled-importer
- Godot LDtk Importer: https://github.com/heygleeson/godot-ldtk-importer
- Better Terrain: https://github.com/Portponky/better-terrain
- Godot Forum: isometric stacking thread: https://forum.godotengine.org/t/how-do-i-correctly-stack-isometric-tilemaplayers/113870
- Godot Forum: TileMapLayer + YSort best practice: https://forum.godotengine.org/t/best-practice-for-stacking-tilemaplayer-nodes-with-ysort-in-godot-4-4/120306
- Unidot importer: https://github.com/V-Sekai/unidot_importer

## 本地证据

- `wulinsh-assets/ASSET_CATALOG.md`
- `wulinsh-assets/maps/scenes/Map_10020/*`
- `wulinsh-assets/maps/scenes/Map_10040/*`
- `wulinsh-assets/maps/scenes/Map_10060/*`
- `wulinsh-assets/maps/tiles/sprites.json`
- `scenes/battle/battle_controller.gd`
- `scripts/core/level_data.gd`
- `scripts/systems/grid_system.gd`
