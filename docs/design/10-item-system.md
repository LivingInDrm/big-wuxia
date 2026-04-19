# 10. 物品系统

## 1. 范围与结论

P2 交付的是一条完整可玩的物品闭环：

- `ItemData` 资源定义
- `Inventory` 背包容器
- 战斗内消耗品使用
- 敌人掉落 `LootTable`
- 关卡通关奖励 `LevelData.rewards`
- 主菜单背包面板

P2 不做向后兼容；文档以当前仓库中的实际实现为准，不回写“最初设想”。

## 2. ItemData 五大类与四种消耗效果

`ItemData` 定义于 [scripts/core/item_data.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scripts/core/item_data.gd:1)。

五大类：

- `CONSUMABLE`
- `EQUIPMENT`
- `MANUAL`
- `QUEST`
- `MISC`

四种消耗效果：

- `HEAL_HP`
- `HEAL_MP`
- `BUFF`
- `DISPEL`

公共字段：

- `id / name / description / icon`
- `category`
- `stackable / max_stack / droppable`

按类别补充字段：

- 消耗品：`effect_type / effect_value / effect_duration / effect_target_stat`
- 装备：`equip_slot / stat_modifiers / enhancement_level`
- 秘籍：`teaches_specialty / teaches_level`
- 任务：`quest_flag`

实际实现说明：

- 装备的 `weapon_type` 目前没有单独字段，实际是塞在 `stat_modifiers["weapon_type"]` 里；例如 `iron_blade` 使用 `{ "attack": 5, "weapon_type": "blade" }`。
- `effect_value` 是 `float`，但执行时会转成整数。

## 3. Inventory：stackable / unique 双存储

`Inventory` 定义于 [scripts/core/inventory.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scripts/core/inventory.gd:1)，挂在 `GameState.inventory`。

当前采用双存储策略：

- `stackable_items: Dictionary<item_id, count>`
- `unique_items: Array<ItemInstance>`

规则：

- `CONSUMABLE` / `MISC` 走 `stackable_items`
- `EQUIPMENT` / `MANUAL` / `QUEST` 走 `unique_items`
- 独立物品通过 `ItemInstance.instance_id` 区分实例
- 当前无容量限制

这套结构直接对应 UI 渲染：

- 可堆叠物品在列表里显示数量 `xN`
- 非堆叠物品逐件渲染，每件都是独立条目

## 4. ItemEffectExecutor：四效果流转

执行器定义于 [scripts/systems/item_effect_executor.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scripts/systems/item_effect_executor.gd:1)。

`HEAL_HP`：

1. 校验 `item.category == CONSUMABLE`
2. 若目标已满血则返回 `false`
3. 调用 `target.heal(int(round(effect_value)))`
4. 若目标仍存活则视为成功

`HEAL_MP`：

1. 记录 `prev_mp`
2. 调用 `target.restore_mp(int(round(effect_value)))`
3. 仅当 `current_mp > prev_mp` 时成功

`BUFF`：

1. 用 `item.id` 作为 `source_id`
2. 将 `effect_target_stat -> effect_value` 组装为 `modifier_dict`
3. `effect_duration` 至少取 1 回合
4. 调用 `target.add_status_effect(...)`

`DISPEL`：

1. 遍历 `target.status_effects`
2. 当前实现把“任一修正值为负数”的状态视为 debuff
3. 过滤掉 debuff，保留其他状态
4. 若移除了负面状态则调用 `target._refresh_derived_resources()`

实际实现说明：

- `DISPEL` 当前不按 `effect_target_stat` 精确匹配某一种 debuff，而是移除所有负向状态。
- `HEAL_HP` / `HEAL_MP` 都会受当前资源上限限制。例：`jinchuang_yao` 配置为 `+30`，但本次 E2E 实际只把徐凤年从 `101/105` 回到 `105/105`，实得 `+4`。

## 5. LootTable：独立概率与可注入 RNG

掉落表定义于 [scripts/core/loot_table.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scripts/core/loot_table.gd:1)。

`entries` 语义：

- 每条 entry 独立判定，不是“总权重池抽一项”
- `weight` 语义是 `0..100` 百分比
- `min / max` 表示该条掉落数量区间

流程：

1. 遍历每个 entry
2. `weight <= 0` 或 `item_id` 为空直接跳过
3. 使用 `rng.randf() < weight / 100.0` 判定是否掉落
4. 若命中，再用 `rng.randi_range(min, max)` 生成数量

确定性：

- 生产逻辑 `roll()` 内部新建并 `randomize()` 一个 RNG
- 测试逻辑走 `roll_with_rng(rng)`，允许注入固定 seed 的 `RandomNumberGenerator`
- 因此 `test_loot.gd` 可以验证相同 seed 的序列完全一致

当前资源配置：

- 普通兵：`jinchuang_yao 50% x1`，`misc_caoyao 20% x1..2`
- 杨元赞：`lao_huang_xinwu 100% x1`，`jinchuang_yao 80% x2..3`，`jiedu_dan 30% x1`

## 6. 关卡奖励：rewards 字段与 BattleController 挂钩点

奖励字段定义于 [scripts/core/level_data.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scripts/core/level_data.gd:1)：

- `rewards: Array[Dictionary]`
- entry 结构为 `{ "item_id": String, "count": int }`

发奖挂钩点在 [scenes/battle/battle_controller.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scenes/battle/battle_controller.gd:570) 一带：

1. `_check_battle_end()` 判定胜利
2. `trigger_victory()`
3. `_grant_level_rewards()`
4. 写入 `GameState.inventory`
5. 再切到胜利场景

当前关卡奖励：

- `level_01`：`jinchuang_yao x2`，`neili_dan x1`
- `level_02`：`chunqiu_daofa x1`，`jinchuang_yao x2`

## 7. 背包 UI 架构

面板定义于 [scenes/inventory/inventory_panel.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scenes/inventory/inventory_panel.gd:1) 和 `inventory_panel.tscn`。

固定 5 个 Tab：

- 消耗品
- 装备
- 秘籍
- 任务
- 其他

渲染策略：

- 先调用 `inventory.list_by_category(category)`
- 对可堆叠条目，返回 `{ item_data, count }`，格子显示 `xN`
- 对独立物品，返回 `ItemInstance`，每件单独成格
- 右侧详情区按物品类别拼装说明

实际实现说明：

- 主菜单直接提供“背包”入口，不经过暂停菜单。
- `QUEST` 详情面板会额外显示“不可丢弃”状态。
- 装备详情面板已经会把 `stat_modifiers` 中的 `weapon_type` 按普通属性行显示出来。

## 8. 战斗内使用物品状态机

状态定义于 [scenes/battle/battle_controller.gd](/Users/xiaochunliu/VerdentProject/big-wuxia/scenes/battle/battle_controller.gd:38)：

- `IDLE`
- `UNIT_SELECTED`
- `MOVED_AWAIT_ACTION`
- `SKILL_TARGETING`
- `ITEM_TARGETING`

闭环流程：

1. 选中己方单位
2. `BattleUI` 刷新“使用物品”按钮
3. 点击“使用物品”，只展示 `CONSUMABLE`
4. 在 `ItemSelectPanel` 选择具体物品
5. `BattleController` 进入 `ITEM_TARGETING`
6. 点击友方目标单位执行效果
7. 扣减库存并结束该单位行动

取消规则：

- 在 `ITEM_TARGETING` 中，`_unhandled_input()` 只会在“点空地”时取消
- 如果点击到单位，则进入 `_on_unit_clicked()`
- 若该单位可作为目标，则执行物品
- 若该单位不是合法目标，则恢复到物品前状态

这保证了“选中物品后，点角色是使用，不是误取消”。

## 9. 10 个种子物品与数值表

当前仓库实际落地的 10 个种子物品如下：

| id | 名称 | 类别 | 可堆叠 | 数值/效果 |
| --- | --- | --- | --- | --- |
| `jinchuang_yao` | 金疮药 | CONSUMABLE | 是 | `HEAL_HP +30` |
| `jiedu_dan` | 解毒丹 | CONSUMABLE | 是 | `DISPEL poison` |
| `neili_dan` | 内力丹 | CONSUMABLE | 是 | `HEAL_MP +20` |
| `iron_blade` | 铁刀 | EQUIPMENT | 否 | `equip_slot=weapon`，`attack +5`，`weapon_type=blade` |
| `leather_armor` | 皮甲 | EQUIPMENT | 否 | `equip_slot=armor`，`defense +3` |
| `jade_pendant` | 玉佩 | EQUIPMENT | 否 | `equip_slot=accessory`，`hp +20` |
| `chunqiu_daofa` | 春秋刀法秘籍 | MANUAL | 否 | `blade +1` |
| `yishu_miji` | 医术秘籍 | MANUAL | 否 | `medicine +1` |
| `lao_huang_xinwu` | 老黄信物 | QUEST | 否 | `quest_flag=lao_huang_token`，不可丢 |
| `misc_caoyao` | 杂项草药 | MISC | 是 | 当前无主动效果 |

与最初推荐表的偏差：

- `old_huang_token` 实际 ID 为 `lao_huang_xinwu`
- `spirit_herb` 实际 ID 为 `misc_caoyao`
- `medical_manual` 实际 ID 为 `yishu_miji`
- `chun_qiu_manual` 实际 ID 为 `chunqiu_daofa`

## 10. P2 边界与进入 P3 的接口

P2 明确不做：

- 装备强化
- 交易
- 商店

这些内容留到 P3 / P4 / P5 继续展开。

进入 P3 前已经就绪的接口：

- `ItemData.equip_slot`
- `ItemData.stat_modifiers`
- `ItemData.enhancement_level`
- 背包中的 `unique_items: Array<ItemInstance>`

因此 P3 step-3-1 接装备系统时，不需要再重做物品资源层，只需要把装备穿戴、属性结算、UI 状态接上。
