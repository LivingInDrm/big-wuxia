extends RefCounted
class_name WeaponTypes
## WeaponTypes —— 武器类型枚举 + 克制关系
##
## 设计：见 docs/design/01-game-design.md §7.3 克制关系：
##   - 刀克剑（BLADE 克 SWORD）
##   - 剑克内功（SWORD 克 INNER）
##   - 内功克刀（INNER 克 BLADE）
##   （三者循环相克）

enum Type {
	NONE = 0,   # 敌兵等无武器克制
	BLADE = 1,  # 刀 —— 徐凤年
	SWORD = 2,  # 剑 —— 李淳罡
	FIST = 3,   # 拳掌/徒手 —— 姜泥、普通兵
	INNER = 4,  # 内功 —— 预留给后续纯内功流派
}

## 返回 attacker 攻击 defender 时的克制倍率：
##   相克 → 1.25；中立 → 1.0
static func counter_multiplier(attacker: int, defender: int) -> float:
	if attacker == Type.BLADE and defender == Type.SWORD:
		return 1.25
	if attacker == Type.SWORD and defender == Type.INNER:
		return 1.25
	if attacker == Type.INNER and defender == Type.BLADE:
		return 1.25
	return 1.0
