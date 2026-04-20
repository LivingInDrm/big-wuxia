extends CharacterBody2D

signal interactable_area_entered(area: Area2D)
signal interactable_area_exited(area: Area2D)

const SPEED := 180.0

@onready var sprite: AnimatedSprite2D = get_node("AnimatedSprite2D")
@onready var interaction_area: Area2D = get_node("PlayerInteractionArea")

var facing: String = "down"


func _ready() -> void:
	add_to_group("overworld_player")
	interaction_area.add_to_group("player_interaction_area")
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	_update_animation(Vector2.ZERO)


func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector * SPEED
	move_and_slide()
	_update_animation(input_vector)


func _update_animation(input_vector: Vector2) -> void:
	if input_vector.length_squared() > 0.0:
		if absf(input_vector.x) >= absf(input_vector.y):
			facing = "right" if input_vector.x > 0.0 else "left"
		else:
			facing = "down" if input_vector.y > 0.0 else "up"
		sprite.play("run")
	else:
		sprite.play("idle")

	sprite.flip_h = facing == "left"
	if facing == "up":
		sprite.scale = Vector2(0.92, 0.92)
		sprite.modulate = Color(0.92, 0.92, 1.0, 1.0)
	elif facing == "down":
		sprite.scale = Vector2(1.0, 1.0)
		sprite.modulate = Color(1, 1, 1, 1)
	else:
		sprite.scale = Vector2(0.97, 0.97)
		sprite.modulate = Color(0.98, 0.98, 0.98, 1.0)


func _on_interaction_area_entered(area: Area2D) -> void:
	interactable_area_entered.emit(area)


func _on_interaction_area_exited(area: Area2D) -> void:
	interactable_area_exited.emit(area)
