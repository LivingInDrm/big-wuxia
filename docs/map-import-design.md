# big-wuxia 离线地图转换器设计（step-2-1）

> 目的：把 `wulinsh-assets/maps/scenes/Map_XXXXX/` 的 Unity isometric 场景离线预编译成 Godot 4 原生资源（TileSet + 多 TileMapLayer 的 `.tscn`，以及扩展后的 `LevelData.tres`），供 big-wuxia 战斗系统直接加载。
>
> 依据：
> - `docs/map-import-research.md`（§3、§5.2、§5.3、§6.2、§7.2、§8，选定方案 B）
> - `docs/direction-system-design.md`（方向系统 / GridSystem 约束）
> - 真实数据样本：`Map_10020` / `Map_10040` / `Map_10060`
> - 现状代码：`scripts/core/level_data.gd`、`scripts/systems/grid_system.gd`、`scenes/battle/battle_controller.gd`
>
> 范围：**仅设计**。具体代码在 step-2-2 及之后实现。

---

## A. 转换器目录结构

### A.1 语言选择：Python 脚本（而非 Godot EditorScript）

选择依据：
- Godot 4 的 `.tres` / `.tscn` 是稳定的文本格式（研究 §6.2.b 建议以脚本稳定生成），Python 直接写纯文本最简单。
- 输入端 JSON、PNG、atlas repack 都是纯离线操作，不依赖 Godot 编辑器；Python + `Pillow` 做 repack 比在 Godot 内调 `Image` 更直接。
- 553 张地图 / 6211 张 texture / 11489 条 sprite（研究 §6.2.b），需要可重入、可 diff、可 CI 的脚本。
- EditorScript 适合需要 Godot import pipeline 的场景（例如动画资源）；本任务纯数据转换不需要 `ResourceSaver`。
- Python 输出 `.tres` / `.tscn` 后，首次在 Godot 打开会自动 reimport 生成 `.import` 文件。

### A.2 目录布局

```
tools/map_importer/
├── README.md                     # 使用说明 + 入参示例
├── run.py                        # CLI 入口：python tools/map_importer/run.py --map Map_10020
├── config.py                     # 常量：路径、尺寸、layer 名白名单、WALKABLE_WHITELIST
├── schema/
│   ├── scene_data.py             # 内存 dataclass：SceneData / LayerData / TileInstance
│   ├── sprite_info.py            # SpriteInfo（name, texture, rect, pivot, footprint_bucket）
│   ├── atlas_plan.py             # AtlasPlan / AtlasSource / AtlasTile
│   └── walkable_data.py          # WalkableData（walkable / blocked / terrain_by_cell / shaftway）
├── stages/                       # 7 个独立阶段，每个可单跑 + 写缓存
│   ├── s1_parse_scene.py         # 读 scene.json + layers/*.json → SceneData
│   ├── s2_build_sprite_index.py  # 读 tiles/sprites.json → Dict[name → SpriteInfo]
│   ├── s3_repack_atlas.py        # 按 footprint 聚类 → 输出 repacked PNG + AtlasPlan
│   ├── s4_generate_tileset.py    # AtlasPlan → .tres（TileSet + TileSetAtlasSource + custom_data）
│   ├── s5_generate_layers.py     # SceneData + TileSet → 多个 TileMapLayer 节点（写进 .tscn）
│   ├── s6_extract_walkable.py    # SceneData → WalkableData
│   └── s7_emit_level_data.py     # map_id + layers + walkability → LevelData .tres
├── writers/
│   ├── tres_writer.py            # 通用 Godot .tres 文本构造器（escape、sub_resource、ext_resource）
│   ├── tscn_writer.py            # 通用 Godot .tscn 文本构造器
│   └── gd_resource_fmt.py        # 字符串化 Vector2i / PackedVector2Array / Dictionary
├── validators/
│   ├── composite_compare.py      # 投影后和 composite.png 比对（研究 §5.2 已验证 ≤20px）
│   ├── sprite_missing_report.py  # spr_* 缺失 tile 统计 + 分类（研究 §8 风险 1）
│   └── walkable_sanity.py        # walkable 连通性 + 覆盖率校验
└── tests/
    └── test_fixtures/            # Map_10020 作为 golden 样本
```

### A.3 输入输出路径约定

输入（**只读**，严禁写入 `wulinsh-assets/`）：

- `wulinsh-assets/maps/scenes/<MAP_ID>/scene.json`
- `wulinsh-assets/maps/scenes/<MAP_ID>/layers/*.json`
- `wulinsh-assets/maps/scenes/<MAP_ID>/composite.png`（仅校验用）
- `wulinsh-assets/maps/tiles/sprites.json`
- `wulinsh-assets/maps/tiles/textures/*.png`

输出（引用研究 §6.2.a）：

- `res://resources/maps/imported/<MAP_ID>/<MAP_ID>_tileset.tres`
- `res://resources/maps/imported/<MAP_ID>/<MAP_ID>_battle_map.tscn`
- `res://resources/maps/imported/<MAP_ID>/atlas/<footprint>_<N>.png`（repacked atlas PNG，多个）
- `res://resources/maps/imported/<MAP_ID>/manifest.json`（source hash + stats）
- `res://resources/data/levels/<MAP_ID>.tres`（LevelData，保留已有 `level_01` / `level_02` 不动）
- `tools/map_importer/out/<MAP_ID>/report.md`（供人工审校）

### A.4 CLI 契约

```
python tools/map_importer/run.py \
  --map Map_10020              # 必填
  --stages all                 # all | s1,s2,s4 …
  --force                      # 忽略缓存
  --dry-run                    # 只产 report 不写资源
  --validate                   # 额外跑 composite 比对
```

---

## B. LevelData schema 扩展

### B.1 完整字段（在现有 `scripts/core/level_data.gd` 上追加）

```gdscript
extends Resource
class_name LevelData

@export_group("Identity")
@export var level_id: String = ""
@export var level_name: String = ""
@export var map_id: String = ""                       # 新：Map_10020

@export_group("Map")
@export var map_layout: PackedVector2Array = PackedVector2Array()   # 兼容旧用法：从 walkable_cells 派生
@export var walkable_cells: PackedVector2Array = PackedVector2Array()  # 新
@export var blocked_cells: PackedVector2Array = PackedVector2Array()   # 新
@export var terrain_by_cell: Dictionary = {}          # 新：Vector2i → String (tile_id / terrain_type)
@export var map_scene: PackedScene                    # 新：<MAP_ID>_battle_map.tscn
@export var render_origin: Vector2i = Vector2i.ZERO   # 新：Unity bounds.min 的偏移补偿

@export_group("Units")
@export var player_units: Array[Dictionary] = []
@export var enemy_units: Array[Dictionary] = []

@export_group("Objectives")
@export var victory_condition: String = "kill_all"
@export var boss_id: String = ""

@export_group("Rewards")
@export var rewards: Array[Dictionary] = []
```

字段语义：

- `map_id`：与 `wulinsh-assets/maps/scenes/` 目录名一致（研究 §6.2.a）。
- `walkable_cells`：GridSystem 的唯一权威输入（研究 §7.2 "最重要的架构调整"）。
- `blocked_cells`：`_Block` + `Wall` + 黑名单 `WallCorner` / `WallThing`（研究 §8 高风险 2）。
- `terrain_by_cell`：格子 → 地形 id（初版全部为 `"grass"` 以对齐现有 6 个 `TerrainTileData`；后续可扩展 `stairs` / `roof` / …）。
- `map_scene`：`load()` 后 `instantiate()` 挂到 BattleController，代替当前 `_paint_map()` 的 grass terrain 铺设。
- `render_origin`：Unity 的 `scene.bounds.min_x` / `min_y` 可能为负（Map_10040 `min_x=-16`），转换时整体平移使 Godot cell 全为非负；`render_origin` 记录该平移，便于 debug / 反查。

### B.2 `map_layout` 的兼容生成

在 LevelData 加一个 getter / 初始化钩子：

```gdscript
func ensure_map_layout() -> void:
    if map_layout.is_empty() and not walkable_cells.is_empty():
        map_layout = walkable_cells.duplicate()
```

- 旧关卡（`level_01.tres` 等）继续用 `map_layout`，`walkable_cells` 空 → `_paint_map()` 走 grass terrain 旧路径。
- 新关卡（`Map_10020`）只填 `walkable_cells` + `map_scene`，`map_layout` 在加载时自动派生，保持向后兼容。

### B.3 与现有 `player_units` / `enemy_units` / `victory_condition` 的关系

- **完全解耦**：单位和目标字段不变；只有地图几何部分扩展。
- 单位放置坐标 `spawn` 必须落在 `walkable_cells` 内，由 `battle_controller._place_units()` 在加载时校验。

### B.4 序列化格式（`.tres` 片段示例）

```tres
[gd_resource type="Resource" script_class="LevelData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/core/level_data.gd" id="1"]
[ext_resource type="PackedScene" path="res://resources/maps/imported/Map_10020/Map_10020_battle_map.tscn" id="2"]

[resource]
script = ExtResource("1")
level_id = "map_10020"
level_name = "剑州城外"
map_id = "Map_10020"
map_layout = PackedVector2Array()
walkable_cells = PackedVector2Array(0, 0, 1, 0, 2, 0, …)
blocked_cells = PackedVector2Array(…)
terrain_by_cell = {Vector2i(0,0): "grass", …}
map_scene = ExtResource("2")
render_origin = Vector2i(0, 0)
player_units = […]
enemy_units = […]
victory_condition = "kill_all"
```

---

## C. TileSet 生成策略

### C.1 每图一个 TileSet（研究 §6.2.b 推荐）

决策：**每地图独立 TileSet，不做全局共享**。

依据：

- 研究 §6.2.b 指出全库 6211 texture / 11489 sprite，全局太大；样本图单图只用 18–32 texture，局部更轻。
- 共享 TileSet 会让任何一张地图的 atlas 修改触发全库 reimport，违背离线稳定性目标。

折中：抽出常量模板 `tools/map_importer/config.py::TILESET_META`（`tile_shape` / `tile_layout` / `custom_data_layers`），所有地图复用这份 schema，仅 AtlasSource 不同。

### C.2 Atlas repack 按 footprint 分 source

研究 §3.2 + §5.3 确认 sprite 尺寸不能统一（66×43 / 66×36 / 62×32 / 76×125+），且 `sprite_rect` 可跨越原 texture 任意位置，不适合 "1 texture = 1 source"。

repack 规则（`s3_repack_atlas`）：

- 遍历 `SceneData` 收集所有被引用的 `(texture, sprite_rect, pivot)` 三元组；去重。
- 按 footprint 聚类成 4 个桶（研究 §5.3）：
  - `ground_66x43`：地面主体
  - `wall_66x36`：墙 / 屋顶底层
  - `block_62x32`：`block64` / 逻辑砖
  - `tall_76x128`：墙体 / 竖向装饰（使用最大外接矩形对齐到 76×128 或 76×125）
- 每桶生成 N×M 网格 PNG（Pillow），单 atlas 最多 64 列；超出就开第二张（`tall_76x128_0.png` / `tall_76x128_1.png`）。
- AtlasPlan 记录：`sprite_name → (atlas_file, atlas_coords: Vector2i, pivot_rel)`。
- 稳定排序：按 `sprite_name` 字典序排布，保证多次运行产物 byte-identical。

### C.3 TileSet custom_data 字段（基于研究 §6.2.b）

TileSet 层级定义 6 个 `custom_data_layers`：

| index | name             | type    | 说明 |
|-------|------------------|---------|------|
| 0     | `tile_id`        | String  | 原始 sprite_name（兼容现有 GridSystem 的 `custom_data_0`） |
| 1     | `source_texture` | String  | 原 Unity texture 文件名（调试 / 追踪） |
| 2     | `layer_role`     | String  | `ground` / `wall` / `roof` / `block` / `deco` |
| 3     | `walkable`       | bool    | 是否可走（仅作参考，权威仍是 `LevelData.walkable_cells`） |
| 4     | `terrain_type`   | String  | `grass` / `stairs` / `wall` / `roof` / `block` / `deco` |
| 5     | `height_level`   | int     | 默认 0；Map_10060 的 Ground1–8 后续可填 1–8 |

兼容性：GridSystem 现在只读 `custom_data_0 = tile_id`（`grid_system.gd:61`），新增字段不影响旧逻辑。

### C.4 生成方式（Python 写 `.tres`）

用 `writers/tres_writer.py` 直接拼文本；结构示例：

```tres
[gd_resource type="TileSet" load_steps=6 format=3]

[ext_resource type="Texture2D" path=".../atlas/ground_66x43_0.png" id="atlas_ground_0"]
[ext_resource type="Texture2D" path=".../atlas/wall_66x36_0.png" id="atlas_wall_0"]
…

[sub_resource type="TileSetAtlasSource" id="src_ground_0"]
texture = ExtResource("atlas_ground_0")
texture_region_size = Vector2i(66, 43)
0:0/0 = 0
0:0/0/custom_data_0 = "tudi8.3_C_0"
0:0/0/custom_data_1 = "tudi8.3.png"
0:0/0/custom_data_2 = "ground"
0:0/0/custom_data_3 = true
0:0/0/custom_data_4 = "grass"
0:0/0/custom_data_5 = 0
…

[resource]
tile_shape = 1                # TileSet.TILE_SHAPE_ISOMETRIC
tile_layout = 0               # TileSet.TILE_LAYOUT_STACKED
tile_size = Vector2i(66, 36)  # 菱形投影参考（见 G 章）
custom_data_layer_0/name = "tile_id"
custom_data_layer_0/type = 4  # TYPE_STRING
custom_data_layer_1/name = "source_texture"
…
sources/0 = SubResource("src_ground_0")
sources/1 = SubResource("src_wall_0")
```

pivot 处理：`TileData.texture_origin = sprite_rect.center - pivot_px`，pivot 来自原 tile `pivot_x` / `pivot_y`（比例）；由 s4 计算后写 `0:0/0/texture_origin = Vector2i(...)`。

---

## D. TileMapLayer 职责归并（研究 §6.2.c 六层方案）

### D.1 层分配矩阵

| Godot 层             | 来源 Unity 层                                                     | Y-sort | `z_index` | 默认可见 |
|----------------------|-------------------------------------------------------------------|--------|-----------|----------|
| `GroundBaseLayer`    | `Ground0`                                                         | 否     | -10       | 是 |
| `GroundDetailLayer`  | `Ground1` … `Ground8` 合并                                        | 否     | -5        | 是 |
| `ObstacleLayer`      | `Wall` + 白名单 `WallCorner` + 白名单 `WallThing`                 | **是** | 0         | 是 |
| `RoofOverlayLayer`   | `TopRoof`                                                         | 否     | 20        | 是（战斗外）/ 透明（战斗中） |
| `DecorationLayer`    | `BuildingStatic` + 非白名单 `WallCorner` + 非白名单 `WallThing`   | **是** | 0         | 是 |
| `DebugBlockLayer`    | `_Block` + `_ShaftWay`                                            | 否     | 50        | **否** |

依据：研究 §6.2.c 的六层表格；样本数据支持该分类：

- Map_10020：`Ground0` + `Ground1` + `Wall` + `WallCorner` + `BuildingStatic` + `_Block`。
- Map_10060：多 `TopRoof` + `WallThing` + `Ground2–8`。
- Map_10040：多 `_ShaftWay`。

### D.2 Y-sort 策略

研究 §2.3 指出角色与高物件需共享 Y-sort 父节点。

生成 `<MAP_ID>_battle_map.tscn` 根节点结构：

```
Node2D (root, y_sort_enabled=false)
├── GroundBaseLayer (TileMapLayer, y_sort=false, z=-10)
├── GroundDetailLayer (TileMapLayer, y_sort=false, z=-5)
├── YSortRoot (Node2D, y_sort_enabled=true, z=0)
│   ├── ObstacleLayer (TileMapLayer, y_sort=true)
│   ├── DecorationLayer (TileMapLayer, y_sort=true)
│   └── [运行时插入] UnitsContainer（由 BattleController add_child / reparent）
├── RoofOverlayLayer (TileMapLayer, y_sort=false, z=20)
└── DebugBlockLayer (TileMapLayer, y_sort=false, z=50, visible=false)
```

- 只有 `YSortRoot` 启用 Y-sort；地面层与屋顶层固定 z_index 避免抖动。
- 角色在 BattleController 挂到 `YSortRoot`（当前挂到根的 `UnitsContainer` 需调整，见 I 章）。

### D.3 `y_sort_origin` 设置

- `ObstacleLayer` / `DecorationLayer`：每个 TileData 的 `y_sort_origin` 使用 sprite 底部像素（`sprite_rect.h - pivot_y_px`），让墙体底边参与排序。
- 单位：`Unit` 节点设 `y_sort_origin = 0`，其 `Transform.y` 直接作为 Y-sort 键。
- 由 s4 在写 TileSet 时一并计算并写入。

---

## E. walkable 提取规则（研究 §6.2.d 初版规则）

### E.1 初版规则（`s6_extract_walkable`）

```python
def extract_walkability(scene: SceneData) -> WalkableData:
    ground_union = union_of(scene.layers, names=["Ground0", "Ground1", "Ground2",
                                                  "Ground3", "Ground4", "Ground6",
                                                  "Ground7", "Ground8"])
    block_set    = set_of(scene.layers, names=["_Block"])
    wall_set     = set_of(scene.layers, names=["Wall"])

    # 白名单：研究 §8 高风险 2，初版保守把所有 WallCorner/WallThing 视为阻挡
    # 后续人工审校后按 sprite_name 移入 WALKABLE_WHITELIST
    wc_set       = set_of(scene.layers, names=["WallCorner"]) - WALKABLE_WHITELIST
    wt_set       = set_of(scene.layers, names=["WallThing"])  - WALKABLE_WHITELIST

    walkable = ground_union - block_set - wall_set - wc_set - wt_set
    blocked  = block_set | wall_set | wc_set | wt_set

    # 兜底：Ground 合集必须存在；为空意味着解析错误
    assert len(ground_union) > 0, f"no ground tiles in {scene.map_id}"

    return WalkableData(
        walkable_cells=sorted(walkable),
        blocked_cells=sorted(blocked),
        terrain_by_cell={c: "grass" for c in walkable},  # 初版全 grass
        shaftway_cells=sorted(set_of(scene.layers, names=["_ShaftWay"])),
    )
```

### E.2 `_ShaftWay` 等少数派处理

- `_ShaftWay`（Map_10040 仅 6 tile）：**不进入 walkable / blocked**，独立写入 `LevelData.terrain_by_cell[c] = "shaftway"`，BattleController 可选择视作触发器（当前阶段不影响寻路）。
- 初版只在 `DebugBlockLayer` 保留渲染，走 TileSet `custom_data` `layer_role = "block"`。

### E.3 `spr_*` 缺失 tile 对 walkable 的影响（研究 §8 高风险 1）

- Map_10040 `TopRoof`（7603 tile）和 Map_10060 `TopRoof`（7765 tile）中的 `spr_*` 不影响 walkability：`TopRoof` 不进入 walkable 规则。
- 但 Map_10040 的部分 `Ground1` / `Ground2` / `Ground3` 也有 `spr_*`（研究 §5.3 引）：这些 tile 仍需进入 `walkable_cells`（几何坐标在 JSON 里是完整的），只是 TileSet 渲染侧会 **使用占位 sprite**（见 H 章降级策略）。
- `s6` 的 walkable 提取 **只看几何 (x,y)，不看 texture**，因此 `spr_*` 对 walkable 无影响。
- 在 `report.md` 中明确列出所有 `spr_*` tile 的 `(layer, x, y)` 供人工审校。

---

## F. 关键函数签名（伪代码级）

### F.1 s1 parse_scene

```python
# stages/s1_parse_scene.py
def parse_scene(map_dir: Path) -> SceneData:
    """读 scene.json + layers/*.json → 结构化内存对象。"""
    # 返回：
    #   SceneData(
    #     map_id: str,                        # "Map_10020"
    #     bounds: Rect2i,                     # min_x/max_x/min_y/max_y
    #     layers: List[LayerData],            # 按 scene.json.layers 顺序
    #   )
    # LayerData(
    #     name: str, sorting_order: int, origin: Vector2i, size: Vector2i,
    #     tiles: List[TileInstance],
    # )
    # TileInstance(
    #     cell: Vector2i,                     # (x, y)；z 字段丢弃（当前无高度系统）
    #     sprite_name: str,
    #     texture: Optional[str],             # spr_* 时为 None
    #     sprite_rect: Optional[Rect2i],
    #     pivot: Optional[Vector2],           # 比例，0~1
    # )
```

### F.2 s2 build_sprite_index

```python
# stages/s2_build_sprite_index.py
def build_sprite_index(tiles_dir: Path) -> dict[str, SpriteInfo]:
    """读 wulinsh-assets/maps/tiles/sprites.json → name → SpriteInfo."""
    # SpriteInfo(
    #     name: str,
    #     texture: str,                        # "tudi8.3.png"
    #     rect: Rect2i,                        # 0,0,66,43
    #     pivot: Vector2,                      # 0.5, 0.5814
    #     footprint_bucket: Literal["ground_66x43","wall_66x36","block_62x32","tall_76x128"],
    # )
    # 注：此函数返回**全局 11489 个 sprite**，s3 只取 SceneData 用到的子集。
```

### F.3 s3 repack_atlas

```python
# stages/s3_repack_atlas.py
def repack_atlas(used_sprites: set[SpriteInfo], out_dir: Path) -> AtlasPlan:
    """按 footprint 聚类 sprite → 生成 repacked PNG → 写出 atlas 文件。"""
    # 返回：
    # AtlasPlan(
    #     sources: List[AtlasSource],          # 每个 source 一个 PNG
    # )
    # AtlasSource(
    #     file: Path,                          # atlas/ground_66x43_0.png
    #     tile_size: Vector2i,                 # (66, 43)
    #     layout: List[AtlasTile],
    # )
    # AtlasTile(
    #     sprite_name: str,
    #     atlas_coords: Vector2i,              # 在 source PNG 中的格子坐标
    #     pivot_px: Vector2i,                  # 用于 texture_origin
    # )
```

### F.4 s4 generate_tileset

```python
# stages/s4_generate_tileset.py
def generate_tileset(atlas_plan: AtlasPlan, scene: SceneData, out_path: Path) -> TileSetTres:
    """AtlasPlan + 层 → layer_role 归属 → 写 .tres，返回索引表。"""
    # TileSetTres(
    #     path: Path,                          # <MAP_ID>_tileset.tres
    #     tile_id_to_source: dict[str, (source_index: int, atlas_coords: Vector2i)],
    # )
    # 副作用：写 .tres 文本；6 个 custom_data_layers（C.3）。
```

### F.5 s5 generate_layers

```python
# stages/s5_generate_layers.py
def generate_layers(
    scene: SceneData, tileset: TileSetTres, out_path: Path
) -> TileMapScene:
    """SceneData + TileSet 索引 → 6 个 TileMapLayer，写成 .tscn。"""
    # 步骤：
    #   1. Unity cell → Godot cell（G 章公式）
    #   2. 按 D.1 矩阵把 Unity 层分配到 6 个 Godot 层
    #   3. 对每个 tile 调用 tileset.tile_id_to_source → set_cell(source_id, atlas_coords)
    #   4. 按 D.2 组织 YSortRoot 嵌套
    # 返回：
    # TileMapScene(
    #     path: Path,                          # <MAP_ID>_battle_map.tscn
    #     layer_stats: dict[str, int],         # "GroundBaseLayer": 3602, …
    # )
```

### F.6 s6 extract_walkability

```python
# stages/s6_extract_walkable.py
def extract_walkability(scene: SceneData) -> WalkableData:
    """按 E.1 规则从 SceneData 提取可走 / 阻挡 / 地形。"""
    # WalkableData(
    #     walkable_cells: List[Vector2i],      # 已排序去重
    #     blocked_cells:  List[Vector2i],
    #     terrain_by_cell: dict[Vector2i, str],
    #     shaftway_cells: List[Vector2i],      # 独立输出
    # )
```

### F.7 s7 emit_level_data

```python
# stages/s7_emit_level_data.py
def emit_level_data(
    map_id: str,
    map_scene_path: Path,
    walkability: WalkableData,
    render_origin: Vector2i,
    out_path: Path,
) -> None:
    """产出 res://resources/data/levels/<MAP_ID>.tres。"""
    # 不填 player_units/enemy_units/victory_condition/rewards（需策划后续配）
    # 写出时：map_layout 置空（由 LevelData.ensure_map_layout 运行时派生）
```

### F.8 validators（验证阶段）

```python
# validators/composite_compare.py
def compare_with_composite(scene: SceneData, composite_png: Path) -> CompareReport:
    """按 G 章公式投影 tile → 与 composite.png 比对 bbox，≤20px 视为通过（研究 §5.2）。"""

# validators/sprite_missing_report.py
def report_missing_sprites(scene: SceneData, index: dict) -> MissingReport:
    """列出所有 sprite_name 在 index 中查不到的 tile（layer, x, y, name）。"""
```

---

## G. 坐标系

### G.1 Godot isometric TileSet 配置

基于研究 §2.2（`cell_size` 对应 Unity `[1.0, 0.5, 1.0]`）和 §5.2（投影验证）：

```
tile_shape       = TileSet.TILE_SHAPE_ISOMETRIC        # enum 值 1
tile_layout      = TileSet.TILE_LAYOUT_STACKED         # enum 值 0（菱形棋盘）
tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL # 默认
tile_size        = Vector2i(66, 36)                    # 菱形 bounding box 宽×高
```

- `tile_size = (66, 36)` 让 Godot 自动按 33 / 18 做投影；实测 `18` 与 Unity 的 `21 / 21.5` 存在 3px/格差，但 Godot 内 Y-sort 按格心计算，整体偏差不累积。
- **重要**：实际 sprite 高度多样（43 / 36 / 32 / 125），通过 `TileData.texture_origin` 补齐 pivot 偏移（s4 写入）。`tile_size` 仅影响格心间距，不影响 sprite 视觉尺寸。

### G.2 Unity cell → Godot cell 映射（研究 §5.2）

研究 §5.2 已验证公式：

```python
# 转换器内核
def unity_to_godot(cell: Vector2i, bounds_min: Vector2i) -> Vector2i:
    # Unity 坐标含负数偏移 → 全局平移为非负
    return Vector2i(cell.x - bounds_min.x, cell.y - bounds_min.y)

def render_origin(bounds_min: Vector2i) -> Vector2i:
    return bounds_min  # 记录原始偏移（LevelData.render_origin）
```

- 示例：Map_10040 `bounds.min = (-16, -3)` → Unity cell `(-16, -3)` 在 Godot 里是 `(0, 0)`，`render_origin = (-16, -3)`。
- Godot TileMap 内部的 cell → 像素公式由 TileSet 自动处理，转换器不直接算像素。

### G.3 render_origin 的作用

- 运行时 BattleController 读取 `level_data.render_origin` 可反查任意 Godot cell 对应的原 Unity cell（debug 用）。
- 若未来接入原版事件 / NPC 坐标（Unity cell），转换时可用 `render_origin` 做一次性平移对齐。
- 相机居中（见 I 章）使用 `bounds.size * tile_size / 2` 计算，与 `render_origin` 无关。

---

## H. 风险应对

### H.1 `spr_*` 缺失 tile（研究 §8 高风险 1）

三层降级策略（按优先级）：

1. **预追查**（Phase 1）：由 `validators/sprite_missing_report.py` 在 s1 之后跑；若缺失率 > 5%，输出到 `report.md` 并要求人工确认 → 决定是否推进。
2. **占位 sprite**：s3 为 `spr_*` 注入一个 48×48 粉色 debug sprite（`atlas/placeholder.png`），custom_data `layer_role = "missing"`，保留渲染位置。
3. **禁渲染但保几何**（TopRoof 策略）：对 `TopRoof` 层内的 `spr_*`，**不写入 TileMapLayer**（跳过 `set_cell`），但几何信息进 report。因为 TopRoof 视觉可由 composite.png 叠层兜底（研究 §8 建议）。

选择规则：

- `TopRoof` / `BuildingStatic` → 策略 3
- 其他层（`Ground*`）→ 策略 2（占位），且 walkable 照常生效（E.3 已说明几何不受影响）。

### H.2 墙角 / 墙物语义（研究 §8 高风险 2）

审校流程：

1. 首次转换：`WALKABLE_WHITELIST = {}`（保守全阻挡）。
2. s1 完成后产出 `report.md`，列出每张地图所有 `WallCorner` / `WallThing` tile 的 `(sprite_name, count)` 聚合表。
3. 人工（或后续 task）按 `sprite_name` 判定可走 → 填进 `config.py::WALKABLE_WHITELIST`（按 `sprite_name` 粒度，不按 cell）。
4. 再跑一次 s6 即可刷新 `walkable_cells`，无需重打 atlas。

约束：白名单 **只对 `WallCorner` / `WallThing` 生效**；`Wall`、`_Block` 永远阻挡，不接受白名单。

### H.3 Ground 多层台阶（研究 §8 中风险 2）

- 第一版：Map_10060 的 Ground1–8 全部视作同平面，`height_level = 0`。
- 降级副作用：台阶视觉仍正确（靠 sprite 绘画），但角色可能"穿层"走上楼梯底。
- 后续扩展（不在本任务）：为每个 Ground 层单独写 `height_level = N` 到 `custom_data`，future `GridSystem` 可引入高度限制（需配合 direction-system-design 扩展）。

---

## I. 与 BattleController 接入方式

### I.1 `_paint_map()` 改造

当前（`battle_controller.gd:75`）：

```
_paint_map()                    # 从 map_layout 铺 grass terrain
grid.init_from_tilemap(terrain_layer)
```

改造后（保持向后兼容，按 `level_data.map_scene` 是否存在分支）：

```gdscript
func _paint_map() -> void:
    current_level_data.ensure_map_layout()
    if current_level_data.map_scene != null:
        _paint_map_from_scene()       # 新路径：实例化 map_scene
    else:
        _paint_map_from_terrain()     # 旧路径：保留当前逻辑（level_01/02）

func _paint_map_from_scene() -> void:
    var map_root: Node2D = current_level_data.map_scene.instantiate()
    map_root.name = "BattleMap"
    add_child(map_root)
    # UnitsContainer 需挪到 map_root.YSortRoot 下（D.2）
    var ysort_root := map_root.get_node("YSortRoot")
    units_container.reparent(ysort_root)
    # terrain_layer 字段指向 map_root.GroundBaseLayer 兜底，不再用作 walkable 数据源
    terrain_layer = map_root.get_node("GroundBaseLayer")
```

### I.2 GridSystem 新签名

新增 `init_from_level_data`（优先），保留 `init_from_tilemap`（兜底）：

```gdscript
## 新：从 LevelData.walkable_cells 初始化（研究 §7.2）
func init_from_level_data(level_data: LevelData) -> void:
    _load_terrain_library()
    tiles.clear()
    for cell in level_data.walkable_cells:
        var terrain_id: String = level_data.terrain_by_cell.get(cell, "grass")
        var terrain: TerrainTileData = _terrain_library.get(terrain_id)
        if terrain == null:
            push_warning("[GridSystem] unknown terrain '%s' at %s" % [terrain_id, cell])
            terrain = _terrain_library.get("grass")
        tiles[Vector2i(cell)] = GridTile.new(Vector2i(cell), terrain)
    print("[GridSystem] initialized %d tiles from LevelData" % tiles.size())
```

BattleController 调用切换：

```gdscript
grid = GridSystem.new()
add_child(grid)
if not current_level_data.walkable_cells.is_empty():
    grid.init_from_level_data(current_level_data)
else:
    grid.init_from_tilemap(terrain_layer)     # 向后兼容 level_01/02
```

### I.3 方向系统兼容性

引用 `direction-system-design.md`：

- 方向枚举 SE/SW/NE/NW 基于 isometric cell 的相对位移（`dx`, `dy`），与坐标系无关。
- GridSystem 的 `init_from_level_data` 不暴露 isometric 细节，方向查询照常。
- Y-sort 在 `YSortRoot` 一侧处理，角色朝向贴图由动画层决定，不受转换器影响。

### I.4 相机 / 缩放

- Unity isometric 宽高比约 2:1；Godot 菱形也 2:1。画面整体变宽，但**不变大**（格心间距 33px 横，18px 纵 vs 之前 64px 正交）。
- 当前 `camera.zoom` 维持；若后续视觉偏小，调整单次 `camera.zoom = Vector2(0.85, 0.85)` 即可，不需要改转换器。
- 相机初始位置：`(bounds.size.x * 33 / 2, bounds.size.y * 18 / 2)`，由 BattleController 读 `level_data` 后设置。

---

## 落地顺序（后续 step 参考，本任务不执行）

1. step-2-2：按本设计实现 `tools/map_importer/`，先跑通 Map_10020。
2. step-2-3：扩展 `LevelData` + `GridSystem.init_from_level_data` + `BattleController._paint_map_from_scene`。
3. step-2-4：接入方向系统（已有 plan）；人工审校 Map_10020 的 walkable / `WALKABLE_WHITELIST`。
4. step-2-5：跑 Map_10040（spr_* 降级验证）+ Map_10060（TopRoof + 多 Ground 验证）。

## 与现有代码关系总览

| 现有文件                                         | 改动类型 |
|--------------------------------------------------|----------|
| `scripts/core/level_data.gd`                     | 追加字段 + `ensure_map_layout()`（非破坏） |
| `scripts/systems/grid_system.gd`                 | 新增 `init_from_level_data`（保留旧 API） |
| `scenes/battle/battle_controller.gd`             | `_paint_map()` 分支；`UnitsContainer` reparent |
| `resources/data/levels/level_01.tres` / `level_02.tres` | **不动**（走旧路径） |
| `resources/data/tiles/*.tres`                    | **不动**（`grass` / `road` / …继续复用） |
| `wulinsh-assets/maps/**`                         | **只读** |
