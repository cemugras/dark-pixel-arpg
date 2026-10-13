extends Node2D

@export var magnet_range: float = 40.0   # bu mesafeye girince oyuncuya doğru çekilir
@export var collect_range: float = 6.0   # bu mesafede toplanır
@export var magnet_speed: float = 180.0

var value: int = 1

var _target: Node2D
var _collected: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("coin")
	_target = get_tree().get_first_node_in_group("player")
	sprite.play("spin")

func attract_to_player() -> void:
	magnet_range = INF
	magnet_speed = 600.0
	
func _physics_process(delta: float) -> void:
	if _collected or not is_instance_valid(_target):
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist <= collect_range:
		_collect()
	elif dist <= magnet_range:
		global_position = global_position.move_toward(_target.global_position, magnet_speed * delta)

func _collect() -> void:
	_collected = true
	EventBus.coin_collected.emit(value)
	sprite.play("collect")
	await sprite.animation_finished
	queue_free()
