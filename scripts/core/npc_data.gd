extends Resource
class_name NPCData

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""

@export_group("Visual")
@export var unit_id: String = ""
@export var sprite_frames: SpriteFrames
@export var modulate: Color = Color.WHITE

@export_group("Dialogue")
@export var default_dialogue_id: String = ""
@export var conditional_dialogues: Array[Dictionary] = []

@export_group("Interaction")
@export_range(0.0, 512.0, 1.0) var interaction_range: float = 48.0
