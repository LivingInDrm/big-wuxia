class_name AttributeSet
extends Resource

# A 资质（1-10 scale，静态底子）
@export var constitution: int = 5 # 体质
@export var strength: int = 5 # 臂力
@export var agility: int = 5 # 身法
@export var insight: int = 5 # 悟性
@export var fortune: int = 5 # 福缘

# B 资源基础值（max_hp/max_mp 最终通过 AttributeResolver 计算，这里只放基础加值）
@export var base_hp: int = 30 # 生命基础值
@export var base_mp: int = 10 # 内力基础值

# D 专精（本步先建字段，step-1-4 才使用）
@export var spec_fist: int = 0 # 拳掌
@export var spec_blade: int = 0 # 刀法
@export var spec_sword: int = 0 # 剑法
@export var spec_medicine: int = 0 # 医术
@export var spec_poison: int = 0 # 毒术
