# Battle HUD Spec (v2)

> 本文档为 Battle HUD 第二版（`scenes/battle/battle_hud_v2.tscn`）的前置规格。第一版
> `scenes/battle/battle_ui.gd + battle.tscn::UI` 保持不变，作为并行对照。
>
> 1.5-a 分支会加入 `bar/hp` / `bar/mp` / `bar/exp` 三个 `TextureProgressBar` 主题变体；
> 本规格的所有进度条节点预先写好 `theme_type_variation` 字段，1.5-a 合并后自动生效。

## 1. 元素清单

| # | 元素 | 说明 | 显示时机 |
| --- | --- | --- | --- |
| 1 | TurnIndicator | "第 N 天 · 玩家回合 / 敌方回合" | 始终可见 |
| 2 | UnitInfoCard | 当前行动单位头像 + 名字 + 职业 | 有己方单位被选中 / 激活时 |
| 3 | HpBarRow | 当前单位 HP 数值 + 条 | 同上 |
| 4 | MpBarRow | 当前单位 MP/内力 数值 + 条 | 同上 |
| 5 | ActionMenu | 移动 / 攻击 / 防御 / 技能 / 结束回合 | 有己方单位被激活时 |
| 6 | TargetPreviewCard | 敌方头像 + HP 条 | `MOVED_AWAIT_ACTION` 且鼠标 hover 在攻击范围内的敌人 |
| 7 | DamagePreview | 命中率 / 暴击率 / 伤害区间 | 同 6 |
| 8 | MessageLabel（保留） | 底部系统提示文字 | 始终可见，继承旧 HUD |

## 2. 布局方案

两版选一（先交最小布局，用户可按喜好切换到丰富布局）。

### 2.1 最小布局（默认）

```
┌─────────────────────────────────────────────────┐
│            [TurnIndicator：第 1 天 · 玩家回合]   │
│                                                  │
│                                                  │
│   战斗网格（BattleController 负责绘制）          │
│                                                  │
│                          ┌────────────────────┐  │
│                          │ TargetPreview      │  │
│                          │ 敌名 · HP          │  │
│                          │ 命中/暴击/伤害     │  │
│  ┌─────────────────┐     └────────────────────┘  │
│  │ UnitInfoCard    │     ┌───────────────┐       │
│  │ 徐凤年 · 刀客   │     │ 移动     [M]  │       │
│  │ HP ████ 60/100  │     │ 攻击     [A]  │       │
│  │ MP ██   8/30    │     │ 防御     [D]  │       │
│  └─────────────────┘     │ 技能     [S]  │       │
│                          │ 结束回合 [Sp] │       │
│                          └───────────────┘       │
└─────────────────────────────────────────────────┘
```

- TurnIndicator：顶部居中，`Label theme_type_variation=title`。
- UnitInfoCard + HP/MP：左下，`PanelContainer modal`，宽 ~320，高 ~200。
- ActionMenu：右下，`PanelContainer modal` + `VBoxContainer`，5 个 Button，宽 ~240。
- TargetPreview：右下 ActionMenu 上方，`PanelContainer modal`，默认 `visible=false`。

### 2.2 丰富布局（可选，用户可拖成）

```
┌─────────────────────────────────────────────────┐
│ [UnitInfoCard 左上·小]     [TurnIndicator 中]    │
│ HP/MP 在头像下                                   │
│                                                  │
│                                                  │
│                                          [Target │
│    战斗网格                              Preview │
│                                          右中]   │
│                                                  │
│                            [ActionMenu 底部居中  │
│                             横排 5 个按钮]       │
└─────────────────────────────────────────────────┘
```

## 3. 交互流程

```
 ┌─────────────┐  选己方单位   ┌──────────────────┐
 │   IDLE      │ ────────────▶ │ UNIT_SELECTED    │
 │ (无选中)    │               │ (显示 move_range)│
 └─────────────┘               └──────────────────┘
       ▲                                │
       │                                │ 点移动格
       │                                ▼
       │                       ┌──────────────────┐
       │                       │ MOVED_AWAIT_ACT  │
       │                       │ (attack_range +  │
       │                       │  ActionMenu)     │
       │                       └──────────────────┘
       │                                │
       │    结束 / 点空格       攻击目标 / 技能
       │                                ▼
       │                       ┌──────────────────┐
       └───────────────────────┤ 伤害结算 + 反馈  │
                               └──────────────────┘
```

ActionMenu 五按钮语义：

| 按钮 | 快捷键 | 可用条件 | 说明 |
| --- | --- | --- | --- |
| 移动 | M | `UNIT_SELECTED` | 点按即视觉反馈；实际通过点击网格触发（沿用现系统） |
| 攻击 | A | `MOVED_AWAIT_ACTION` | 提示选敌人 |
| 防御 | D | 永远置灰（S4 暂无防御） | 占位；S6 实装 |
| 技能 | S | 当前单位有可用技能 | 打开技能子菜单（可复用旧 BattleUI.show_skills 或在 v2 重做） |
| 结束回合 | Space | 任意状态 | `theme_type_variation=danger`，强制结束当前单位行动 |

## 4. 数据源

| 元素 | 来源 |
| --- | --- |
| TurnIndicator | `TurnManager.current_turn` + `TurnManager.current_phase` + `day_number`（字段现暂无；VM 默认 1） |
| UnitInfoCard | `Unit.unit_data.unit_name` / `unit_data.modulate`（头像底色占位） / 职业名（`WeaponTypes.Type` → 文字映射） |
| HpBarRow | `Unit.current_hp` / `Unit.max_hp` |
| MpBarRow | `Unit.current_mp` / `Unit.max_mp` |
| ActionMenu.available | `BattleController.select_state` + `Unit.skills[].is_available()` |
| TargetPreviewCard | 鼠标 hover 到的敌方 `Unit` |
| DamagePreview | `CombatSystem.calculate_attack(...)` 返回的 `{hit_chance, crit, damage}`；**注意**当前实现会消耗 LCG 种子，做真正的 preview 前需要 `preview_attack()` 无副作用包装（S6 再做，此前用 VM 占位） |

## 5. Theme 组件映射

| 元素 | Control | `theme_type_variation` |
| --- | --- | --- |
| TurnIndicator | `Label` | `title` |
| UnitInfoCard 容器 | `PanelContainer` | `modal` |
| UnitInfoCard 名字 | `Label` | `section` |
| UnitInfoCard 职业 | `Label` | `caption` |
| HP/MP Row 标签 | `Label` | `caption` |
| HP/MP Row 数值 | `Label` | `body` |
| HP Bar | `TextureProgressBar` | `bar/hp` (1.5-a；当前回退 BigBar 占位贴图) |
| MP Bar | `TextureProgressBar` | `bar/mp` (1.5-a；当前回退 BigBar 占位贴图) |
| ActionMenu 容器 | `PanelContainer` | `modal` |
| ActionMenu 普通按钮 | `Button` | `(default)` |
| ActionMenu 结束按钮 | `Button` | `danger` |
| 快捷键文字 | `Label` | `caption` |
| TargetPreview 容器 | `PanelContainer` | `modal` |
| TargetPreview HP Bar | `TextureProgressBar` | `bar/hp` |
| DamagePreview 文字 | `Label` | `caption` |

## 6. Mock 数据建议

`BattleHUDMock.mock_battle()` 默认装载：

- 己方（3）：徐凤年（刀客，HP 60/100、MP 8/30，**激活中**）、姜泥（医修，HP 80/80、MP 25/40）、李淳罡（剑圣，HP 95/100、MP 12/50）
- 敌方（2）：山贼 A（HP 24/40，正被 hover 作为攻击目标）、射手 B（HP 40/40）
- 回合：第 1 天 · 玩家回合，`turn_number=1`
- 伤害预览：命中 85% / 暴击 15% / 伤害 12-18

这些数据只在 `scenes/debug/battle_hud_preview.tscn` 注入 VM；战斗真实场景不加载。

## 7. 兼容性

- **不影响** 旧 `battle.tscn`：新骨架独立命名 `battle_hud_v2.tscn`。
- **不影响** 测试：`tests/test_theme_*.gd` 只读取主题资源，不引用 HUD 场景。
- **不影响** 1.5-a：本任务不创建 / 不修改 `bar/hp` 等 variation；只在节点上写好名字。
- **1.5-a 合并后**：进度条的占位贴图可以移除（交由 variation 提供）。

## 8. 后续任务（不属于本次前置）

- `battle_hud_v2.gd` 脚本：实例化 VM、连 signals 到节点、连 VM 到真实 BattleController
- `CombatSystem.preview_attack()`：保留 `_roll_state` 的无副作用伤害预览
- Defend 系统：`Unit.defend_stance` + 伤害结算时 `1.5x def`
- 替换 `battle.tscn::UI` → `battle_hud_v2.tscn`
