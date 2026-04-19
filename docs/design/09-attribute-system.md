# BigWuXia v2 P1 — 六层属性系统

本文档定义 BigWuXia v2 P1 的属性系统重构结果。目标是把角色数值从 v1 的平铺字段切到可追溯、可扩展、可验证的六层结构，为后续装备、功法、物品、状态和数值平衡留出接口。

## 1. 设计目标

- 所有战斗值统一由 `AttributeResolver` 计算，不直接读取 `UnitData` 平铺旧字段
- 每个属性只回答一个问题，避免一个字段同时承担战斗、表现、行动多个语义
- 每个推导结果都能拆回六个来源，便于调试、录像核对和后续装备系统接入
- P1 只锁结构与占位公式，不在本阶段做平衡调优

## 2. 六层架构

| 层 | 名称 | 含义 | 当前载体 | 是否运行时变化 |
|---|---|---|---|---|
| A | 资质 | 体质、臂力、身法、悟性、福缘 | `AttributeSet` | 否 |
| B | 资源 | 生命/内力基础值与运行时 current/max | `AttributeSet` + `Unit` | 是 |
| C | 主战 | 攻击、防御、轻功、集气速度 | `AttributeResolver` | 是 |
| D | 专精 | 拳掌、刀法、剑法、医术、毒术 | `AttributeSet` | 否 |
| E | 结果 | 命中、闪避、暴击 | `AttributeResolver` | 是 |
| F | 状态 | 固有特质 + 临时 buff/debuff | `TraitData` + `StatusEffect` | 是 |

补充：`move_range` 不属于六层中的战斗推导值，P1 作为行动预算放在 `AttributeSet`，由 `Unit.get_current_mov()` 统一读取，避免继续挂在 `UnitData` 平铺字段上。

## 3. 字段分布

### A 资质

- `constitution`
- `strength`
- `agility`
- `insight`
- `fortune`

### B 资源

- `base_hp`
- `base_mp`
- `Unit.max_hp`
- `Unit.current_hp`
- `Unit.max_mp`
- `Unit.current_mp`

### C 主战

- `attack`
- `defense`
- `qinggong`
- `qi_speed`

### D 专精

- `spec_fist`
- `spec_blade`
- `spec_sword`
- `spec_medicine`
- `spec_poison`

### E 结果

- `hit`
- `dodge`
- `crit`

### F 状态

- `traits: Array[TraitData]`
- `status_effects: Array[StatusEffect]`

## 4. 占位公式

以下公式是 P1 锁定的占位值，用于验证结构、接口与 deterministic combat，不代表最终平衡。

| 属性 | 公式 |
|---|---|
| `max_hp` | `base_hp + constitution * 10 + level * 5 + equip + technique + status` |
| `max_mp` | `base_mp + constitution * 2 + insight * 3 + technique + status` |
| `attack` | `strength * 2 + weapon_specialty * 1.5 + equip + technique + status` |
| `defense` | `constitution * 1.5 + equip + technique + status` |
| `qinggong` | `agility + equip + technique + status` |
| `qi_speed` | `agility * 0.5 + qinggong * 0.3 + status` |
| `hit` | `75 + agility + weapon_specialty * 0.5 + status` |
| `dodge` | `5 + agility * 0.5 + qinggong * 0.3 + terrain_dodge_bonus + status` |
| `crit` | `5 + trait_bonus + equip + technique + status` |

P1 固定假设：

- `level = 1`
- `equip = 0`
- `technique = 0`
- `trait_bonus` 仅通过 F 层 trait/status 容器注入

## 5. 五角色占位矩阵

### A 资质矩阵

| 角色 | 体质 | 臂力 | 身法 | 悟性 | 福缘 |
|---|---|---|---|---|---|
| 徐凤年 | 7 | 8 | 8 | 6 | 9 |
| 姜泥 | 5 | 4 | 7 | 8 | 7 |
| 李淳罡 | 7 | 9 | 8 | 10 | 4 |
| enemy_soldier | 5 | 5 | 4 | 3 | 2 |
| 杨元赞 | 9 | 9 | 6 | 5 | 3 |

### D 专精矩阵

| 角色 | 拳掌 | 刀法 | 剑法 | 医术 | 毒术 |
|---|---|---|---|---|---|
| 徐凤年 | 2 | 8 | 3 | 0 | 0 |
| 姜泥 | 0 | 0 | 0 | 7 | 2 |
| 李淳罡 | 0 | 0 | 10 | 0 | 0 |
| enemy_soldier | 3 | 3 | 0 | 0 | 0 |
| 杨元赞 | 0 | 5 | 0 | 0 | 0 |

### B 资源与移动占位

| 角色 | `base_hp` | `base_mp` | `move_range` |
|---|---|---|---|
| 徐凤年 | 30 | 10 | 4 |
| 姜泥 | 25 | 15 | 5 |
| 李淳罡 | 30 | 10 | 3 |
| enemy_soldier | 25 | 5 | 3 |
| 杨元赞 | 40 | 10 | 3 |

## 6. 武器与专精映射

`AttributeResolver.get_attack()` 和 `get_hit()` 通过武器类型映射到对应专精：

| `weapon_type` | 读取专精 |
|---|---|
| `BLADE` | `spec_blade` |
| `SWORD` | `spec_sword` |
| `FIST` | `spec_fist` |
| 其他 | `0` |

P1 暂不实现长兵、暗器等额外武器映射，杨元赞先用刀法占位。

## 7. AttributeResolver 接口

P1 统一暴露以下接口：

```gdscript
static func get_max_hp(unit) -> Dictionary
static func get_max_mp(unit) -> Dictionary
static func get_attack(unit) -> Dictionary
static func get_defense(unit) -> Dictionary
static func get_qinggong(unit) -> Dictionary
static func get_qi_speed(unit) -> Dictionary
static func get_hit(unit) -> Dictionary
static func get_dodge(unit, terrain_dodge_bonus: int = 0) -> Dictionary
static func get_crit(unit) -> Dictionary
```

所有接口返回相同结构：

```gdscript
{
    "total": int,
    "sources": {
        "base": int,
        "attribute": int,
        "specialty": int,
        "equip": int,
        "technique": int,
        "status": int,
    }
}
```

## 8. 六源追溯结构

六源字段语义如下：

| key | 语义 | P1 当前实现 |
|---|---|---|
| `base` | 公式固定底值 | 已接 |
| `attribute` | A 层资质贡献 | 已接 |
| `specialty` | D 层专精贡献 | 已接 |
| `equip` | 装备加成 | 预留，P1 固定为 0 |
| `technique` | 功法/内功/招式常驻加成 | 预留，P1 固定为 0 |
| `status` | F 层特质、buff、debuff、地形临时项 | 已接 |

当前追溯策略：

- trait 和 status effect 的 `modifier_dict` 统一汇总到 `status`
- 地形闪避加成并入 `get_dodge(...).sources.status`
- 调试、测试、录像核对均以 `sources` 为权威拆解结构

## 9. 运行时流程

1. `Unit.setup()` 或 `_ready()` 读取 `unit_data.attributes`
2. `Unit` 通过 `AttributeResolver` 初始化 `max_hp` / `max_mp`
3. `CombatSystem` 在攻击时只读取 `AttributeResolver` 的结果属性与主战属性
4. `EnemyAI`、`BattleController` 通过 `Unit.get_current_mov()` 读取移动预算
5. `StatusEffect` 到回合末衰减并触发派生值刷新

## 10. P1 已知边界

- 数值仍是占位值，后续可统一调平衡
- 装备、功法、流派倾向、长兵映射仍是预留接口
- `move_range` 当前未进入六源追溯结构；如果 P2 需要地形/状态影响移动，可再升格为独立解析接口
