# BigWuXia — 风险与未知项

本文档列出 BigWuXia MVP 开发过程中的已知风险、技术未知项、待 Manager 拍板的关键决策、以及应对策略。

## 1. 已知风险

### R1: 角色 sprite 风格冲突（优先级：P1）

**描述**：
- 徐凤年和李淳罡都使用 Tiny Swords `Warrior` sprite（动作完全一致）
- MVP 靠颜色区分（Blue vs Purple），但视觉上仍是"欧式战士"，与雪中悍刀行的武侠风格冲突
- 姜泥使用 `Monk` sprite（西式僧袍），与少女轻功形象冲突更严重

**影响**：
- MVP 阶段可通过 UI 文字（"徐凤年"/"李淳罡"/"姜泥"）+ 头像（Human Avatars 占位）勉强区分
- 长期需 AI 生成角色立绘替换（512×512 头像 + 可选：重绘 sprite sheet）

**应对策略**：
1. **MVP 阶段**：
   - 接受风格冲突，用颜色区分（Blue Warrior = 徐凤年，Purple Warrior = 李淳罡，Blue Monk = 姜泥）
   - 在角色卡片/UI 上显示清晰的中文名字 + 背景故事（"北凉世子"/"剑神"/"王妃"）
   - 用 UI 风格（羊皮纸/毛笔字/山水背景）强化武侠感
2. **Sprint 6 polish（可选）**：
   - 用 Stable Diffusion 生成 3 个角色的立绘（512×512）
   - 替换 UI 头像（Human Avatars → 立绘）
   - 战斗场景中仍用 Tiny Swords sprite（成本控制）
3. **后续版本（MVP 后）**：
   - 委托像素艺术师重绘 3 个角色的完整 sprite sheet（192×192，Idle/Run/Attack/Skill）
   - 或用 Stable Diffusion + ControlNet 生成像素风武侠角色 sprite

**风险等级**：**中**（MVP 可交付，但用户反馈可能指出风格不协调）

---

### R2: TileMapLayer 新 API 社区案例少（优先级：P2）

**描述**：
- TileMapLayer 是 Godot 4.6 新 API（取代 TileMap），社区案例少
- 可能遇到 API 不稳定、文档不全、边缘 bug

**影响**：
- 开发 Sprint 2 时可能遇到 TileMapLayer 配置/导入问题
- 例如：autotile 规则不生效、Custom Data Layer 读取失败、多层渲染顺序错误

**应对策略**：
1. **前期验证**：
   - Sprint 2 早期用 screenshot_harness 截图验证 TileMapLayer 渲染（检查 seam/层级）
   - 如果 TileMapLayer 有严重 bug，**降级到 Godot 4.5 用 TileMap**（config_version 仍是 5，API 向下兼容）
2. **Godot 社区求助**：
   - 遇到问题先查官方文档：https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
   - 如无文档，查 GitHub Issues：https://github.com/godotengine/godot/issues
   - 如仍无解，发 GitHub Issue 或 Godot Discord 求助
3. **回退方案**：
   - 如 TileMapLayer 完全不可用，用纯 Sprite2D 拼地图（手动放置 64×64 tile）
   - 性能损失可接受（12×10 = 120 个 Sprite2D，现代设备无压力）

**风险等级**：**低-中**（4.6 是稳定版，重大 bug 概率低；但新 API 需早期验证）

---

### R3: 武侠字体许可问题（优先级：P3）

**描述**：
- 武侠风需要书法/宋体字体，常见的"方正楷体"/"华文行楷"等商业字体**不免费**
- 如果误用商业字体，可能面临版权纠纷

**影响**：
- MVP 阶段字体选择受限
- 免费字体（思源宋体）风格可能不够"武侠"

**应对策略**：
1. **MVP 阶段**：
   - 使用**思源宋体**（Noto Serif CJK SC），授权：SIL OFL 1.1（免费商用）
   - 下载：https://github.com/adobe-fonts/source-han-serif/releases
   - 如需更强武侠感，可用**站酷高端黑**（免费商用）：https://www.zcool.com.cn/special/zcoolfonts/
2. **后续版本（可选）**：
   - 购买商业授权字体（例如"汉仪尚巍手书"/"文悦古典明朝体"），成本约 500-2000 元
   - 或委托书法家手写标题字（"雪中悍刀行"5 个字，成本约 1000 元）
3. **验证清单**：
   - 所有字体必须记录授权信息在 `docs/design/CREDITS.md`（MVP 后期补充）

**风险等级**：**低**（思源宋体足够覆盖 MVP 需求）

---

### R4: 敌方 AI 过于简单或过于复杂（优先级：P2）

**描述**：
- MVP 的敌方 AI 是简单贪心策略（找最近目标 → 移动 → 攻击）
- 可能过于**弱智**（玩家无挑战），或过于**无脑冲锋**（被 AOE 团灭）

**影响**：
- 如果 AI 太弱，正式关无挑战性，玩家无成就感
- 如果 AI 太强（例如优先集火姜泥），玩家无法通关

**应对策略**：
1. **MVP 阶段**：
   - Sprint 4-5 实现简单 AI，Sprint 6 人工盲跑测试时调整
   - **AI 参数化**：
     ```gdscript
     # ai_controller.gd
     const AI_AGGRESSION := 0.7  # 70% 概率优先攻击，30% 优先防守
     const AI_FOCUS_FIRE := false  # MVP 不集火，后续可开启
     ```
   - 如果教程关 AI 太强，降低敌人数值（HP 12 → 10，ATK 4 → 3）
   - 如果正式关 AI 太弱，增加 BOSS 血量（HP 35 → 40）
2. **后续版本**：
   - 实现 AI 难度分级（简单/普通/困难）
   - 困难 AI 策略：优先攻击血量最低单位、避免进入 AOE 范围、利用地形（站林地增加闪避）

**风险等级**：**中**（MVP 可通过数值调整应对，但需人工测试）

---

### R5: 性能瓶颈（BFS/A* 在大地图慢）（优先级：P3）

**描述**：
- GridSystem 的 BFS/A* 算法时间复杂度 O(n log n)（n = 网格总数）
- 12×10 网格 = 120 个格子，每次 BFS 遍历最多 120 次，性能无压力
- 但如果后续版本扩展到 20×20（400 格）或 30×30（900 格），可能卡顿

**影响**：
- MVP 阶段无影响（12×10 网格足够小）
- 后续版本如扩展地图需优化

**应对策略**：
1. **MVP 阶段**：
   - 不优化（12×10 性能无问题）
2. **后续版本（如需大地图）**：
   - 用 PriorityQueue（堆）替代 `Array.sort_custom()`，时间复杂度从 O(n²) 降到 O(n log n)
   - 缓存移动范围（相同 mov 的单位共用结果）
   - 用空间分区（例如 Quadtree）减少 BFS 遍历范围

**风险等级**：**低**（MVP 无影响）

---

### R6: Godot MCP 在子任务中不可用（优先级：P1）

**描述**：
- Godot MCP 工具（如 `run_project`, `get_debug_output`）需要在交互式 Claude Code 会话中使用
- CI/自动化子任务环境可能无法调用 MCP
- 参考 godot-dev skill: "MCP 工具在交互式会话中使用，CI/自动化子任务用 `godot --headless` CLI 替代"

**影响**：
- Manager 派发的子任务（Sprint 实施 / E2E 验证）无法用 MCP 启动编辑器/运行项目

**应对策略**：
1. **所有子任务用 CLI 替代 MCP**：
   - 运行项目：`godot --path /path/to/project res://scenes/battle/battle.tscn`
   - Headless 测试：`godot --headless --path /path/to/project --script tests/e2e/test_battle.gd`
   - 截图验收：`godot --path /path/to/project --script tools/screenshot_harness.gd -- ...`
2. **任务 prompt 模板**：
   ```
   [Sprint N 实施]
   严格按 docs/design/06-sprint-plan.md §SN.2 范围实施。
   注意：不要用 Godot MCP（子任务环境不可用），用 `godot --headless` CLI。
   完成后用 `godot --headless --quit` smoke test 检查无报错。
   ```

**风险等级**：**低**（有明确替代方案）

---

## 2. 技术未知项

### U1: TileMapLayer 多层叠加性能

**描述**：
- BigWuXia 需要 2 层 TileMapLayer（地形层 + 高亮层）
- Godot 4.6 官方文档未明确说明多层 TileMapLayer 的性能开销

**验证方式**：
- Sprint 2 早期用 screenshot_harness + Godot Profiler 测试：
  - 单层 TileMapLayer（12×10 地形）
  - 双层 TileMapLayer（地形 + 高亮层）
  - 检查帧率差异（预期 < 5%）

**应对策略**：
- 如果双层性能差（帧率 < 55 FPS），合并到单层（动态修改 tile 颜色而非叠加新层）

---

### U2: AnimatedSprite2D 批量实例化性能

**描述**：
- 正式关有 11 个单位（3 玩家 + 8 敌方）
- 每个单位有 AnimatedSprite2D + HealthBar + 粒子特效
- 未知 11 个 AnimatedSprite2D 同时播放是否卡顿

**验证方式**：
- Sprint 3 早期用 Godot Profiler 测试：
  - 同时播放 11 个 AnimatedSprite2D Idle 动画（8fps）
  - 检查帧率（预期 60 FPS 稳定）

**应对策略**：
- 如果卡顿，降低动画帧率（8fps → 6fps）
- 或用 SpriteFrames 共享（所有同色 Warrior 共用一个 SpriteFrames 实例）

---

### U3: GPUParticles2D vs CPUParticles2D 选型

**描述**：
- 技能特效（刀气/剑气/治疗光效）可用 GPUParticles2D 或 CPUParticles2D
- GPUParticles2D 性能更好，但配置复杂；CPUParticles2D 简单但 CPU 占用高

**验证方式**：
- Sprint 5 早期用 Godot Profiler 测试：
  - 同时播放 3 个技能特效（GPUParticles2D vs CPUParticles2D）
  - 检查帧率和 CPU 占用

**应对策略**：
- MVP 优先用 CPUParticles2D（配置简单，3 个特效同时播放无压力）
- 后续版本如需优化，改为 GPUParticles2D

---

## 3. 待 Manager 拍板事项

### D1: BOSS 角色设定（影响正式关设计）

**问题**：
- 正式关的 BOSS 是谁？需要明确人设 + 技能
- 选项：
  1. **北莽武将**（虚构，Black Warrior sprite）
     - 优点：不破坏原著，自由度高
     - 缺点：无 IP 代入感
  2. **徽山轩辕敬城**（原著角色，儒剑仙）
     - 优点：IP 粉丝有代入感
     - 缺点：轩辕是友方，做 BOSS 不合理
  3. **北莽红衣女帝**（原著角色）
     - 优点：经典反派，有代入感
     - 缺点：Tiny Swords 无女性 sprite（需 AI 生成）
  4. **拓跋菩萨**（原著角色，北莽国师）
     - 优点：强力反派，合理
     - 缺点：Monk sprite 不适合（需 AI 生成）

**Manager 需决策**：
- 选哪个 BOSS？
- BOSS 技能是什么？（例如"横扫千军"十字 AOE，或"单体秒杀大招"）

**建议**：
- **优先选项 1**（北莽武将，虚构）：成本最低，Black Warrior sprite 直接用
- 后续版本可替换为原著角色（需 AI 生成 sprite）

---

### D2: Sprint 6 是否做音效/BGM（影响工作量）

**问题**：
- Sprint 6 的音效/BGM 是"可选"（标注"如时间紧可省略"）
- 需 Manager 决定是否做

**选项**：
1. **做**（增加 2 天工作量）：
   - 主菜单 BGM（古琴/古风音乐循环）
   - 战斗 BGM（紧张武侠配乐）
   - 攻击音效 + 治疗音效 + UI 点击音
   - 来源：freesound.org（CC0 授权）
2. **不做**（保持 Sprint 6 = 2 天）：
   - MVP 无音效/BGM（纯静音游戏）
   - 后续版本补充

**Manager 需决策**：
- 是否做音效/BGM？

**建议**：
- **优先选项 2**（不做）：MVP 聚焦战斗循环验证，音效对核心玩法影响小
- 后续版本补充音效/BGM（1-2 天工作量）

---

### D3: Sprint 6 是否做角色立绘替换（影响美术风格）

**问题**：
- Sprint 6 的角色立绘替换是"可选"（标注"如 S6 时间紧可延后"）
- 需 Manager 决定是否做

**选项**：
1. **做**（增加 1 天工作量）：
   - 用 Stable Diffusion 生成徐凤年/姜泥/李淳罡立绘（512×512）
   - 替换 UI 头像（Human Avatars → 立绘）
   - 提升武侠 IP 代入感
2. **不做**（保持 Sprint 6 = 2 天）：
   - MVP 用 Tiny Swords Human Avatars 占位
   - 后续版本替换

**Manager 需决策**：
- 是否做立绘替换？

**建议**：
- **优先选项 2**（不做）：MVP 聚焦战斗循环，立绘对核心玩法影响小
- 后续版本补充立绘（1 天工作量）

---

### D4: Sprint 粒度是否需调整（影响派发节奏）

**问题**：
- 当前 6 个 Sprint，每个 1-2 天工作量，总计 10-12 天
- Manager 可能希望更细颗粒（8 个 Sprint，每个 1 天）或更粗颗粒（4 个 Sprint,每个 2-3 天）

**选项**：
1. **保持 6 个 Sprint**（当前方案）
2. **拆成 8 个 Sprint**（更细）：
   - S1: 项目骨架 + Autoload（1 天）
   - S2: 主菜单 + 字体/背景（1 天）
   - S3: 网格地图（1 天）
   - S4: 单位系统（1 天）
   - S5: 回合管理（1 天）
   - S6: 移动/攻击（2 天）
   - S7: 技能 + 地形/克制（2 天）
   - S8: 2 关卡 + polish（2 天）
3. **合并成 4 个 Sprint**（更粗）：
   - S1: 项目骨架 + 主菜单 + 网格地图（2-3 天）
   - S2: 单位系统 + 回合管理 + 移动/攻击（3-4 天）
   - S3: 技能系统 + 地形/克制 + 胜负判定（2-3 天）
   - S4: 2 关卡 + polish + E2E（2-3 天）

**Manager 需决策**：
- 是否调整 Sprint 粒度？

**建议**：
- **保持 6 个 Sprint**（平衡粒度和验收频率）

---

## 4. 应对策略总结

| 风险/未知项 | 优先级 | 应对策略 | 验证时机 |
|---|---|---|---|
| R1: 角色 sprite 风格冲突 | P1 | MVP 用颜色区分，S6 可选立绘替换 | S6 人工评审 |
| R2: TileMapLayer 新 API | P2 | S2 早期验证，如有 bug 降级到 4.5 TileMap | S2 实施前 |
| R3: 字体许可问题 | P3 | 用思源宋体（SIL OFL 1.1） | S1 字体导入 |
| R4: AI 过于简单/复杂 | P2 | S6 人工测试后调数值 | S6 盲跑 |
| R5: BFS/A* 性能 | P3 | MVP 不优化（12×10 无问题） | S4 Profiler |
| R6: Godot MCP 不可用 | P1 | 子任务用 `godot --headless` CLI | 所有 Sprint |
| U1: TileMapLayer 多层性能 | — | S2 Profiler 测试 | S2 实施中 |
| U2: AnimatedSprite2D 性能 | — | S3 Profiler 测试 | S3 实施中 |
| U3: GPUParticles2D 选型 | — | S5 Profiler 测试，优先 CPU 粒子 | S5 实施中 |
| D1: BOSS 角色设定 | — | **待 Manager 拍板** | S6 实施前 |
| D2: 音效/BGM | — | **待 Manager 拍板**（建议不做） | S6 实施前 |
| D3: 角色立绘替换 | — | **待 Manager 拍板**（建议不做） | S6 实施前 |
| D4: Sprint 粒度调整 | — | **待 Manager 拍板**（建议保持 6 个） | 立即 |

---

## 5. Manager 需立即决策的事项

请 Manager 在开始 Sprint 1 前决策以下事项：

1. **D1: BOSS 角色设定** → 选项 1（北莽武将，虚构）或其他？
2. **D2: Sprint 6 是否做音效/BGM** → 做（+2 天）或不做？
3. **D3: Sprint 6 是否做角色立绘替换** → 做（+1 天）或不做？
4. **D4: Sprint 粒度是否调整** → 保持 6 个或调整？

**建议决策**（最小范围 MVP）：
- D1: 选项 1（北莽武将，虚构），技能"横扫千军"（十字 2 格 AOE）
- D2: 不做音效/BGM（后续版本补充）
- D3: 不做立绘替换（后续版本补充）
- D4: 保持 6 个 Sprint

如采纳建议，总工作量保持 **10-12 天**（6 个 Sprint × 1-2 天）。

---

**下一步**：Manager 决策上述事项后，开始 Sprint 1 实施。
