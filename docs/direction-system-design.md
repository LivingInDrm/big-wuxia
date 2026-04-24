# big-wuxia 方向系统设计（正交 4 向 → isometric 4 向）

> Task Skill：`big-wuxia-iso-refactor` step-1-1  
> 范围：**只设计方向系统**，不覆盖地图 isometric 化（step-2-1 另案）。  
> 目标：把"上下左右 + flip_h"的正交方向体系升级为 **isometric 4 斜向**（NE / SE / SW / NW），依托 `wulinsh-assets` 的 **B(背) / Z(正) + 水平翻转** 素材约定。  
> 决策优先级：本文档结论 > `docs/map-import-research.md` 中的相关条目（当两者冲突时）。

---

## A. 现状分析

### A.1 当前"方向真相表"

| 维度 | 现状 | 文件:行 |
| --- | --- | --- |
| facing 类型 | `var facing: int = 1`（仅 ±1，一维） | `scenes/unit/unit.gd:35` |
| facing 初值 | `-1 if unit_data.is_enemy else 1`（敌方默认左） | `scenes/unit/unit.gd:69` |
| facing 更新 | `_update_facing(dx)`，dx 只看 x 分量 | `scenes/unit/unit.gd:294-299` |
| facing 应用 | `_apply_facing()` → `anim_sprite.flip_h = facing < 0` | `scenes/unit/unit.gd:302-304` |
| move 时朝向 | 根据 `path.back().x - current_position.x` 一次性取 dx，`.y` 完全忽略 | `scenes/unit/unit.gd:219` |
| attack 时朝向 | `signi(int(round(target_world_pos.x - position.x)))`，`.y` 忽略 | `scenes/unit/unit.gd:245, 262` |
| hurt 反馈方向 | `shake_offset = Vector2(-6.0 * float(facing), 0.0)`，水平抖 | `scenes/unit/unit.gd:380` |
| 动画集合 | `idle / run / attack / hit / die / skill`（单方向） | `resources/data/units/xu_fengnian_sprite_frames.tres:183,202,225,256,287,326` |
| SpriteFrames 素材来源 | **只用了 `B128_*`**（背面）—— `Z128_*` 全部未导入 | `xu_fengnian_sprite_frames.tres` vs `wulinsh-assets/characters/128/animations.json` 中 `B128_*` / `Z128_*` |
| 格子→像素 | `x * TILE_PX + TILE_PX/2, y * TILE_PX + TILE_PX/2`（正交 64×64） | `scenes/unit/unit.gd:82-86, 225-228`；`scenes/battle/battle_controller.gd:34, 148, 335-336` |
| GridSystem 邻格 | `_DIRS_4 := [(1,0),(-1,0),(0,1),(0,-1)]`（上下左右） | `scripts/systems/grid_system.gd:132` |
| A* 启发式 | `Manhattan = abs(dx)+abs(dy)`（明确注释"4 邻格"） | `scripts/systems/grid_system.gd:258-259` |
| 攻击范围 | `Chebyshev = max(abs(dx), abs(dy))` | `scripts/systems/grid_system.gd:192-207` |
| 点击换算 | `Vector2i(int(world.x / TILE_PX), int(world.y / TILE_PX))` | `scenes/battle/battle_controller.gd:148` |

### A.2 关键结论

1. **方向只有左右**：现在是 1D facing（±1），没有"前后"概念；y 方向移动完全不触发 facing 切换。
2. **素材已经 4 向可用**：`wulinsh-assets/characters/<id>/animations.json` 每个角色都有 `B<ID>_*` 与 `Z<ID>_*` 两套（背/正），再加 `flip_h` 就能覆盖 4 个 isometric 斜向（**素材已经够用，代码差一层**）。
3. **当前 SpriteFrames 只含 B 面**：`xu_fengnian_sprite_frames.tres` / `jiang_ni_sprite_frames.tres` / `li_chungang_sprite_frames.tres` 都只把 `B128/133/140_*` 那 6 个 `attack/die/hit/idle/run/skill` 动画打进 SpriteFrames，`Z*` 没导入 → **方向系统落地必须同步补 Z 帧**（step-1-2 烘焙任务）。
4. **GridSystem 逻辑层对方向升级基本透明**：`_DIRS_4` 的 `(dx,dy)` 语义不变，isometric 视觉下"4 邻格"仍然成立（`docs/map-import-research.md` §2.1 "`cell -> logical coord` 保持一致"）。**GridSystem 不用改，只改视觉映射层。**
5. **存在"阵营默认朝向"问题**：`facing = -1 if is_enemy else 1` 是 1D 残留；升级到 2D 方向后阵营默认要改成"朝向敌方阵营"（玩家 SW 对应屏幕左下、敌方 NE 对应屏幕右上，互相看得见脸/背）。
6. **manager-lessons P0 教训必须守住**（`~/.verdent/workspace/base/memories/manager-lessons.md` 2026-04-19 "角色朝向必须用持久 facing 状态"）：朝向必须是持久状态，仅在动作"起手"时更新，动作末端统一调 `_apply_facing()`，**禁止在 move/attack 结束时硬复位**。

---

## B. 新方向系统设计

### B.1 方向枚举

采用 **isometric 斜向四方**，命名与屏幕观感一一对应：

```gdscript
enum Dir {
    SW = 0,   # 正面朝屏幕左下（Z + 不翻转） - "面对镜头偏左"
    SE = 1,   # 正面朝屏幕右下（Z + flip_h） - "面对镜头偏右"
    NE = 2,   # 背面朝屏幕右上（B + flip_h） - "背对镜头偏右"
    NW = 3,   # 背面朝屏幕左上（B + 不翻转） - "背对镜头偏左"
}
```

视觉直觉（isometric 菱形格，屏幕 y 向下）：

```
         NW (B, no-flip)         NE (B, flip_h)
                  \              /
                   \    背面    /
                    \          /
                     [ UNIT ]
                    /          \
                   /    正面    \
                  /              \
         SW (Z, no-flip)         SE (Z, flip_h)
```

> 任务说明约定 **Z = 正面朝屏幕左下**，所以 `SW = Z + 不翻`、`SE = Z + flip_h`、`NW = B + 不翻`、`NE = B + flip_h`。

### B.2 方向 → 素材映射表

| Facing | 朝向语义     | 动画前缀 | flip_h | 阵营默认   |
| ------ | ------------ | -------- | ------ | ---------- |
| SW     | 正面 · 左下  | `z_`     | false  | 玩家默认   |
| SE     | 正面 · 右下  | `z_`     | true   | 玩家备选   |
| NE     | 背面 · 右上  | `b_`     | true   | 敌方默认   |
| NW     | 背面 · 左上  | `b_`     | false  | 敌方备选   |

> **玩家默认 SW**（面向屏幕偏左，最自然的"主角正脸"），**敌方默认 NE**（背对镜头、朝向玩家）。两侧形成 SW ↔ NE 的视觉对立。

### B.3 facing 持久状态管理（守住 P0 教训）

直接对应 `manager-lessons.md` 2026-04-19 教训的 5 条铁律：

1. **`Unit.facing` 升级为 `Facing.Dir` 枚举（int 语义），不是每次动作后重算。**
2. `_ready` 按阵营设初值：`facing = Facing.Dir.NE if is_enemy else Facing.Dir.SW`。
3. **只有三个起手点**允许更新 facing：
   - `move_along_path(path)` 起手：按"整条路径净位移"算一次目标方向。
   - `play_attack(defender_cell)` 起手：按 `(defender_cell - self_cell)` 算。
   - `play_skill(target_cell)` 起手：同攻击。
4. 所有动作末端（`idle` 回播之前）统一调 **`_apply_facing()`**，该函数只做三件事：
   - 选 `b_` / `z_` 前缀（B/Z 面）
   - 设 `anim_sprite.flip_h`
   - 重绑当前播放动画到 `<前缀>_<语义>`
   - **绝不**重设 `facing` 本身。
5. **禁止散写** `sprite.flip_h = xxx`；全局 grep 只允许出现在 `_apply_facing`。
6. **测试必测**（manager-lessons 第 5 条）：
   - 往 SW 方向移动后 `facing == Dir.SW`
   - 攻击右上目标后 `facing == Dir.NE`
   - idle 状态下 facing 保持最后值
   - 受击 / die 不改 facing

```gdscript
# scripts/core/facing.gd（伪代码）
class_name Facing
extends RefCounted

enum Dir { SW = 0, SE = 1, NE = 2, NW = 3 }

static func from_grid_delta(dx: int, dy: int, fallback: int = Dir.SW) -> int:
    # isometric 下 grid(dx,dy) → 屏幕四象限
    # 规则：dy 决定前/后（south/正面=Z，north/背面=B），dx 决定左/右（flip_h）
    if dx == 0 and dy == 0:
        return fallback
    var south := dy >= 0   # dy>=0 → 面向镜头（正面 Z）
    var east  := dx >  0   # dx>0  → 屏幕偏右（flip_h）
    if south and not east:  return Dir.SW
    if south and east:      return Dir.SE
    if not south and east:  return Dir.NE
    return Dir.NW

static func is_back(d: int) -> bool:  return d == Dir.NE or d == Dir.NW
static func flip_h(d: int)  -> bool:  return d == Dir.SE or d == Dir.NE
static func prefix(d: int)  -> String: return "b" if is_back(d) else "z"
```

> `from_grid_delta` 优先用 `dy` 判前/后，`dx == 0` 的纯横向移动会落到 SW/SE（面向镜头）而不是 NE/NW，对应"水平移动默认面对镜头"这个直觉。

### B.4 动画切换逻辑（idle/run/attack/hit/die/skill 等）

**核心约定**：逻辑层用"语义动画名"（`idle/run/attack/...`），渲染层按当前 facing 拼成实际名（`b_attack` / `z_idle` …）。

两种实现选项，推荐 **选项 A**：

#### 选项 A（推荐）：单份 SpriteFrames，内含 `b_<sem>` + `z_<sem>` 两套

```gdscript
# 伪代码
const ANIM_SEMANTIC := ["idle", "run", "attack", "hit", "die", "skill"]

func play_anim(semantic: String) -> void:
    var full := "%s_%s" % [Facing.prefix(facing), semantic]
    var sf := anim_sprite.sprite_frames
    if sf != null and sf.has_animation(full):
        anim_sprite.play(full)
    elif sf != null and sf.has_animation(semantic):
        # 回退：旧资源（enemy_soldier / yang_yuanzan）只有无前缀版本
        anim_sprite.play(semantic)

func _apply_facing() -> void:
    if anim_sprite == null: return
    anim_sprite.flip_h = Facing.flip_h(facing)
    _rebind_current_anim()   # 切前缀 b_ ↔ z_

func _rebind_current_anim() -> void:
    var cur := String(anim_sprite.animation)
    if cur == "": return
    var semantic := cur
    if cur.begins_with("b_") or cur.begins_with("z_"):
        semantic = cur.substr(2)
    var target := "%s_%s" % [Facing.prefix(facing), semantic]
    var sf := anim_sprite.sprite_frames
    if sf != null and sf.has_animation(target) and target != cur:
        var frame := anim_sprite.frame
        var progress := anim_sprite.frame_progress
        anim_sprite.play(target)
        anim_sprite.frame = frame
        anim_sprite.frame_progress = progress
    # 回退单前缀资源：不切也 OK，_apply_facing 只剩 flip_h 生效
```

**优点**：
- `UnitData.sprite_frames` 字段保持不变。
- 方向切换只改字符串，不换整套资源，无整资源 reload 代价。
- 切面时保留帧进度（`frame + frame_progress`），不闪。
- 为 step-1-2 SpriteFrames 重烘焙提供明确的命名契约。

#### 选项 B（不推荐）：两套 SpriteFrames（`sprite_frames_b` / `sprite_frames_z`）

缺点：
- `UnitData` 字段要扩成 `sprite_frames_b/z`，破坏现有资源兼容。
- 每次切面要换 `anim_sprite.sprite_frames`，帧进度丢失，闪。
- 老角色（warrior/monk 单 sheet）兼容路径复杂。

**决策：选 A。**

### B.5 网格方向 → 视觉方向（映射函数）

```gdscript
# 路径净位移朝向（终点朝向，移动起手用）
func facing_from_path(path: Array[Vector2i], from: Vector2i) -> int:
    if path.is_empty(): return facing
    var end := path[path.size() - 1]
    return Facing.from_grid_delta(end.x - from.x, end.y - from.y, facing)

# 相对目标朝向（攻击/技能起手用）
func facing_from_target(self_cell: Vector2i, target_cell: Vector2i) -> int:
    return Facing.from_grid_delta(
        target_cell.x - self_cell.x,
        target_cell.y - self_cell.y,
        facing
    )

# 逐步朝向（备选，本任务不采用，见 D.2 Q4）
func facing_from_step(prev: Vector2i, next: Vector2i) -> int:
    return Facing.from_grid_delta(next.x - prev.x, next.y - prev.y, facing)
```

### B.6 `move_along_path` 行为约定

- **起手**：按**整条路径净位移**算一次目标 facing（走曲折路仍按净方向定 run 朝向）。
- **每步 tween**：**不**改 facing（否则 Z/B 会反复切换闪烁）。
- **结束**：播 `idle`，调 `_apply_facing()`（facing 在起手已定，末端只"贴到 sprite"）。

### B.7 攻击 / 技能朝向

- `play_attack(defender_cell: Vector2i)`：**替换现有 `play_attack(target_world_pos: Vector2)`**
  - 起手：`facing = facing_from_target(current_position, defender_cell); _apply_facing()`
  - 播 `attack` → `await animation_finished` → 播 `idle` → `_apply_facing()`（不重置 facing）
- `play_skill(animation_key, target_cell)`：同上
- `battle_controller._execute_attack` 里把 `defender.position` 换成 `defender.current_position`（走 grid cell，不走 world px）

> 理由：step-2 起 TILE_PX 不再固定 64（isometric cell 像素非方形），按 grid cell 传参是唯一稳的路径。

### B.8 与 GridSystem 接口约束（isometric 下 4 邻格是否要改）

**结论：本次不改 GridSystem 逻辑。**

依据：
- `docs/map-import-research.md` §2.1 明确："`cell -> logical coord` 保持一致，A* / move range 仍是 4 邻格，只是视觉上变成菱形"。
- `_DIRS_4` 的 `(dx,dy)` 是**逻辑**邻接关系，与屏幕渲染正交/isometric 无关。
- Manhattan 启发式仍适用（4 邻格 = Manhattan）。
- Chebyshev 攻击范围在 isometric 下一样合理（`max(|dx|,|dy|)` 表达"菱形 ring"）。

**仅在 step-2-1（地图 isometric）联动修改**（不在本任务范围）：
- `battle_controller._on_cell_clicked` 里的 `Vector2i(int(world.x/TILE_PX), int(world.y/TILE_PX))` 换成 `tilemap_layer.local_to_map(local_pos)`。
- `unit.position` 的 `grid → pixel` 换成 `tilemap_layer.map_to_local(grid_pos)`。
- 这两处**只影响坐标换算，不影响 facing 语义**。

### B.9 行为决策矩阵（快速查表）

| 场景 | facing 更新时机 | 输入 | 末端 `_apply_facing` | 备注 |
| --- | --- | --- | --- | --- |
| `_ready` 初始化 | 立即 | `is_enemy` | 是 | 玩家 SW / 敌方 NE |
| `move_along_path` 起手 | 起手一次 | 整条路径净位移 | 是 | 逐步 tween 不再改 facing |
| `play_attack` 起手 | 起手 | `defender_cell - self_cell` | 是 | 参数从 world_pos 改 cell |
| `play_skill` 起手 | 起手 | `target_cell - self_cell` | 是 | 同上 |
| `take_damage` / `_play_hurt_feedback` | 不更新 | - | 是（动画切换自带前缀切换） | shake 方向按 facing 2D 化 |
| `die` | 不更新 | - | 是 | |
| idle 空闲 | 不更新 | - | 是 | 保持最后 facing |

---

## C. 影响清单（伪代码级）

### C.1 `scripts/core/facing.gd`（新增 ~20 行）

```gdscript
class_name Facing
extends RefCounted

enum Dir { SW = 0, SE = 1, NE = 2, NW = 3 }

static func from_grid_delta(dx: int, dy: int, fallback: int = Dir.SW) -> int:
    if dx == 0 and dy == 0: return fallback
    var south := dy >= 0
    var east  := dx >  0
    if south and not east:  return Dir.SW
    if south and east:      return Dir.SE
    if not south and east:  return Dir.NE
    return Dir.NW

static func is_back(d: int) -> bool:  return d == Dir.NE or d == Dir.NW
static func flip_h(d: int)  -> bool:  return d == Dir.SE or d == Dir.NE
static func prefix(d: int)  -> String: return "b" if is_back(d) else "z"
```

### C.2 `scenes/unit/unit.gd`（改动集中区 ~60 行）

要点：
- 顶部加 `const FacingScript = preload("res://scripts/core/facing.gd")`。
- `var facing: int = 1` → `var facing: int = FacingScript.Dir.SW`。
- `_ready`：`facing = FacingScript.Dir.NE if unit_data.is_enemy else FacingScript.Dir.SW`。
- 新增 `play_anim(semantic: String)`（B.4 选项 A）。
- 新增 `_rebind_current_anim()`（B.4 选项 A）。
- 把 `_update_facing(dx: int)` 升级为 `_update_facing_from_grid(dx: int, dy: int)`；旧 `_update_facing(dx)` 保留为 `_update_facing_from_grid(dx, 0)` 的薄 wrapper（**标 deprecated**，后续清理）。
- 改 `_apply_facing()`：
  ```gdscript
  func _apply_facing() -> void:
      if anim_sprite == null: return
      anim_sprite.flip_h = FacingScript.flip_h(facing)
      _rebind_current_anim()
  ```
- `move_along_path(path)`：
  ```gdscript
  var end := path[path.size() - 1]
  _update_facing_from_grid(end.x - current_position.x, end.y - current_position.y)
  play_anim("run")
  # ... 每步 tween，不改 facing ...
  play_anim("idle"); _apply_facing()
  ```
- `play_attack(defender_cell: Vector2i = Vector2i.MAX)`：
  ```gdscript
  if defender_cell != Vector2i.MAX:
      _update_facing_from_grid(
          defender_cell.x - current_position.x,
          defender_cell.y - current_position.y
      )
  play_anim("attack")
  await anim_sprite.animation_finished
  play_anim("idle"); _apply_facing()
  ```
- `play_skill`：同上。
- `_play_hurt_feedback` 的 `shake_offset`：当前是 `Vector2(-6.0 * float(facing), 0.0)`，升级成按 facing 选 2D 偏移（SW/SE 向屏幕左/右，NE/NW 反向）。细节落地在 step-1-2；**本设计文档标注"shake 需按 facing 2D 化"**。

### C.3 `scenes/battle/battle_controller.gd`（改动 ~3 行）

- `await attacker.play_attack(defender.position)` → `await attacker.play_attack(defender.current_position)`（传 grid cell，不是 world px）。
- `play_skill` 调用处（如果有）同款调整。
- 其余 TILE_PX 坐标换算**本任务不动**，留给 step-2-1。

### C.4 `scripts/systems/grid_system.gd`（**不改**）

确认无改动。`_DIRS_4` / Manhattan / Chebyshev 在 isometric 视觉下语义保持（依据 §B.8）。

### C.5 SpriteFrames 资源（3 份，step-1-2 烘焙）

`resources/data/units/{xu_fengnian,li_chungang,jiang_ni}_sprite_frames.tres`：

- 现状：6 个动画（`attack/die/hit/idle/run/skill`），全部来自 B 面。
- 目标：每份含 12 个动画：
  ```
  b_attack / b_die / b_hit / b_idle / b_run / b_skill   ← 从 B<ID>_* 烘
  z_attack / z_die / z_hit / z_idle / z_run / z_skill   ← 从 Z<ID>_* 烘
  ```
- 做法：
  1. 现有 6 个 `attack/die/hit/idle/run/skill` **改名加 `b_` 前缀**。
  2. 按 `wulinsh-assets/characters/<id>/animations.json` 里 `Z<ID>_*` 帧列表 + `sprites.json` 的 region，追加 6 个 `z_` 前缀动画。
- **step-1-2 的实际烘焙任务**，本任务只负责"设计层约定命名"。

### C.6 `UnitData`（可选，本任务不改）

考虑过加 `default_facing: int` 让每个 UnitData 指定初始朝向，但"玩家 SW / 敌方 NE"阵营默认已足够、且关卡内双方阵营方向统一，**本任务不加该字段**，留作未决（D.2 Q5）。

---

## D. 风险 + 未决

### D.1 风险（已识别）

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| `_rebind_current_anim` 切前缀时帧进度不对齐 | 动画闪一下 | 记录 `frame + frame_progress` 后重播；B/Z 同语义动画帧数一致（`characters/128/animations.json` 里 B128/Z128 所有同名动画帧数/fps 完全对齐），风险低 |
| `enemy_soldier` / `yang_yuanzan` 没 B/Z 两套素材 | 混编时老单位无方向语义 | `play_anim` 回退分支支持"无前缀"老动画；老单位 `facing` 仍维护，`_apply_facing` 只管 `flip_h` 不切前缀 |
| 玩家/敌方默认朝向在"同阵营同侧"关卡反直觉 | 视觉不对 | 允许关卡在 `LevelData` / `UnitData` 覆盖默认（留到 step-4 关卡脚本） |
| 逐步切 facing 让用户感觉"闪" | UX 问题 | 本任务采用"起手定一次、全程不变"策略，规避该风险 |
| `play_attack` 签名从 `target_world_pos: Vector2` → `defender_cell: Vector2i` 是破坏性修改 | `battle_controller` 要同步改；测试/E2E 可能调用 | 影响面清单已列 C.3；必要时保留旧签名重载（`play_attack(target_world_pos: Vector2)`）做兼容层，内部转换 `world → cell` |

### D.2 未决问题（manager 拍板）

1. **Q1：Z 动画数据源怎么补？**  
   现状：`xu_fengnian_sprite_frames.tres` 只有 `B128_*`。  
   选项 a）写一次性 Godot `EditorScript`，读 `characters/<id>/animations.json` 的 `Z<ID>_*` 帧列表 + `sprites.json` region，自动往 SpriteFrames 追加 `z_*` 动画。  
   选项 b）手工在 Godot 编辑器里点。  
   **推荐 a**，但实际烘焙归 step-1-2 单独立项。

2. **Q2：`sprite_offset` 要不要按 4 方向各自调？**  
   现状：`UnitData.sprite_offset` 是单一 `Vector2` 值。  
   B/Z 帧的像素 bbox 在 `sprites.json` 里普遍一致（60-85 px 级），可能单值 offset 够用；但 isometric 菱形格中心 vs 角色脚底锚点前后面可能差 ~5px。  
   **推荐**：先上单值 offset，若 step-1-2 实测发现 Z 面"脚在格外"，再扩成 `Dictionary[Facing.Dir → Vector2]`。本任务不加字段，`UnitData` 注释里写"保留未来扩展"。

3. **Q3：`enemy_soldier` / `yang_yuanzan` 仍用 warrior/monk 老 sprite，过渡策略？**  
   选项 a）只给有 4 向素材的角色（徐/李/姜）启用 B/Z 切换，老单位走"facing 维护但不切前缀"的兼容路径。`play_anim` 回退分支已在 §B.4 写好。  
   选项 b）给 warrior/monk 临时绑一套"`b_` 前缀指向原动画、`z_` 前缀也指向原动画"的 SpriteFrames，让 `_facing_prefix` 永远命中。  
   **推荐 a**（改动最小，老单位视觉退化到"只 flip_h、不切前后"，可接受）。

4. **Q4：逐步朝向 vs 终点朝向？**  
   当前设计：**整条路径一次定向**（§B.6）。  
   若未来关卡有"L 形走位"且用户希望沿途看到朝向切换，再改成"每步切 facing"。**本任务选终点朝向**。

5. **Q5：`LevelData` / `UnitData` 是否支持覆盖阵营默认朝向？**  
   本任务**不加字段**。若关卡设计需要（如"玩家从右上出发朝 SW 走"），再扩 `UnitData.default_facing: Facing.Dir` 或 `LevelData.unit_defaults[unit_id].facing`。留作 step-4 关卡设计联动项。

---

## E. 交付 / DoD

### E.1 本任务（step-1-1）交付

- [x] `docs/direction-system-design.md` 本文档（A/B/C/D 全部章节）。
- [x] 明确 Facing 枚举（§B.1）+ 方向↔素材映射表（§B.2）。
- [x] facing 持久状态管理 5 条铁律（§B.3，对齐 manager-lessons P0）。
- [x] `Unit.gd` / `battle_controller.gd` / SpriteFrames 改动清单（§C，伪代码级）。
- [x] GridSystem **明确列为"不改"** 并给依据（§B.8）。
- [x] 风险 + 未决 5 项（§D）。

### E.2 落地步骤 → 目标 → 验证（后续 step 引用）

| 设计步骤 | 目标文件 | 验证（落地后） |
| --- | --- | --- |
| 新增 Facing 枚举 | `scripts/core/facing.gd` | 单元：4 方向映射对 16 组 dx/dy 组合 |
| Unit facing 升级 | `scenes/unit/unit.gd` | 往 SW/NE 移动后 facing 正确 |
| 动画前缀切换 | `scenes/unit/unit.gd` | 切面后帧进度不跳；旧单位回退可用 |
| 攻击 API 改 cell | `scenes/battle/battle_controller.gd` | 攻击右上单位后 facing == Dir.NE |
| SpriteFrames 补 Z | `resources/data/units/{xu_fengnian,li_chungang,jiang_ni}_sprite_frames.tres` | 12 个动画全在；播 `z_idle` 能渲染 |
| GridSystem 不动 | `scripts/systems/grid_system.gd` | 旧战斗流程 grep 回归 + 运行回归 |

### E.3 step-1-1 不做

- 不改 GridSystem（§B.8）。
- 不改任何坐标换算（TILE_PX、`world → cell`），留给 step-2-1。
- 不烘焙 SpriteFrames 的 Z 面动画，留给 step-1-2。
- 不做 shake 2D 化细节，留给 step-1-2 实装时落地。

---

## 附录：参考

- `~/.verdent/skills/godot-dev/SKILL.md` — P0 Unit facing 持久状态规则
- `~/.verdent/workspace/base/memories/manager-lessons.md` 2026-04-19 "角色朝向必须用持久 facing 状态"
- `docs/map-import-research.md` §2.1 / §5.2 / §6 — isometric 坐标系 + LevelData 扩展
- `wulinsh-assets/ASSET_CATALOG.md` §1 — B/Z 动画前缀解读
- `wulinsh-assets/characters/128/animations.json` — B128 / Z128 动画帧对齐证据
