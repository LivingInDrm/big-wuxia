# BigWuXia — 项目总览

## 一句话简介

基于《雪中悍刀行》IP 的 2D 网格战棋（SRPG），使用 Godot 4.6.2 开发，目标验证核心战斗循环 + 美术工作流。

## 项目基本信息

- **名称**: BigWuXia
- **类型**: 2D 回合制网格战棋（SRPG，参考 Fire Emblem / Final Fantasy Tactics）
- **引擎**: Godot 4.6.2（路径 `/usr/local/bin/godot`）
- **项目路径**: `/Users/xiaochunliu/VerdentProject/big-wuxia/`
- **美术素材**: Tiny Swords (Free Pack) `/Users/xiaochunliu/Downloads/Tiny Swords (Free Pack)/`
- **开发模式**: Manager 自主推进（参考 tiny-swords-td 风格）
- **文档语言**: 中文
- **代码语言**: GDScript（Godot 4.6 新语法，config_version=5）

## MVP 目标

BigWuXia 的 MVP 范围是**轻量级战斗循环验证**，具体包括：

1. **1 个教程关**：教学基本移动、攻击、技能、地形
2. **1 个正式关**：完整战斗循环（移动 → 攻击 → 技能 → 回合切换 → 胜负判定）
3. **3 个可玩角色**：徐凤年（主 T）、姜泥（辅助/治疗）、李淳罡（爆发大招）
4. **验证目标**：
   - 核心战斗循环跑通（回合制网格移动/攻击/技能/结算/胜负）
   - 美术工作流跑通（Tiny Swords sprite → AnimatedSprite2D → TileMapLayer 地图）
   - 武侠 IP 包装可行性（欧式 sprite + 中式 UI 风格能否兼容）

## 4 条边界（不做什么）

为了保持 MVP 范围可控，明确**不做**以下内容：

1. **剧情分支**：无对话树、无选项、无多结局；教程关和正式关的剧情都是线性固定的
2. **装备成长系统**：无装备、无道具、无升级；角色数值和技能在关卡开始时固定
3. **多章节/城镇**：只有战斗场景；无大地图、无城镇探索、无商店/锻造
4. **多人模式**：纯单机 PvE；无联机、无 PvP、无排行榜

## 技术栈核心决策

| 决策点 | 方案 | 理由 |
|---|---|---|
| 网格实现 | TileMapLayer（渲染）+ 自建 GridSystem 脚本（逻辑） | TileMapLayer 是 Godot 4.6 推荐方案；逻辑网格独立管理 occupancy/movement cost 更灵活 |
| 角色选择 | 徐凤年（Warrior·刀）+ 姜泥（Monk·辅助）+ 李淳罡（Warrior·剑神） | 3 种不同定位（坦克/辅助/爆发）+ 都能直接映射 Tiny Swords sprite（Warrior/Monk） |
| 美术风格 | MVP 用原 Tiny Swords sprite + 武侠 UI 框（羊皮纸/毛笔字/山水底） | 最快验证循环；角色立绘后期 AI 生成替换 |
| Sprint 粒度 | 6 个 sprint，每个 1-2 天工作量 | 参考 tiny-swords-td 风格，细颗粒、验收频繁 |

详细技术栈选型见 [04-tech-stack.md](./04-tech-stack.md)。

## 文档导航

本项目的设计文档统一放在 `docs/design/` 下，按编号阅读：

| # | 文件 | 内容 |
|---|---|---|
| 00 | [00-overview.md](./00-overview.md) | **本文**：项目总览、MVP 目标、边界、文档导航 |
| 01 | [01-game-design.md](./01-game-design.md) | SRPG 玩法规则、回合流程、移动/攻击/技能、地形、克制、3 角色数值+技能表 |
| 02 | [02-architecture.md](./02-architecture.md) | Godot 项目结构、场景树、autoload、数据模型、信号拓扑 |
| 03 | [03-art-pipeline.md](./03-art-pipeline.md) | Tiny Swords 素材审计、角色↔sprite 映射、UI 武侠化方案、AI 生成规格 |
| 04 | [04-tech-stack.md](./04-tech-stack.md) | TileMapLayer vs AStar2D 选型、BFS/A* 实现思路、回合状态机、输入 FSM |
| 05 | [05-mvp-scope.md](./05-mvp-scope.md) | MVP 功能勾选表、2 关卡大纲（教程关 + 正式关）、验证目标 |
| 06 | [06-sprint-plan.md](./06-sprint-plan.md) | 6 个 sprint 详单（目标/范围/不做/验收/依赖/工作量） |
| 07 | [07-risks-unknowns.md](./07-risks-unknowns.md) | 已知风险、未知项、待 Manager 拍板事项 |
| 09 | [09-attribute-system.md](./09-attribute-system.md) | v2 P1 六层属性架构、公式占位、角色矩阵、追溯接口 |

## 工作流约束（P0 规则）

参考 tiny-swords-td 项目的工作流，BigWuXia 遵循以下 P0 约束：

1. **Godot MCP 在子任务中不可用**，一律用 `godot --headless` CLI + GDScript 脚本化测试
2. **素材根固定**：`/Users/xiaochunliu/Downloads/Tiny Swords (Free Pack)/`（不拷贝到项目内，引用绝对路径）
3. **所有任务 prompt 必须指明**："阅读 `docs/design/` 的相关章节作为权威指令"，并提示使用 `godot-dev` skill
4. **每个 Sprint 完成后必须派独立 E2E 验证任务**，验证失败派修复任务直到通过才进下一 Sprint
5. **累积 2-3 个 Sprint 完成后自动 commit**（中文 `feat:` 格式）
6. **验收必须含真实输入事件模拟**（`InputEventMouseButton.new()` 注入）+ screenshot_harness 双验证

详见 [06-sprint-plan.md](./06-sprint-plan.md) 的验收模板。

## 开发环境

- **Godot**: 4.6.2，`config_version=5`（**不是 6**，写 6 会导致 `--headless --import` 报错）
- **worker skill**: `~/.verdent/skills/godot-dev/`（含 Godot 4.6 开发要点 + screenshot workflow）
- **参考项目**: `~/.verdent/workspace/base/task-skills/tiny-swords-td/`（同套素材的塔防游戏，可参考 Sprint 风格和验收流程）
- **测试框架**: GUT（Godot Unit Test），用于逻辑单元测试（BFS、伤害公式、克制计算）
- **测试模式**: `godot --headless` smoke test + GDScript 输入事件注入 + screenshot_harness + GUT

## 下一步

阅读 [01-game-design.md](./01-game-design.md) 了解战棋玩法规则，或跳转到 [06-sprint-plan.md](./06-sprint-plan.md) 查看开发路线图。
