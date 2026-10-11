extends CharacterBody2D

@export var max_health: int = 30
@export var move_speed: float = 40.0
@export var contact_damage: int = 5
@export var coin_value: int = 1

var health: int
var target: Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	health = max_health
	target = get_tree().get_first_node_in_group("player")
	sprite.play("run")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return

	var dir := global_position.direction_to(target.global_position)
	velocity = dir * move_speed
	move_and_slide()

	# Sprite sağa bakıyorsa bu satır doğru; sola bakıyorsa < yerine > yaz
	if absf(dir.x) > 0.05:
		sprite.flip_h = dir.x < 0.0

func take_damage(amount: int) -> void:
	health -= amount
	_flash()
	if health <= 0:
		die()

func die() -> void:
	EventBus.enemy_died.emit(global_position, coin_value)
	queue_free()

func _flash() -> void:
	sprite.modulate = Color(3, 3, 3)  # kısa süreli parlama
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
