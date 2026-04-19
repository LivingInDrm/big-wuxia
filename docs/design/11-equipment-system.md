# 11. 装备系统

## 目录
- [1. 概览](#1-概览)
- [2. 四槽设计](#2-四槽设计)
- [3. stat_modifiers 约定](#3-stat_modifiers-约定)
- [4. weapon_type 匹配规则](#4-weapon_type-匹配规则)
- [5. 属性链路接入点](#5-属性链路接入点)
- [6. 装备变化后的资源重算](#6-装备变化后的资源重算)
- [7. 开场初装发放策略](#7-开场初装发放策略)
- [8. 已知限制](#8-已知限制)

## 1. 概览

P3 在 P1 属性六源与 P2 背包系统之上，引入 4 槽装备、装备切换 UI、以及装备对战斗属性的真实影响。当前实现聚焦装备穿脱、属性叠加、开场初装和角色面板可视化；强化、锻造和结果属性修正仍留在后续版本。

运行时存储位于 `GameState.equipped`，结构为：

```gdscript
Dictionary<String, Dictionary>
```

外层键是角色 id，内层键是装备槽位，值为 `ItemInstance` 或 `null`。核心写入口位于 [autoload/game_state.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/autoload/game_state.gd:48) 的 `equip()` / `unequip()`。

## 2. 四槽设计

P3 固定使用 4 个装备槽：

- `WEAPON`
- `ARMOR`
- `ACCESSORY_1`
- `ACCESSORY_2`

枚举定义位于 [scripts/core/item_data.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scripts/core/item_data.gd:20)。角色面板显示顺序与存储顺序一致，分别对应武器、防具、饰品 1、饰品 2。双饰品槽的设计目的是在不引入复杂职业模板的前提下，保留后续 build 空间。

## 3. stat_modifiers 约定

装备数值采用纯加法，写在 `ItemData.stat_modifiers: Dictionary` 中。P3 允许的键只有以下 6 个：

- `attack`
- `defense`
- `qinggong`
- `qi_speed`
- `max_hp`
- `max_mp`

约定含义如下：

- `attack`：攻击总值加成
- `defense`：防御总值加成
- `qinggong`：轻功总值加成
- `qi_speed`：集气速度总值加成
- `max_hp`：气血上限加成
- `max_mp`：内力上限加成

装备数据资源示例：

```gdscript
stat_modifiers = {
    "attack": 5
}
```

现阶段不接受结果属性键，例如命中、闪避、暴击、抗性等；这些结果属性修正留到 v2.1 再统一设计。

## 4. weapon_type 匹配规则

只有 `WEAPON` 槽会检查 `weapon_type`。规则如下：

- 装备资源上的 `item_data.weapon_type` 必须与角色 `unit_data.weapon_type` 对应的字符串一致
- 不匹配时，`GameState.equip()` 直接返回 `false`
- 失败不会替换原武器，也不会把物品从背包移出

具体逻辑位于 [autoload/game_state.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/autoload/game_state.gd:57) 和 [scenes/character_panel/character_panel.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scenes/character_panel/character_panel.gd:376)。角色面板在候选列表阶段就会过滤不匹配武器，`GameState` 再做一次最终防线校验。

## 5. 属性链路接入点

装备属性通过 `AttributeResolver._get_equip_modifier()` 接入六源体系，代码位于 [scripts/systems/attribute_resolver.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scripts/systems/attribute_resolver.gd:169)。

P3 当前接入到以下六条路径：

- `get_attack()`
- `get_defense()`
- `get_qinggong()`
- `get_qi_speed()`
- `get_max_hp()`
- `get_max_mp()`

每条路径都会把装备值写入结果里的 `sources.equip` 和 `sources.equipment`，因此上层 UI 或测试既可以读取旧命名，也可以读取语义更清晰的 `equipment`。

这意味着装备修正已经进入：

- 角色面板展示
- 战斗伤害公式
- 资源上限计算
- 任何依赖 `AttributeResolver` 的测试和逻辑

## 6. 装备变化后的资源重算

`GameState.equip()` / `unequip()` 成功后会发出 `equipment_changed(char_id)`，信号定义位于 [autoload/game_state.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/autoload/game_state.gd:27)。

运行中的 `Unit` 会在 [scenes/unit/unit.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scenes/unit/unit.gd:433) 监听这个信号并调用 `recalc_stats()`。P3 对 `max_hp` 的处理规则是：

```gdscript
current_hp = clampi(
    int(roundi(float(prev_current_hp) * float(max_hp) / float(prev_max_hp))),
    0,
    max_hp
)
```

行为解释：

- 如果角色原本满血，装备增加 `max_hp` 后会随上限一起涨满
- 如果角色不是满血，则保持血量比例
- 卸装导致上限下降时，同样按比例回落，并最终 clamp 到新上限
- `max_mp` 当前只做上限裁剪，不做比例涨落

这一条链路同时覆盖了角色面板内的预览值和战斗场景中的真实单位。

## 7. 开场初装发放策略

开场初装在 `GameState.reset()` 内由 `_init_starting_equipment()` 执行，配置位于 [autoload/game_state.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/autoload/game_state.gd:11)。

当前固定发放：

- 徐凤年：`iron_blade` -> `WEAPON`
- 李淳罡：`plain_sword` -> `WEAPON`
- 姜泥：`cloth_robe` -> `ARMOR`

执行步骤如下：

1. `reset()` 先创建空的 `equipped` 四槽字典
2. 把初始装备临时加入共享背包 `inventory`
3. 调用 `equip()` 把物品从 `inventory.unique_items` 挂到对应角色槽位
4. 因为 `equip()` 会移出背包，所以初始装备不会在库存里重复出现

这个策略的好处是：

- 只维护一套装备流转逻辑
- 初装、手动换装、卸装都复用同一套 API
- 测试可以直接验证“装备在槽位里且不在背包里”

## 8. 已知限制

- 强化、锻造和词条养成尚未实现，但 `ItemData.enhancement_level` 已预留
- 结果属性修正尚未开放；命中、闪避、暴击等装备词条留到 v2.1 设计
- 战斗中不可切换装备，当前只允许在选关页进入角色面板后调整
- `weapon_type` 只对武器槽生效，防具与饰品没有职业限制
