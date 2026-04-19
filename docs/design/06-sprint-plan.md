# BigWuXia — Sprint 计划文档

本文档定义 BigWuXia MVP 的 6 个 Sprint 详细计划，每个 Sprint 包含：目标、范围、不做、验收标准、依赖、工作量估算。

## Sprint 总览

| Sprint | 一句话目标 | 工作量 | 关键产出 | 状态 |
|---|---|---|---|
| S1 | 项目骨架 + 主菜单 + 武侠 UI 基调 | 1 天 | project.godot + MainMenu + 字体/背景导入 | 已完成 |
| S2 | 网格地图 + TileMapLayer + GridSystem | 1-2 天 | Battle 场景 + 地形渲染 + 逻辑网格 | 已完成 |
| S3 | 单位系统 + 回合切换 | 2 天 | Unit 场景 + TurnManager + 3 角色 + 敌人 | 已完成 |
| S4 | 移动/攻击范围 + 基础战斗 | 2 天 | BFS 移动 + 普攻 + 伤害结算 + 死亡 | 已完成 |
| S5 | 技能系统 + 地形/克制 + 胜负判定 | 2 天 | 6 个技能 + 地形修正 + Victory/Defeat | 已完成 |
| S6 | 2 关卡 + polish（字体/特效）+ E2E 通关 | 2 天 | LevelData + 双关卡 + 选关流程 + 截图化 E2E | 已完成 |

**总工作量**: 10-12 天（按每天 6-8 小时工作计算）

**GATE 规则**: 每个 Sprint 的 DoD 通过（E2E 验证子任务 PASS）才能进下一个 Sprint。

---

## Sprint 1: 项目骨架 + 主菜单 + 武侠 UI 基调

### S1.1 目标

搭建 Godot 项目骨架，实现主菜单场景，确定武侠 UI 风格基调（羊皮纸/毛笔字/山水背景）。

### S1.2 范围

1. **创建 Godot 项目**：
   - 初始化 project.godot（config_version=5）
   - 配置分辨率 1366×768（窗口模式）
   - 配置 .gitignore（忽略 .godot/ .import/）
2. **目录结构**：
   - 创建 scenes/ scripts/ resources/ autoload/ tests/ tools/ 目录
   - 按 [02-architecture.md](./02-architecture.md) §1.1 标准结构
3. **Autoload 配置**：
   - 创建 GameState.gd / GameBalance.gd / SceneManager.gd / AudioBus.gd
   - 在 project.godot 中注册 Autoload
4. **主菜单场景**（MainMenu.tscn）：
   - 山水背景（AI 生成，1366×768）
   - 大标题"雪中悍刀行"（思源宋体 Heavy 72pt）
   - 3 个按钮："开始游戏"/"教程"/"退出"（Tiny Swords BigBlueButton + 毛笔字）
   - 按钮点击 → 调用 SceneManager.change_scene_to_file()
5. **字体导入**：
   - 下载思源宋体（Noto Serif CJK SC Heavy/Regular/Bold）
   - 导入到 resources/fonts/，配置 MSDF + Oversampling 2.0
6. **背景资产生成**：
   - 用 MidJourney/Stable Diffusion 生成主菜单背景（雪山/北凉城/水墨山水）
   - 导入到 resources/sprites/backgrounds/

### S1.3 不做

- 角色选择场景（S1 只做主菜单）
- 战斗场景（S2 开始）
- 音效/BGM（S6 polish）

### S1.4 验收标准

1. **Smoke test 通过**：
   ```bash
   godot --headless --path /Users/xiaochunliu/VerdentProject/big-wuxia --quit
   ```
   无 `push_error` 日志
2. **主菜单可运行**：
   - 启动游戏，显示主菜单
   - 点击"开始游戏"，跳转到占位场景（CharacterSelect.tscn，空白）
   - 点击"教程"，跳转到占位场景（Battle.tscn，空白）
   - 点击"退出"，游戏正常关闭
3. **UI 风格验收**：
   - screenshot_harness 截取主菜单 PNG
   - 人工检查：山水背景 + 思源宋体大标题 + 羊皮纸按钮，风格协调
4. **GDScript 类型注解**：
   - 所有 .gd 文件有 `class_name` 和类型注解（函数参数/返回值）

### S1.5 依赖

无（首个 Sprint）

### S1.6 工作量估算

**1 天**（6-8 小时）

**任务拆分**：
- 创建项目 + 目录结构：1 小时
- Autoload 配置：1 小时
- 主菜单场景 + 脚本：2 小时
- 字体导入 + 配置：1 小时
- AI 生成背景 + 导入：2 小时
- 验收测试：1 小时

---

## Sprint 2: 网格地图 + TileMapLayer + GridSystem

### S2.1 目标

实现战斗场景的网格地图渲染（TileMapLayer）和逻辑网格系统（GridSystem），能显示 12×10 地图 + 查询地形数据。

### S2.2 范围

1. **Battle 场景**（Battle.tscn）：
   - 创建 Node2D 根节点
   - 添加 TileMapLayer 节点（地形层）
   - 添加 TileMapLayer 节点（高亮层，用于移动/攻击范围）
   - 添加 Camera2D（固定视角，MVP 不做拖拽）
   - 添加 CanvasLayer（UI 层，占位）
2. **TileSet 配置**：
   - 导入 Tiny Swords `Terrain/Tileset/Tilemap_color1.png` 到 resources/sprites/terrain/
   - 创建 TileSet 资源（tile_size=64×64，autotile 启用）
   - 添加 Custom Data Layer: `tile_id`（String）
   - 逐个 tile 设置 `tile_id`（grass/forest/mountain/water/road）
   - 保存为 resources/data/terrain/main_tileset.tres
3. **TileData Resource**（scripts/core/tile_data.gd）：
   - 创建 TileData 类（movement_cost / dodge_bonus / is_obstacle）
   - 创建 6 个 .tres 实例（grass/bush/forest/mountain/water/road）
4. **GridSystem**（scripts/systems/grid_system.gd）：
   - 实现 §4.1-4.3 的接口（get_tile / is_walkable / is_occupied）
   - 实现 `_init_tiles_from_tilemap()`（从 TileMapLayer 读取 tile_id 初始化 tiles Dictionary）
   - 暂时不实现 BFS/A*（S4 实现）
5. **BattleController 占位**（scenes/battle/battle_controller.gd）：
   - 创建 Node 脚本，引用 GridSystem / TurnManager（占位）
   - `_ready()` 时调用 GridSystem._init_tiles_from_tilemap()
6. **测试地图绘制**：
   - 在 TileMapLayer 中手动绘制 12×10 地图（教程关 8×8 地图）
   - 包含平地/林地/山/水混合

### S2.3 不做

- 单位渲染（S3）
- 移动/攻击范围（S4）
- UI（S3 开始）

### S2.4 验收标准

1. **地形渲染正确**：
   - screenshot_harness 截取 Battle 场景 PNG（1366×768）
   ```bash
   godot --path . --script tools/screenshot_harness.gd -- \
         res://scenes/battle/battle.tscn /tmp/s2_battle.png 60 1366x768
   ```
   - 人工检查：12×10 地图清晰，无 seam（缝隙），平地/林地/山/水视觉区分明显
2. **GridSystem 初始化正确**：
   - GUT 单元测试：
   ```gdscript
   func test_grid_system_init():
       var grid := GridSystem.new()
       grid.grid_size = Vector2i(12, 10)
       # 模拟从 TileMapLayer 读取
       grid._init_tiles_from_tilemap()
       assert_eq(grid.tiles.size(), 120)  # 12×10
       assert_not_null(grid.get_tile(Vector2i(0, 0)))
       assert_eq(grid.get_tile(Vector2i(0, 0)).tile_id, "grass")
   ```
3. **Smoke test 通过**：
   ```bash
   godot --headless --path . res://scenes/battle/battle.tscn --quit
   ```
   无 `push_error` 日志

### S2.5 依赖

- S1 完成（项目骨架 + Autoload）

### S2.6 工作量估算

**1-2 天**（8-12 小时）

**任务拆分**：
- Battle 场景创建：1 小时
- TileSet 配置（导入 + 设置 tile_id）：3 小时
- TileData Resource 创建：1 小时
- GridSystem 实现（不含 BFS/A*）：3 小时
- 测试地图绘制：2 小时
- 验收测试：2 小时

---

## Sprint 3: 单位系统 + 回合切换

### S3.1 目标

实现单位场景（Unit.tscn）、3 个玩家角色 + 敌方单位，回合管理（TurnManager），能按回合轮流 Idle 动画播放（无移动/攻击）。

### S3.2 范围

1. **Unit 场景**（scenes/unit/unit.tscn）：
   - AnimatedSprite2D（SpriteFrames 预设）
   - HealthBar（ProgressBar + HPLabel）
   - SelectIndicator（Sprite2D，圆圈光环，默认隐藏）
   - ActedIndicator（Sprite2D，半透明遮罩，默认隐藏）
   - Area2D + CollisionShape2D（鼠标点击检测）
2. **Unit 脚本**（scenes/unit/unit.gd）：
   - 属性：`unit_data: UnitData`, `current_hp`, `current_position`, `acted`
   - 方法：`_ready()` 初始化（读取 UnitData，设置 HP 条）
   - 信号：`unit_selected`, `unit_died`
   - 暂时不实现 move_to / attack / use_skill（S4）
3. **UnitData Resource**（scripts/core/unit_data.gd）：
   - 创建 UnitData 类（见 [02-architecture.md](./02-architecture.md) §4.1）
   - 创建 4 个 .tres 实例：xu_fengnian / jiang_ni / li_chungang / enemy_soldier
4. **SpriteFrames 预设**：
   - 创建 warrior_sprite_frames.tres（Warrior Idle/Run/Attack，8f/6f/4f）
   - 创建 monk_sprite_frames.tres（Monk Idle/Run/Heal，6f/4f/11f）
   - 徐凤年/李淳罡/敌方普通兵共用 warrior_sprite_frames.tres（用 modulate 改颜色：Blue/Purple/Red）
5. **TurnManager**（scripts/systems/turn_manager.gd）：
   - 实现 §5 回合状态机（Phase enum + 状态转换）
   - 实现 start_battle() / _start_player_phase() / _start_enemy_phase() / _next_turn()
   - 信号：turn_started / phase_changed
6. **BattleController 集成**：
   - 在 Battle.tscn 中添加 UnitsContainer（Node2D）
   - 在 UnitsContainer 下手动放置 3 个玩家单位 + 3 个敌方单位（占位，教程关配置）
   - BattleController._ready() 连接 TurnManager 信号
   - 实现简单的回合切换逻辑（玩家阶段 → 敌方阶段 → 新回合，UI 显示"回合 N"）
7. **BattleUI 占位**（scenes/battle/battle_ui.gd）：
   - 创建 CanvasLayer + Control
   - 添加 TurnLabel（Label，显示"回合 1 - 玩家阶段"）
   - 添加 MessageLabel（Label，显示消息提示）

### S3.3 不做

- 移动/攻击（S4）
- 技能（S5）
- AI 行为（S4）

### S3.4 验收标准

1. **单位渲染正确**：
   - screenshot_harness 截取 Battle 场景 PNG
   - 人工检查：3 个玩家单位（徐凤年蓝/姜泥蓝/李淳罡紫）+ 3 个敌方单位（红）清晰显示
   - Idle 动画流畅播放（8fps）
2. **回合切换正确**：
   - E2E 测试（GDScript 输入注入）：
   ```gdscript
   func test_turn_cycle():
       # 进入 Battle 场景
       get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
       await get_tree().process_frame
       var controller := get_node("/root/Battle/BattleController")
       var turn_mgr := controller.turn_manager
       
       assert_eq(turn_mgr.current_phase, TurnManager.Phase.PLAYER_SELECT)
       assert_eq(turn_mgr.current_turn, 1)
       
       # 模拟玩家阶段结束
       turn_mgr._start_enemy_phase()
       await get_tree().process_frame
       assert_eq(turn_mgr.current_phase, TurnManager.Phase.ENEMY_TURN)
       
       # 模拟敌方阶段结束
       turn_mgr._next_turn()
       await get_tree().process_frame
       assert_eq(turn_mgr.current_turn, 2)
       assert_eq(turn_mgr.current_phase, TurnManager.Phase.PLAYER_SELECT)
   ```
3. **UI 显示正确**：
   - TurnLabel 显示"回合 1 - 玩家阶段"
   - 回合切换时更新为"回合 1 - 敌方阶段" → "回合 2 - 玩家阶段"
4. **血条显示正确**：
   - 单位 HP 条显示"28/28"（徐凤年）
   - 颜色正确（绿色 HP > 50%，黄色 HP 20-50%，红色 HP < 20%）

### S3.5 依赖

- S2 完成（Battle 场景 + GridSystem）

### S3.6 工作量估算

**2 天**（12-16 小时）

**任务拆分**：
- Unit 场景 + 脚本：3 小时
- UnitData Resource + 实例创建：2 小时
- SpriteFrames 预设（导入 sprite + 配置动画）：3 小时
- TurnManager 实现：3 小时
- BattleController 集成 + UI 占位：3 小时
- 验收测试：2 小时

---

## Sprint 4: 移动/攻击范围 + 基础战斗

### S4.1 目标

实现移动范围计算（BFS）、攻击范围计算、单位移动（Tween）、普攻、伤害结算、死亡。

### S4.2 范围

1. **GridSystem 算法实现**：
   - 实现 get_move_range()（Dijkstra/BFS with movement cost，见 [04-tech-stack.md](./04-tech-stack.md) §4.1）
   - 实现 get_attack_range()（Chebyshev 距离环形，§4.2）
   - 实现 find_path()（A* 寻路，§4.3）
2. **高亮层渲染**（TileMapLayer overlay）：
   - 移动范围：绿色半透明 tile
   - 攻击范围：红色半透明 tile
   - BattleController 接收 unit_selected 信号 → 调用 GridSystem.get_move_range() → 渲染绿色高亮
3. **Unit 移动实现**（unit.gd）：
   - 实现 move_to(target: Vector2i)：
     - 调用 GridSystem.find_path() 获取路径
     - 用 Tween 逐格移动（每格 0.15s）
     - 播放 Run 动画
     - 移动结束后播放 Idle 动画，发射 unit_moved 信号
4. **输入处理**（battle_controller.gd）：
   - 鼠标点击单位 → select_unit() → 显示移动范围
   - 鼠标点击移动范围内的格子 → move_to() → 完成移动
   - 移动后显示行动面板（攻击/待机按钮，技能 S5 实现）
5. **DamageCalculator 实现**（scripts/systems/damage_calculator.gd）：
   - 实现 calculate_damage() 静态方法（见 [02-architecture.md](./02-architecture.md) §7.3）
   - 命中判定（95% − 地形闪避）
   - 暴击判定（10%）
   - 武器克制（刀 > 剑 > 内功 > 刀，×1.25）
   - 伤害公式：max(1, ATK×k − DEF)
6. **Unit 攻击实现**（unit.gd）：
   - 实现 attack(target: Unit)：
     - 播放 Attack 动画
     - 调用 DamageCalculator.calculate_damage()
     - 显示伤害浮字（DamageLabel，向上飘 + fade out）
     - target.take_damage(damage)
     - 如果 target.hp <= 0，target.die()
7. **Unit 死亡实现**（unit.gd）：
   - 实现 die()：
     - 播放 fade out Tween（modulate.a = 0）
     - 发射 unit_died 信号
     - queue_free()
8. **伤害浮字**（scripts/components/damage_label.gd）：
   - 创建 Label 节点，动态实例化
   - Tween 动画：position.y −= 30，modulate.a = 0（1 秒）
   - 暴击用橙色，普通用白色

### S4.3 不做

- 技能（S5）
- 地形修正（S5 实现，S4 只做伤害公式）
- AI 行为（S4 只实现玩家操作，敌方回合跳过）

### S4.4 验收标准

1. **移动范围正确**：
   - GUT 单元测试：
   ```gdscript
   func test_get_move_range():
       var grid := GridSystem.new()
       grid.grid_size = Vector2i(8, 8)
       # 全平地（cost=1）
       for x in range(8):
           for y in range(8):
               grid.tiles[Vector2i(x, y)] = TileData.new()
               grid.tiles[Vector2i(x, y)].movement_cost = 1.0
       
       var start := Vector2i(4, 4)
       var mov := 3
       var range := grid.get_move_range(start, mov)
       
       # 应包含 (4,4) 周围 3 格内的所有格子
       assert_has(range, Vector2i(4, 1))  # 上 3 格
       assert_has(range, Vector2i(7, 4))  # 右 3 格
       assert_has(range, Vector2i(4, 7))  # 下 3 格
       assert_has(range, Vector2i(1, 4))  # 左 3 格
   ```
2. **移动动画流畅**：
   - E2E 测试（输入注入 + screenshot_harness）：
   ```gdscript
   # 点击徐凤年
   var click1 := InputEventMouseButton.new()
   click1.position = _grid_to_screen(Vector2i(0, 6))  # 徐凤年位置
   click1.pressed = true
   Input.parse_input_event(click1)
   await get_tree().process_frame
   
   # 截图验证移动范围高亮
   screenshot_harness("res://scenes/battle/battle.tscn", "/tmp/s4_move_range.png", 30)
   # 人工检查：绿色高亮范围正确
   
   # 点击目标格
   var click2 := InputEventMouseButton.new()
   click2.position = _grid_to_screen(Vector2i(3, 6))
   click2.pressed = true
   Input.parse_input_event(click2)
   await get_tree().create_timer(1.0).timeout  # 等待移动动画
   
   # 截图验证移动完成
   screenshot_harness("res://scenes/battle/battle.tscn", "/tmp/s4_move_done.png", 30)
   # 人工检查：徐凤年移动到 (3, 6)
   ```
3. **伤害公式正确**：
   - GUT 单元测试：
   ```gdscript
   func test_damage_calculation():
       var attacker := Unit.new()
       attacker.unit_data = UnitData.new()
       attacker.unit_data.atk = 10
       attacker.unit_data.weapon_type = WeaponType.BLADE
       
       var defender := Unit.new()
       defender.unit_data = UnitData.new()
       defender.unit_data.def = 3
       defender.unit_data.weapon_type = WeaponType.SWORD
       defender.current_hp = 20
       
       var skill := SkillData.new()
       skill.damage_multiplier = 1.0
       
       var result := DamageCalculator.calculate_damage(attacker, defender, skill)
       
       # 刀克剑，×1.25
       # 伤害 = (10 × 1.0 × 1.25) − 3 = 12.5 − 3 = 9（向下取整）
       assert_eq(result.damage, 9)
   ```
4. **攻击流程正确**：
   - E2E 测试（输入注入）：
   ```gdscript
   # 移动徐凤年到敌人旁边
   # ...
   # 点击"攻击"按钮
   # 点击敌人
   # 等待攻击动画
   # 检查敌人 HP 减少
   assert_lt(enemy.current_hp, enemy.unit_data.max_hp)
   ```

### S4.5 依赖

- S3 完成（Unit 系统 + TurnManager）

### S4.6 工作量估算

**2 天**（12-16 小时）

**任务拆分**：
- GridSystem BFS/A* 实现：4 小时
- 高亮层渲染：2 小时
- Unit 移动 Tween：2 小时
- DamageCalculator 实现：2 小时
- Unit 攻击 + 死亡：2 小时
- 伤害浮字：1 小时
- 验收测试：3 小时

---

## Sprint 5: 技能系统 + 地形/克制 + 胜负判定

### S5.1 目标

实现 6 个技能（徐凤年×2 / 姜泥×3 / 李淳罡×3）、地形修正、武器克制、胜负判定、Victory/Defeat 界面。

### S5.2 范围

1. **SkillData Resource**（scripts/core/skill_data.gd）：
   - 创建 SkillData 类（见 [02-architecture.md](./02-architecture.md) §4.2）
   - 创建 6 个 .tres 实例：
     - chun_qiu_dao_fa.tres（徐凤年普攻）
     - liang_xiu_qing_she.tres（徐凤年技能，十字 AOE）
     - nei_gong_zhang.tres（姜泥普攻）
     - hui_chun_shu.tres（姜泥治疗）
     - qing_gong.tres（姜泥轻功）
     - jian_qi.tres（李淳罡普攻+）
     - jian_qi_ru_lei.tres（李淳罡技能，直线 AOE）
     - jian_kai_tian_men.tres（李淳罡大招，整局 1 次）
2. **SkillExecutor 实现**（scripts/systems/skill_executor.gd）：
   - 实现 execute_skill() 静态方法：
     - 根据 skill.range_type（SINGLE/LINE/CROSS/AOE）计算目标格子列表
     - 对每个目标格子执行 skill.effect_type（DAMAGE/HEAL）
     - 播放技能动画（AnimatedSprite2D 的 "skill" 动画 + 粒子特效）
     - CD 计数（skill.cooldown）
3. **技能 UI**（battle_ui.gd）：
   - 在 ActionPanel 中添加 Skill1Button / Skill2Button
   - 点击技能按钮 → 显示技能范围（红色/蓝色高亮）
   - 点击目标格 → 释放技能
   - CD > 0 时按钮灰化 + 显示 CD 数字
4. **地形修正集成**（damage_calculator.gd）：
   - 在 calculate_damage() 中读取 defender 的地形 TileData
   - 命中率 = 95% − tile.dodge_bonus
   - （可选）防御加成：DEF += tile.def_bonus
5. **武器克制集成**（damage_calculator.gd）：
   - 已在 S4 实现，S5 验证
6. **胜负判定**（battle_controller.gd）：
   - 每回合结束检查：
     - 如果所有敌人 HP <= 0 → trigger_victory()
     - 如果所有玩家 HP <= 0 → trigger_defeat()
   - trigger_victory() → SceneManager.change_scene_to_file("res://scenes/victory/victory.tscn")
   - trigger_defeat() → SceneManager.change_scene_to_file("res://scenes/defeat/defeat.tscn")
7. **Victory 场景**（scenes/victory/victory.tscn）：
   - 羊皮纸背景
   - "胜利！"标题（思源宋体 Heavy 64pt）
   - "返回主菜单"按钮
8. **Defeat 场景**（scenes/defeat/defeat.tscn）：
   - 羊皮纸背景
   - "失败"标题
   - "重试"按钮（重新加载 Battle 场景）
   - "返回主菜单"按钮

### S5.3 不做

- 音效/BGM（S6）
- 复杂 Buff/Debuff（MVP 只做伤害/治疗）

### S5.4 验收标准

1. **技能释放正确**：
   - E2E 测试（输入注入）：
   ```gdscript
   # 徐凤年移动后，点击"两袖青蛇"技能按钮
   # 点击敌人（十字 AOE 中心）
   # 等待技能动画
   # 检查十字范围内的敌人 HP 减少
   var enemies_in_cross := [enemy1, enemy2]  # 假设在十字范围内
   for e in enemies_in_cross:
       assert_lt(e.current_hp, e.unit_data.max_hp)
   ```
2. **地形修正生效**：
   - GUT 单元测试：
   ```gdscript
   func test_terrain_dodge_bonus():
       # 站在林地（+20% 闪避）的单位
       var defender := Unit.new()
       defender.current_position = Vector2i(2, 2)
       
       var grid := GridSystem.new()
       var forest_tile := TileData.new()
       forest_tile.dodge_bonus = 20
       grid.tiles[Vector2i(2, 2)] = forest_tile
       
       # 模拟 100 次攻击，统计命中率
       var hit_count := 0
       for i in range(100):
           var result := DamageCalculator.calculate_damage(attacker, defender, skill)
           if result.hit:
               hit_count += 1
       
       # 命中率应约为 75%（95% − 20%）
       assert_between(hit_count, 65, 85)  # 允许 ±10% 误差
   ```
3. **胜负判定触发**：
   - E2E 测试（输入注入）：
   ```gdscript
   # 击杀所有敌人
   for enemy in enemies:
       enemy.current_hp = 0
       enemy.die()
   
   # 等待下一帧
   await get_tree().process_frame
   
   # 检查场景切换到 Victory
   assert_eq(get_tree().current_scene.name, "Victory")
   ```
4. **CD 机制正确**：
   - E2E 测试：
   ```gdscript
   # 使用"两袖青蛇"（CD=2）
   xu_fengnian.use_skill(1, target_pos)
   assert_eq(xu_fengnian.skills[1].current_cd, 2)
   
   # 下一回合
   turn_manager._next_turn()
   assert_eq(xu_fengnian.skills[1].current_cd, 1)
   
   # 再下一回合
   turn_manager._next_turn()
   assert_eq(xu_fengnian.skills[1].current_cd, 0)  # 可再次使用
   ```

### S5.5 依赖

- S4 完成（移动/攻击/伤害结算）

### S5.6 工作量估算

**2 天**（12-16 小时）

**任务拆分**：
- SkillData Resource + 实例创建：2 小时
- SkillExecutor 实现：4 小时
- 技能 UI + CD 显示：2 小时
- 地形修正集成：1 小时
- 胜负判定 + Victory/Defeat 场景：2 小时
- 验收测试：3 小时

---

## Sprint 6: 2 关卡 + polish（字体/特效）+ E2E 通关

> **完成状态（2026-04-19）**：S6 已完成并进入 MVP Freeze，版本号 `v0.1`。
> 交付物：`LevelData` Resource、`level_01.tres` / `level_02.tres`、BOSS `yang_yuanzan.tres`、`level_select` 场景、真实鼠标 `tools/e2e_full_playthrough.gd` 与 7 张流程截图。

### S6.1 目标

完成 2 个关卡（教程关 + 正式关）、美术 polish（字体 / 特效）、E2E 通关测试，达到 MVP DoD。

> **Manager 决策（2026-04-18）**：D2 音效 / BGM 与 D3 角色立绘替换均 **不做**，列入 Post-MVP 待办（见 [07-risks-unknowns.md](./07-risks-unknowns.md) §3 D2/D3）。

### S6.2 范围

1. **LevelData Resource**（scripts/core/level_data.gd）：
   - 创建 LevelData 类（见 [02-architecture.md](./02-architecture.md) §4.4）
   - 创建 2 个 .tres 实例：
     - tutorial_level.tres（教程关，8×8 地图，见 [05-mvp-scope.md](./05-mvp-scope.md) §3.1）
     - level_1.tres（正式关，12×10 地图，§3.2）
2. **关卡加载逻辑**（battle_controller.gd）：
   - `_ready()` 时读取 GameState.current_level
   - 从 GameBalance.get_level_data() 获取 LevelData
   - 根据 LevelData 初始化地图 + 单位（player_units / enemy_units / spawn 位置）
3. **教程关实现**：
   - 按 §3.1 配置：
     - 地图：8×8，平地/林地/山混合
     - 我方：徐凤年 + 姜泥
     - 敌方：3 只普通兵
   - 教学提示（MessageLabel 显示，见 §3.1.4）
4. **正式关实现**：
   - 按 §3.2 配置：
     - 地图：12×10，复杂地形
     - 我方：徐凤年 + 姜泥 + 李淳罡
     - 敌方：5 普通兵 + 2 弓箭手 + 1 BOSS
   - BOSS 技能："横扫千军"（十字 2 格 AOE）
5. **CharacterSelect 场景**（scenes/character_select/character_select.tscn）：
   - MVP 简化：3 个角色卡片（头像 + 名字 + 属性预览）
   - 点击"确认出战"按钮 → GameState.selected_characters = ["xu_fengnian", "jiang_ni", "li_chungang"]
   - → SceneManager.change_scene_to_file("res://scenes/battle/battle.tscn")
6. **美术 polish**：
   - **角色立绘替换**: **不做**（Manager D3 决策 2026-04-18，Post-MVP 待办；MVP 用 Tiny Swords sprite Idle 首帧裁剪作为头像占位）
   - **技能特效**：
     - 刀气/剑气：复用 Tiny Swords `Particle FX/Fire_01.png` 改色（蓝/金）
     - 治疗光效：`Monk/Heal_Effect.png` 改色（绿 → 金）
     - 剑开天门：叠加 Explosion_01 + 自定义剑气粒子（GPUParticles2D）
   - **音效/BGM**: **不做**（Manager D2 决策 2026-04-18，Post-MVP 待办；MVP 为纯静音游戏）
7. **E2E 通关测试**：
   - 人工盲跑测试：
     - 启动游戏 → 主菜单 → 点"教程" → 通关教程关（5 分钟内）
     - 返回主菜单 → 点"开始游戏" → 选角色 → 通关正式关（10 分钟内）
   - 记录 bug（无法通关/卡死/崩溃 → 修复后重测）
8. **性能测试**：
   - `godot --headless` 运行 Battle 场景，检查帧率稳定性
   - Godot Profiler 检查内存占用（< 200 MB）

### S6.3 不做

- 更多关卡（MVP 只有 2 关）
- 剧情对话（MVP 无对话）

### S6.4 验收标准

1. **2 关卡可通关**：
   - 教程关：人工盲跑，5 分钟内通关，无明显困惑
   - 正式关：人工盲跑，15 分钟内通关，BOSS 有挑战性但可击败
2. **美术达标**：
   - screenshot_harness 截取主菜单 + 战斗场景 + 胜利界面
   - 人工评审：武侠风格协调（羊皮纸/毛笔字/山水背景 + 技能特效清晰）
3. **性能达标**：
   - 60 FPS 稳定（12×10 网格 + 8 单位同屏）
   - 内存占用 < 200 MB
4. **MVP DoD 完成**：
   - 18 项核心功能（[05-mvp-scope.md](./05-mvp-scope.md) §2.1）全部实现
   - GUT 单元测试 PASS
   - E2E 测试 PASS
   - 无 P0/P1 bug

### S6.5 依赖

- S5 完成（技能 + 胜负判定）

### S6.6 工作量估算

**2 天**（12-16 小时）

**任务拆分**：
- LevelData Resource + 关卡配置：2 小时
- 关卡加载逻辑：1 小时
- 教程关实现 + 教学提示：2 小时
- 正式关实现（BOSS）：2 小时
- CharacterSelect 场景：1 小时
- 美术 polish（技能特效；立绘替换已按 D3 决策剔除）：3 小时
- 音效/BGM：**不做**（D2 决策 2026-04-18，0 小时）
- E2E 通关测试 + bug 修复：3 小时

---

## Sprint 验收模板（每个 Sprint 后执行）

### E2E 验证任务模板

```
[Sprint N 独立 E2E 验证]
前置：Sprint N 已由另一任务实施完成。
严格按 docs/design/06-sprint-plan.md §SN.4 跑所有验收标准，独立判断 DoD 是否达成。
对每一项输出：PASS / FAIL + 证据（命令输出片段或截图路径）。
任何 FAIL 必须清楚说明根因和修复建议，不要自行修复（Manager 会派修复任务）。
```

### Smoke Test 命令

```bash
# 每个 Sprint 完成后跑
godot --headless --path /Users/xiaochunliu/VerdentProject/big-wuxia --quit
# 无 push_error 日志 → PASS
```

### Screenshot Harness 示例

```bash
# S2 地形渲染验收
godot --path /Users/xiaochunliu/VerdentProject/big-wuxia \
      --script tools/screenshot_harness.gd -- \
      res://scenes/battle/battle.tscn /tmp/s2_battle.png 60 1366x768

# S3 单位渲染验收
godot --path /Users/xiaochunliu/VerdentProject/big-wuxia \
      --script tools/screenshot_harness.gd -- \
      res://scenes/battle/battle.tscn /tmp/s3_units.png 60 1366x768

# S6 主菜单验收
godot --path /Users/xiaochunliu/VerdentProject/big-wuxia \
      --script tools/screenshot_harness.gd -- \
      res://scenes/main_menu/main_menu.tscn /tmp/s6_mainmenu.png 45 1366x768
```

---

**下一步**：阅读 [07-risks-unknowns.md](./07-risks-unknowns.md) 了解已知风险和待拍板事项。
