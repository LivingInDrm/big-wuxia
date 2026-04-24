class_name Facing
extends RefCounted

## 方向系统（isometric 斜向四方）。
##
## 设计见 docs/direction-system-design.md §B。
## 约定：
##   SW = 正面 + 不翻转（z_ 前缀，flip_h=false） - 玩家默认
##   SE = 正面 + flip_h     （z_ 前缀，flip_h=true）
##   NE = 背面 + flip_h     （b_ 前缀，flip_h=true） - 敌方默认
##   NW = 背面 + 不翻转     （b_ 前缀，flip_h=false）

enum Dir { SW = 0, SE = 1, NE = 2, NW = 3 }


## isometric grid 位移 (dx, dy) → Dir 枚举。
##
## 规则：
##   dy > 0（向下/south） → 正面 Z
##   dy < 0（向上/north） → 背面 B
##   dy = 0 时默认视为面向镜头（Z）
##   dx > 0 → 屏幕右（flip_h）
static func from_grid_delta(dx: int, dy: int, fallback: int = Dir.SW) -> int:
	if dx == 0 and dy == 0:
		return fallback
	var south := dy >= 0
	var east := dx > 0
	if south and not east:
		return Dir.SW
	if south and east:
		return Dir.SE
	if not south and east:
		return Dir.NE
	return Dir.NW


## 是否背面（B 面）。
static func is_back(d: int) -> bool:
	return d == Dir.NE or d == Dir.NW


## 是否水平翻转。
static func flip_h(d: int) -> bool:
	return d == Dir.SE or d == Dir.NE


## 动画前缀："b" 或 "z"。
static func prefix(d: int) -> String:
	return "b" if is_back(d) else "z"
