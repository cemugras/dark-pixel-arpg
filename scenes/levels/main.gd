extends Node2D

@export var coin_scene: PackedScene

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(pos: Vector2, coin_value: int) -> void:
	var coin := coin_scene.instantiate()
	add_child(coin)
	coin.global_position = pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	coin.value = coin_value
