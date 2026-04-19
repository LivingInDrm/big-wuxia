extends Resource
class_name LevelData

@export_group("Identity")
@export var level_id: String = ""
@export var level_name: String = ""

@export_group("Map")
@export var map_layout: PackedVector2Array = PackedVector2Array()

@export_group("Units")
@export var player_units: Array[Dictionary] = []
@export var enemy_units: Array[Dictionary] = []

@export_group("Objectives")
@export var victory_condition: String = "kill_all"
@export var boss_id: String = ""

@export_group("Rewards")
@export var rewards: Array[Dictionary] = []
