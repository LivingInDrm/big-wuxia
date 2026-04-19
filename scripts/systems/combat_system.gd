extends Node
class_name CombatSystem
## CombatSystem —— S4 基础战斗结算
##
## 职责：
##   - calc_damage(attacker, defender)：S4 简化公式 max(1, atk - def)
##   - resolve_attack(attacker, defender)：执行攻击动画 + 扣血 + 回死亡信号
##
## 地形闪避修正 / 克制 / 暴击 留给 S5。

## 伤害计算（纯函数，便于单测）
static func calc_damage(attacker_atk: int, defender_def: int) -> int:
	return max(1, attacker_atk - defender_def)


## 执行一次攻击。attacker 播放 attack 动画后 defender 扣血。
## 返回 defender 是否死亡。
##
## Caller 负责在调用前保证 attacker/defender 的合法性（在 attack_range 内、阵营不同）。
static func resolve_attack(attacker: Unit, defender: Unit) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker.unit_data == null or defender.unit_data == null:
		return false
	var dmg: int = calc_damage(attacker.unit_data.atk, defender.unit_data.def)
	defender.take_damage(dmg)
	return defender.current_hp <= 0
