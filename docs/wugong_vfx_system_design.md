# 武功特效系统设计调研

本文只做现状调研与扩展方案设计，不包含代码实施，不跑游戏。

## 结论摘要

- 当前武功静态数据集中在 `resources/data/skills/*.tres`，由 `autoload/game_balance.gd:22-24,54-70` 统一加载，再由 `scenes/unit/unit.gd:317-328` 根据 `unit_data.skill_ids` 复制为运行时实例。
- 当前攻击范围表达方式只有 `range_type + range_value` 两个字段，其中 `range_type` 只支持 `SINGLE / LINE / CROSS / AOE` 四种枚举，范围判定逻辑硬编码在 `scripts/systems/skill_executor.gd:17-79`。
- 当前武功特效播放是技能 ID 驱动的硬编码分支：`execute_skill()` 调 `caster.play_skill()`，随后 `_spawn_skill_vfx()` 按 `skill.skill_id` 选择 `AnimatedSprite2D` 序列帧特效；清理依赖 `animation_finished` 或显式 timer。关键链路见 `scripts/systems/skill_executor.gd:82-147`、`scripts/systems/vfx.gd:11-56`、`scenes/unit/unit.gd:261-275`。
- 当前资源侧只发现 4 套序列帧 VFX：`dust / fire / explosion / heal`，未发现 `Particles2D`、`ShaderMaterial`、`projectile` 相关现成实现或素材。证据：`resources/sprites/vfx/*` 与全局搜索 `Particles2D|GPUParticles2D|CPUParticles2D|ShaderMaterial|projectile|Projectile` 结果为空。

---

## Part 1 现状摸底

### 1. 当前武功数据在哪

#### 1.1 加载入口

- `autoload/game_balance.gd:22-24` 调 `_load_dir("res://resources/data/skills", skills, "skill_id")`，说明武功资源目录是 `resources/data/skills`。
- `scenes/unit/unit.gd:317-328` 的 `_load_skills()` 会遍历 `unit_data.skill_ids`，通过 `GameBalance.get_skill_data(skill_id)` 取到模板资源，再执行 `duplicate_runtime()`。
- `scripts/core/skill_data.gd:45-48` 的 `duplicate_runtime()` 会深拷贝资源并初始化 `current_cd / remaining_uses`。

#### 1.2 武功定义文件清单

当前武功定义文件共 8 个，均位于 `resources/data/skills/`：

| 技能 ID | 名称 | 文件 | 关键行 |
|---|---|---|---|
| `chun_qiu_dao_fa` | 春秋刀法 | `resources/data/skills/chun_qiu_dao_fa.tres` | `:7-16` |
| `liang_xiu_qing_she` | 两袖青蛇 | `resources/data/skills/liang_xiu_qing_she.tres` | `:7-16` |
| `jian_qi` | 剑气 | `resources/data/skills/jian_qi.tres` | `:7-16` |
| `jian_qi_ru_lei` | 剑气·如雷 | `resources/data/skills/jian_qi_ru_lei.tres` | `:7-16` |
| `jian_kai_tian_men` | 剑开天门 | `resources/data/skills/jian_kai_tian_men.tres` | `:7-16` |
| `nei_gong_zhang` | 内功掌 | `resources/data/skills/nei_gong_zhang.tres` | `:7-16` |
| `hui_chun_shu` | 回春术 | `resources/data/skills/hui_chun_shu.tres` | `:7-16` |
| `qing_gong` | 轻功·掠影 | `resources/data/skills/qing_gong.tres` | `:7-16` |

#### 1.3 当前 SkillData 字段

`scripts/core/skill_data.gd:17-34` 定义了当前武功资源字段：

| 分类 | 字段 | 说明 | 现状 |
|---|---|---|---|
| Identity | `skill_id` | 技能 ID | 已使用 |
| Identity | `skill_name` | 显示名 | 已使用 |
| Identity | `description` | 描述 | 已使用 |
| Identity | `icon` | 图标 | 结构已定义，当前 8 个 `.tres` 都未设置 |
| Cooldown | `cooldown` | 冷却 | 已使用 |
| Cooldown | `max_uses` | 最大次数 | 已使用 |
| Range | `range_type` | 范围枚举 | 已使用 |
| Range | `range_value` | 范围参数 | 已使用 |
| Effect | `effect_type` | 效果枚举 | 已使用 |
| Effect | `power` | 数值强度 | 已使用 |
| Effect | `animation_key` | 角色动作动画键 | 已使用 |

当前 **没有** 以下字段：

- 单独的伤害字段，当前统一用 `power`，并由 `CombatSystem.calculate_attack(..., skill)` 读取。证据：`scripts/systems/combat_system.gd:41-42`。
- 射程形状 Resource 或自定义 mask。
- 任意 VFX / SFX 资源引用字段。
- Projectile 配置。
- on_cast / on_hit 回调钩子字段。

#### 1.4 每个武功当前配置字段

| 技能 | 描述 | cooldown / uses | range_type / value | effect_type | power | animation_key | 额外说明 |
|---|---|---:|---|---|---:|---|---|
| 春秋刀法 | `resources/data/skills/chun_qiu_dao_fa.tres:9` | `0 / -1` | `0 / 1` | `0` | `1.0` | `attack` | 近战单点 |
| 两袖青蛇 | `resources/data/skills/liang_xiu_qing_she.tres:9` | `2 / -1` | `2 / 2` | `0` | `0.8` | `attack` | 十字范围 |
| 剑气 | `resources/data/skills/jian_qi.tres:9` | `0 / -1` | `1 / 2` | `0` | `1.1` | `attack` | 直线 2 格 |
| 剑气·如雷 | `resources/data/skills/jian_qi_ru_lei.tres:9` | `2 / -1` | `1 / 3` | `0` | `1.5` | `attack` | 直线 3 格，贯穿 |
| 剑开天门 | `resources/data/skills/jian_kai_tian_men.tres:9` | `99 / 1` | `3 / 2` | `0` | `4.5` | `attack` | 大范围 AOE |
| 内功掌 | `resources/data/skills/nei_gong_zhang.tres:9` | `0 / -1` | `0 / 1` | `0` | `1.0` | `idle` | 近战单点，但角色动作不是 `attack` |
| 回春术 | `resources/data/skills/hui_chun_shu.tres:9` | `1 / -1` | `0 / 3` | `1` | `8.0` | `heal` | 单点治疗，允许 3 格内选目标 |
| 轻功·掠影 | `resources/data/skills/qing_gong.tres:9` | `3 / -1` | `0 / 0` | `2` | `3.0` | `run` | 自身 BUFF，施放后进入再次移动状态 |

### 2. 当前武功特效是怎么播的

#### 2.1 调用链

完整链路如下：

1. `scenes/battle/battle_controller.gd:504-529`
   - `_on_skill_button_pressed()` 取 `selected_unit.get_skill(idx)`。
   - 调 `SKILL_EXECUTOR.get_targetable_cells(...)` 计算目标格。
   - 进入 `SKILL_TARGETING` 状态并显示范围。
2. `scenes/battle/battle_controller.gd:532-545`
   - `_execute_skill()` 调 `await SKILL_EXECUTOR.execute_skill(...)`。
3. `scripts/systems/skill_executor.gd:82-90`
   - `execute_skill()` 先算 `affected_cells`。
   - `await caster.play_skill(skill.animation_key, target_world_pos)`。
   - `await _spawn_skill_vfx(caster, skill, target_pos, affected_cells)`。
4. `scenes/unit/unit.gd:261-275`
   - `play_skill()` 根据 `animation_key` 播角色动作；若无同名动画，回退到 `attack`，再不行回退到 `idle`。
5. `scripts/systems/skill_executor.gd:125-147`
   - `_spawn_skill_vfx()` 用 `match String(skill.skill_id)` 硬编码选择要播的 VFX。
6. `scripts/systems/vfx.gd:11-22`
   - `VFX.spawn_at()` 动态创建 `AnimatedSprite2D`，加到 parent 下播放。
   - 非 loop 动画在 `animation_finished` 后自动 `queue_free()`。
7. `scripts/systems/skill_executor.gd:157-164`
   - `_spawn_fire()` 对 loop 的火焰特效额外挂 `create_timer(FIRE_LIFETIME)`，到时手动 `queue_free()`。
8. `scripts/systems/vfx.gd:25-56`
   - 飘字通过 `CanvasLayer + Label + Tween` 创建，Tween 结束后释放 overlay。

#### 2.2 当前技能到特效的映射

`scripts/systems/skill_executor.gd:130-147`：

| 技能 ID | 特效 | 说明 |
|---|---|---|
| `chun_qiu_dao_fa` | `DUST_VFX` | `:131-154`，在目标格生成一次 dust |
| `nei_gong_zhang` | `DUST_VFX` | 同上 |
| `jian_qi` | `DUST_VFX` | 同上 |
| `liang_xiu_qing_she` | `FIRE_VFX` | `:133-135`，对每个受影响格播火焰 |
| `jian_qi_ru_lei` | `FIRE_VFX` | `:136-139`，沿路径逐格播火焰，带 `LINE_VFX_STEP_DELAY` |
| `jian_kai_tian_men` | `EXPLOSION_VFX + FIRE_VFX` | `:140-143`，目标中心爆炸，范围格再铺火焰 |
| `hui_chun_shu` | `HEAL_VFX` | `:144-145`，目标格上方播治疗 |
| `qing_gong` | `DUST_VFX` | `:146-147`，施法者脚下扬尘 |

#### 2.3 当前特效层能力边界

当前 `scripts/systems/vfx.gd:11-22` 的通用能力只有：

- 播一段 `AnimatedSprite2D`
- 非 loop 序列帧自动释放
- 飘字

当前 **没有**：

- 专门的 VFX 场景或 VFXPlayer 节点
- Projectile 飞行逻辑
- Particles 节点播放器
- Shader 特效接口
- 命中特效 / 施法特效 / 飞行特效的分层配置

### 3. 当前攻击范围如何判定

#### 3.1 范围枚举

`scripts/core/skill_data.gd:4-9`：

```gdscript
enum RangeType {
	SINGLE = 0,
	LINE = 1,
	CROSS = 2,
	AOE = 3,
}
```

也就是说当前是 **枚举 + 单个整数参数**，不是格子集合 Resource，也不是 shape mask。

#### 3.2 目标选择范围

`scripts/systems/skill_executor.gd:17-40`：

- `SINGLE / CROSS / AOE`
  - 当前可选目标格统一用 `Chebyshev(caster, coord) <= range_value`
  - 也就是说“可选目标区域”本质上是以施法者为中心的方形/棋王距离区域
- `LINE`
  - 从施法者向上下左右四个方向各延伸 `1..range_value`

#### 3.3 实际生效范围

`scripts/systems/skill_executor.gd:43-79`：

- `SINGLE`
  - 只影响 `target_pos` 一格
- `LINE`
  - 取施法者到 `target_pos` 的主方向
  - 从施法者开始沿该方向吃满 `range_value` 格
  - 表达的是“固定长度直线”
- `CROSS`
  - 以 `target_pos` 为中心
  - 包含中心格 + 上下左右各 `range_value` 格
- `AOE`
  - 双层 `for dx/dy`
  - 以 `target_pos` 为中心，取 `Chebyshev(target_pos, coord) <= range_value`
  - 实际上是“方形/棋王距离圆”，不是欧氏圆

#### 3.4 与普通攻击范围的区别

普通武器攻击范围不走 `SkillExecutor`，而走 `GridSystem.get_attack_range()`：

- `scripts/systems/grid_system.gd:190-207`
- 规则是 `Chebyshev` 距离 `1..weapon_range`

所以现状里存在两套范围逻辑：

- 武器攻击：`GridSystem.get_attack_range()`
- 武功攻击：`SkillExecutor.get_targetable_cells()` + `get_affected_cells()`

#### 3.5 现状限制

基于上述实现，当前 **不能直接表达**：

- 菱形（Manhattan 距离）
- 真圆形（欧氏距离）
- 锥形
- 扇形
- 任意 mask
- 带阻挡裁剪的射线
- “目标选择形状”与“生效形状”彻底解耦的复杂技能

### 4. 现有特效资源有哪些

#### 4.1 VFX 资源目录

当前 VFX 目录是 `resources/sprites/vfx/`，包含：

| 资源 | 文件 | 说明 |
|---|---|---|
| Dust SpriteFrames | `resources/sprites/vfx/dust.tres` | 默认动画，非循环，`speed=15.0`，见 `:49-76` |
| Fire SpriteFrames | `resources/sprites/vfx/fire.tres` | 默认动画，循环，`speed=12.0`，见 `:161-254` |
| Explosion SpriteFrames | `resources/sprites/vfx/explosion.tres` | 默认动画，非循环，`speed=15.0`，见 `:49-76` |
| Heal SpriteFrames | `resources/sprites/vfx/heal.tres` | 默认动画，非循环，`speed=10.0`，见 `:61-97` |

#### 4.2 底层 PNG 素材

| 类型 | 文件 |
|---|---|
| dust | `resources/sprites/vfx/dust/Dust_01.png` |
| fire | `resources/sprites/vfx/fire/Fire_01.png` |
| fire | `resources/sprites/vfx/fire/Fire_02.png` |
| fire | `resources/sprites/vfx/fire/Fire_03.png` |
| explosion | `resources/sprites/vfx/explosion/Explosion_01.png` |
| heal | `resources/sprites/vfx/heal/Heal_Effect.png` |

#### 4.3 帧数与表现

从 SpriteFrames 资源可读出：

- `dust.tres`
  - 8 个 `64x64` region，`resources/sprites/vfx/dust.tres:17-45`
  - 非循环，`resources/sprites/vfx/dust.tres:74-76`
- `fire.tres`
  - 多段 `64x64` region，总体是循环火焰序列，`resources/sprites/vfx/fire.tres:17-149,252-254`
  - 循环动画，因此当前必须靠 `skill_executor.gd:161-164` 的 timer 手动清理
- `explosion.tres`
  - 8 个 `192x192` region，`resources/sprites/vfx/explosion.tres:17-45`
  - 非循环，`resources/sprites/vfx/explosion.tres:74-76`
- `heal.tres`
  - 11 个 `192x192` region，`resources/sprites/vfx/heal.tres:17-57`
  - 非循环，`resources/sprites/vfx/heal.tres:95-97`

#### 4.4 未发现的类型

全局搜索未发现以下现成实现：

- `Particles2D / GPUParticles2D / CPUParticles2D`
- `ShaderMaterial`
- `projectile / Projectile`

这意味着“更多武功特效”如果要覆盖飞行物、扭曲刀气、粒子尾迹，需要新增基础设施与新素材。

### 5. 当前已实现的武功有哪些，各自是什么范围/特效

#### 5.1 技能与角色绑定

来自单位配置：

- `resources/data/units/xu_fengnian.tres:23-30`
  - 徐凤年：`chun_qiu_dao_fa`、`liang_xiu_qing_she`
- `resources/data/units/li_chungang.tres:21-28`
  - 李淳罡：`jian_qi`、`jian_qi_ru_lei`、`jian_kai_tian_men`
- `resources/data/units/jiang_ni.tres:22-29`
  - 姜泥：`nei_gong_zhang`、`hui_chun_shu`、`qing_gong`

#### 5.2 总表

| 技能 | 拥有者 | 当前范围表达 | 当前范围解释 | 当前特效 | 证据 |
|---|---|---|---|---|---|
| 春秋刀法 | 徐凤年 | `SINGLE,1` | 近战单格 | dust | `resources/data/skills/chun_qiu_dao_fa.tres:7-16` + `scripts/systems/skill_executor.gd:131-154` |
| 两袖青蛇 | 徐凤年 | `CROSS,2` | 目标中心十字，臂长 2 | fire 铺满受影响格 | `resources/data/skills/liang_xiu_qing_she.tres:7-16` + `scripts/systems/skill_executor.gd:65-72,133-135` |
| 剑气 | 李淳罡 | `LINE,2` | 直线 2 格 | dust | `resources/data/skills/jian_qi.tres:7-16` + `scripts/systems/skill_executor.gd:52-64,131-154` |
| 剑气·如雷 | 李淳罡 | `LINE,3` | 直线 3 格，逐格播特效 | fire + step delay | `resources/data/skills/jian_qi_ru_lei.tres:7-16` + `scripts/systems/skill_executor.gd:52-64,136-139` |
| 剑开天门 | 李淳罡 | `AOE,2` | 目标中心 Chebyshev 半径 2 | center explosion + fire | `resources/data/skills/jian_kai_tian_men.tres:7-16` + `scripts/systems/skill_executor.gd:73-78,140-143` |
| 内功掌 | 姜泥 | `SINGLE,1` | 近战单格 | dust | `resources/data/skills/nei_gong_zhang.tres:7-16` + `scripts/systems/skill_executor.gd:131-154` |
| 回春术 | 姜泥 | `SINGLE,3` | 3 格内选单体友军 | heal | `resources/data/skills/hui_chun_shu.tres:7-16` + `scripts/systems/skill_executor.gd:49-51,144-145` |
| 轻功·掠影 | 姜泥 | `SINGLE,0` | 仅自身 | dust | `resources/data/skills/qing_gong.tres:7-16` + `scripts/systems/skill_executor.gd:49-51,146-147` |

---

## Part 2 “更多武功特效”的扩展方案

以下内容是设计建议，不是现状。

### 1. 攻击范围 Shape 抽象

#### 推荐：`Resource` 抽象优先，枚举只保留在具体 Shape 内部

推荐形态：

```gdscript
# res://scripts/combat/range_shapes/range_shape_def.gd
extends Resource
class_name RangeShapeDef

func get_targetable_cells(caster: Unit, grid: GridSystem) -> Array[Vector2i]:
	return []

func get_affected_cells(caster: Unit, target: Vector2i, grid: GridSystem) -> Array[Vector2i]:
	return []
```

子类例子：

- `PointRangeShapeDef`
- `LineRangeShapeDef`
- `CrossRangeShapeDef`
- `DiamondRangeShapeDef`
- `CircleRangeShapeDef`
- `ConeRangeShapeDef`
- `MaskRangeShapeDef`

#### 为什么不推荐继续“枚举 + 参数”硬扩

现状证据表明，枚举方案已经开始把逻辑推向中心化硬编码：

- 数据层只有 `range_type + range_value`，`scripts/core/skill_data.gd:27-29`
- 逻辑层必须在 `scripts/systems/skill_executor.gd:17-79` 写 `match skill.range_type`
- 特效层又在 `scripts/systems/skill_executor.gd:130-147` 对 `skill_id` 再做一次硬编码分支

如果继续扩展成：

- `shape_type`
- `shape_length`
- `shape_radius`
- `shape_width`
- `shape_angle`
- `shape_mask`

那么 `SkillExecutor` 很快会变成一个更大的中心 switch，所有新武功都会挤到同一个文件里。

#### 为什么推荐 `Resource`

`Resource` 方案的优势：

- 编辑器友好：每种形状可以暴露自己需要的参数，不必让所有技能共享一组大而空的字段。
- 逻辑内聚：`get_targetable_cells()` / `get_affected_cells()` 直接下沉到 shape 资源本身，减少中心化 `match`。
- 易扩展：要加锥形、自定义 mask、不规则落点，不需要改已有枚举定义和大 switch。
- 易复用：多个技能可以复用同一个形状资源，或者共享同一类 shape 模板。
- 更适合和 VFX 对齐：后续 VFX 常常需要知道“路径”“中心点”“边界格”“前沿格”，shape 资源更容易额外提供这些导出信息。

#### 建议的形状参数

| 形状 | 核心参数 |
|---|---|
| 近战点 | `max_range` |
| 直线 N 格 | `length`, `cardinal_only`, `stop_on_block` |
| 十字 | `arm_length` |
| 菱形 | `radius` |
| 圆形 | `radius`, `metric = euclidean/chebyshev` |
| 锥形 | `length`, `half_angle_deg`, `direction_mode` |
| 自定义 mask | `PackedVector2Array offsets` 或 `BitMap` |

#### 兼容迁移建议

为了迁移成本可控，可以做一层适配：

- 短期保留旧字段 `range_type / range_value`
- 新字段增加 `range_shape: RangeShapeDef`
- 若 `range_shape != null`，走新系统
- 否则回退旧逻辑

这样能先迁移框架，再逐步迁移旧武功。

### 2. 特效层抽象

#### 推荐：引入统一 `VFXPlayer` 节点

现状里 `VFX` 只是静态 helper，且只支持 `AnimatedSprite2D`。建议改成战场常驻节点：

```text
BattleScene
- Grid
- Units
- VFXPlayer
  - GroundLayer
  - CastLayer
  - ProjectileLayer
  - HitLayer
  - OverlayLayer
```

#### 支持的 VFX 类型

1. Sprite 序列帧
   - `AnimatedSprite2D`
2. Particles2D
   - `GPUParticles2D`
3. Shader 变形
   - `Sprite2D` / `ColorRect` + `ShaderMaterial`
4. Projectile
   - 独立 `PackedScene`
   - 飞行结束回调命中特效

#### API 草图

```gdscript
extends Node2D
class_name VFXPlayer

func play_cast(vfx: VFXClipDef, ctx: SkillCastContext) -> Signal:
	return _play_clip(vfx, ctx, cast_layer)

func play_hit(vfx: VFXClipDef, ctx: SkillHitContext) -> Signal:
	return _play_clip(vfx, ctx, hit_layer)

func play_projectile(vfx: ProjectileVFXDef, ctx: SkillCastContext) -> Signal:
	return _spawn_projectile(vfx, ctx)

func play_sequence(defs: Array[VFXClipDef], ctx: SkillCastContext) -> void:
	for def in defs:
		await _play_clip(def, ctx, _resolve_layer(def.layer))
```

#### 配套 Resource 草图

```gdscript
extends Resource
class_name VFXClipDef

@export var kind: StringName # sprite, particles, shader, projectile
@export var layer: StringName = &"hit"
@export var follow_target: bool = false
@export var offset: Vector2 = Vector2.ZERO
@export var delay: float = 0.0
@export var lifetime: float = -1.0
@export var sprite_frames: SpriteFrames
@export var particles_scene: PackedScene
@export var shader_scene: PackedScene
@export var projectile_scene: PackedScene
```

#### 推荐的上下文数据

```gdscript
class_name SkillCastContext
var caster: Unit
var target_cell: Vector2i
var affected_cells: Array[Vector2i]
var world_from: Vector2
var world_to: Vector2
var direction: Vector2i
```

#### 为什么需要 `VFXPlayer`

基于现状，统一播放器能解决这些问题：

- 现在 VFX 绑定 `skill_id`，无法从数据侧配置
- 现在 fire 要人工 timer 清理，loop/non-loop 生命周期分散在多个地方
- 现在没有图层概念，所有节点直接加到 `parent_node`
- 现在没有 projectile/hit/cast 的阶段区分

这些问题都能从 `scripts/systems/skill_executor.gd:125-164` 和 `scripts/systems/vfx.gd:11-22` 直接看到。

### 3. 武功配置 Resource

#### 推荐结构

建议新增 `SkillDef.tres`，保留当前 `SkillData` 的核心字段，并把范围与特效接入配置：

```gdscript
extends Resource
class_name SkillDef

@export_group("Identity")
@export var skill_id: String
@export var skill_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_group("Runtime")
@export var cooldown: int = 0
@export var max_uses: int = -1

@export_group("Combat")
@export var effect_type: int = 0
@export var damage: float = 1.0
@export var healing: int = 0
@export var animation_key: StringName = &"attack"
@export var range_shape: RangeShapeDef
@export var can_target_self: bool = false
@export var can_target_ally: bool = false
@export var can_target_enemy: bool = true
@export var pierce_targets: bool = false

@export_group("VFX/SFX")
@export var vfx_on_cast: Array[VFXClipDef] = []
@export var vfx_on_travel: Array[VFXClipDef] = []
@export var vfx_on_hit: Array[VFXClipDef] = []
@export var sfx_on_cast: AudioStream
@export var sfx_on_hit: AudioStream

@export_group("Hooks")
@export var on_cast_callback: StringName
@export var on_hit_callback: StringName
```

#### 示例 `.tres`

```ini
[gd_resource type="Resource" script_class="SkillDef" format=3]

[ext_resource type="Script" path="res://scripts/core/skill_def.gd" id="1_skill"]
[ext_resource type="Resource" path="res://resources/data/range_shapes/line_3.tres" id="2_shape"]
[ext_resource type="Resource" path="res://resources/data/vfx/jian_qi_cast.tres" id="3_cast_vfx"]
[ext_resource type="Resource" path="res://resources/data/vfx/jian_qi_hit.tres" id="4_hit_vfx"]

[resource]
script = ExtResource("1_skill")
skill_id = "jian_qi"
skill_name = "剑气"
description = "直线 3 格剑气。"
cooldown = 1
max_uses = -1
effect_type = 0
damage = 1.25
animation_key = &"attack"
range_shape = ExtResource("2_shape")
can_target_enemy = true
can_target_ally = false
vfx_on_cast = [ExtResource("3_cast_vfx")]
vfx_on_hit = [ExtResource("4_hit_vfx")]
on_cast_callback = &""
on_hit_callback = &""
```

#### 回调钩子建议

这里不建议直接把 GDScript `Callable` 放进 `.tres`，更稳妥的做法是：

- 资源中记录 `StringName callback_id`
- 执行时通过 `SkillLogicRegistry` 分发

这样序列化、重命名、资源引用都更可控。

### 4. 组合示例

以下是配置表达示例，不代表现有代码已支持。

#### 4.1 雪中刀法横扫

- 范围：前方 3 格扇形或横向 3 格 sweep
- VFX：施法前摇刀光 + 前沿 sweep shader + 命中尘土

表达方式：

```ini
skill_id = "xue_zhong_dao_fa"
range_shape = preload("res://resources/data/range_shapes/cone_short_3.tres")
vfx_on_cast = [preload("res://resources/data/vfx/draw_blade_arc.tres")]
vfx_on_hit = [preload("res://resources/data/vfx/dust_hit_small.tres")]
```

适用原因：

- 锥形或扇形很难再用当前 `range_type + range_value` 表达
- sweep 过程适合 shader 或单独 sweep scene，而不是把 fire/dust 铺在每个格子上

#### 4.2 两袖青蛇直线穿透

设计目标：

- 直线 N 格
- 贯穿多个单位
- 飞行时有双剑气轨迹

表达方式：

```ini
skill_id = "liang_xiu_qing_she_v2"
range_shape = preload("res://resources/data/range_shapes/line_5_pierce.tres")
pierce_targets = true
vfx_on_cast = [preload("res://resources/data/vfx/dual_slash_cast.tres")]
vfx_on_travel = [preload("res://resources/data/vfx/dual_snake_projectile.tres")]
vfx_on_hit = [preload("res://resources/data/vfx/slash_hit_medium.tres")]
```

适用原因：

- 现状的两袖青蛇实际是 `CROSS,2`，见 `resources/data/skills/liang_xiu_qing_she.tres:12-13`
- 如果要改成“直线穿透”，需要 shape 与 projectile 一起换，不适合继续沿用现有硬编码技能 ID 特效映射

#### 4.3 剑九二十四剑式范围落点

设计目标：

- 指定区域内多落点
- 每个落点独立播剑雨 / 爆点

表达方式：

```ini
skill_id = "jian_jiu_er_shi_si"
range_shape = preload("res://resources/data/range_shapes/circle_radius_3.tres")
vfx_on_cast = [preload("res://resources/data/vfx/sword_rain_channel.tres")]
vfx_on_hit = [preload("res://resources/data/vfx/sword_rain_impact.tres")]
on_cast_callback = &"spawn_random_impacts_in_area"
```

适用原因：

- 核心不是单次命中，而是“区域内多次异步落点”
- 需要 callback/hook 参与生成二次事件

#### 4.4 回春术群疗

设计目标：

- 菱形 2 格友方治疗
- 中心治疗花纹 + 每个目标头顶治疗数值

表达方式：

```ini
skill_id = "hui_chun_zhen"
range_shape = preload("res://resources/data/range_shapes/diamond_2.tres")
can_target_ally = true
can_target_enemy = false
vfx_on_cast = [preload("res://resources/data/vfx/heal_circle_ground.tres")]
vfx_on_hit = [preload("res://resources/data/vfx/heal_bloom_small.tres")]
```

#### 4.5 轻功掠影位移

设计目标：

- 自身位移强化
- 起点残影 + 终点风尘

表达方式：

```ini
skill_id = "qing_gong_lue_ying"
range_shape = preload("res://resources/data/range_shapes/self_only.tres")
vfx_on_cast = [
	preload("res://resources/data/vfx/afterimage_spawn.tres"),
	preload("res://resources/data/vfx/footstep_dust.tres")
]
on_cast_callback = &"apply_move_buff"
```

### 5. 美术素材策略

#### 现有素材够不够

结论：**不够**。

原因基于现状证据：

- 只有 `dust / fire / explosion / heal` 四套序列帧
- 没有 projectile
- 没有粒子
- 没有 shader 贴图或屏幕扭曲资源
- 当前很多技能复用同一套 `dust` 或 `fire`，见 `scripts/systems/skill_executor.gd:130-147`

#### 建议新增素材优先级

P0，先保证“系统能看起来不像占位”：

- 刀光弧线 2 套：小横扫 / 大横扫
- 剑气直线飞行 2 套：短 / 长
- 通用命中闪 2 套：物理 / 内力
- 地面法阵 1 套：治疗/蓄力通用
- 轻功残影 1 套

P1，补足表现层次：

- Projectile 贴图与尾迹
- 剑雨落点
- 方向性 slash trail
- 命中碎片 / 火花 / 气浪

P2，拔高质感：

- 刀气扭曲 shader mask
- 剑气 heat haze / refraction 纹理
- 分元素变体：冰 / 风 / 雷

#### 可以复用的现有素材

- `dust` 可继续作为近战落地、闪避、位移扬尘基础资产
- `heal` 可继续作为治疗类基础资产
- `explosion` 可暂时作为大招命中占位
- `fire` 更适合“持续燃烧 / 灼烧区域”，不建议再继续承担所有剑气/刀气

---

## Part 3 落地路线

### Sprint 1：框架抽象

目标：

- 新增 `RangeShapeDef` 抽象
- 新增 `SkillDef` / `VFXClipDef`
- 新增 `VFXPlayer`
- 保留旧技能执行链兼容

建议交付：

- 新 range 体系能表达：点、线、十字、菱形、圆形、锥形、自定义 mask
- `SkillExecutor` 支持“优先走新配置，否则回退旧配置”
- `VFXPlayer` 能统一播放 AnimatedSprite2D / Particles / Projectile stub / Shader stub

验收标准：

- 不改旧技能资源时，当前 8 个技能行为不回归
- 新建 1 个 demo 技能资源，不改 `skill_id` 硬编码也能播出配置化特效
- `SkillExecutor` 内不再新增按 `skill_id` 分支的特效逻辑

### Sprint 2：迁移现有武功到新框架

目标：

- 把现有 8 个技能迁移为新 `SkillDef`
- 去掉 `skill_id -> VFX` 的硬编码分支

建议交付：

- 旧 `range_type / range_value` 只保留兼容，不再作为主路径
- `chun_qiu_dao_fa / liang_xiu_qing_she / jian_qi / jian_qi_ru_lei / jian_kai_tian_men / nei_gong_zhang / hui_chun_shu / qing_gong` 全部改为数据驱动

验收标准：

- `scripts/systems/skill_executor.gd` 不再包含按具体技能 ID 匹配特效的 `match String(skill.skill_id)`
- 所有现有技能的范围高亮、受影响格、伤害/治疗/BUFF 与迁移前一致
- 所有现有技能的角色动作与特效仍能正常播放并清理

### Sprint 3：新特效迭代

目标：

- 在新框架上做第一批“像武功”的表现

建议交付：

- 至少新增 3 个高辨识度技能特效
- 引入 1 套 projectile
- 引入 1 套 shader 扫光或扭曲
- 引入 1 套粒子尾迹/命中火花

验收标准：

- 典型技能至少覆盖 4 类表现形态：近战 sweep、直线 projectile、区域落点、位移残影
- 新增技能不需要再改 `SkillExecutor` 主逻辑，只通过资源配置与 hook 完成
- 美术资源目录结构、命名规范、复用策略沉淀成文档

---

## 推荐决策

### 推荐 1：范围系统使用 `Resource` 抽象，而不是继续堆枚举

原因：

- 现状的 `range_type + range_value` 已经逼出了中心大 switch
- 接下来要支持的形状明显超过当前枚举承载力
- 多形状武功与多段特效天然适合资源化组合

### 推荐 2：特效系统引入常驻 `VFXPlayer`

原因：

- 现状 `VFX.spawn_at()` 只会播 `AnimatedSprite2D`
- 生命周期和图层都在调用方零散处理
- projectile / particles / shader 都需要统一入口

### 推荐 3：技能主资源统一为 `SkillDef`

原因：

- 现状技能资源没有 VFX/SFX/Hook 接口
- 继续把特效写死到 `SkillExecutor` 不可维护
- 需要让策划和美术协作点都落在资源层

---

## 对 Manager 的建议

可以进入实施评审，但建议按以下顺序推进：

1. 先做框架，不先卷美术
2. 用 1 个新 demo 技能验证 `RangeShapeDef + VFXPlayer + SkillDef`
3. 再迁移旧 8 个技能
4. 最后投入新美术资产批量生产

如果 Manager 决定继续实施，下一步建议先进入 Sprint 1。
