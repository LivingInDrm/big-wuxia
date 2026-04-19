# BigWuXia v0.1

BigWuXia 是一个基于 Godot 4.6 的武侠 SRPG MVP。当前版本完成了主菜单、双关卡流程、基础回合战斗、技能/VFX、胜负结算，以及从主菜单到最终胜利的真实鼠标 E2E 通关脚本。

## 运行

```bash
godot --path /Users/xiaochunliu/VerdentProject/big-wuxia
```

默认入口：
- 主菜单
- 选关
- 第一关 `第一关 · 剑气试锋`
- 第二关 `第二关 · 杨元赞`

## 操作说明

- 左键点击己方单位：选中单位
- 左键点击高亮地块：移动
- 移动后左键点击敌人：普通攻击
- 左键点击左下技能按钮：进入技能瞄准
- 左键点击高亮目标格：释放技能
- 战斗结束后：在胜利/失败界面返回选关

## 关卡列表

- `level_01` `第一关 · 剑气试锋`
  - 胜利条件：`kill_all`
  - 敌人：3 名北莽普通兵
- `level_02` `第二关 · 杨元赞`
  - 胜利条件：`kill_boss`
  - BOSS：杨元赞

## 测试

全量回归：

```bash
for f in tests/test_*.gd; do
  case "$f" in
    tests/test_click_attack.gd|tests/test_skill_cast.gd) godot --path . --script "$f" ;;
    *) godot --headless --path . --script "$f" ;;
  esac
done
```

真实鼠标完整通关 + 截图：

```bash
godot --path /Users/xiaochunliu/VerdentProject/big-wuxia --script tools/e2e_full_playthrough.gd
```

截图输出目录：
- `tools/screenshots/e2e_step_01.png`
- `tools/screenshots/e2e_step_02.png`
- `tools/screenshots/e2e_step_03.png`
- `tools/screenshots/e2e_step_04.png`
- `tools/screenshots/e2e_step_05.png`
- `tools/screenshots/e2e_step_06.png`
- `tools/screenshots/e2e_step_07.png`
