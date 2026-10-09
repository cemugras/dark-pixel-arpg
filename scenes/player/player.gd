extends CharacterBody2D

@export var move_speed: float = 90.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * move_speed
	move_and_slide()
	_update_animation(dir)

func _update_animation(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("walk")
		if dir.x != 0.0:
			sprite.flip_h = dir.x < 0.0
