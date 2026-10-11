extends CharacterBody2D

var data: EnemyData
var max_health: int = 30
var move_speed: float = 40.0
var contact_damage: int = 5
var coin_value: int = 1

var health: int
var target: Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Dalga yöneticisi, düşmanı sahneye eklemeden önce bunu çağırır
func setup(enemy_data: EnemyData, wave: int) -> void:
	data = enemy_data
	var w := wave - 1
	max_health = int(data.max_health * (1.0 + 0.2 * w))
	contact_damage = int(data.contact_damage * (1.0 + 0.1 * w))
	move_speed = data.move_speed * minf(1.0 + 0.01 * w, 1.5)
	coin_value = data.coin_value
	scale = Vector2.ONE * data.body_scale

func _ready() -> void:
	add_to_group("enemy")
	if data:
		sprite.sprite_frames = data.sprite_frames
	health = max_health
	target = get_tree().get_first_node_in_group("player")
	sprite.play("run")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return

	var dir := global_position.direction_to(target.global_position)
	velocity = dir * move_speed
	move_and_slide()

	if absf(dir.x) > 0.05:
		var faces_right := data.sprite_faces_right if data else true
		sprite.flip_h = (dir.x < 0.0) == faces_right

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
