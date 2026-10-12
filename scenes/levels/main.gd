extends Node2D

@export var coin_scene: PackedScene

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(pos: Vector2, coin_value: int) -> void:
	# Büyük ödüller (boss) birden çok altın parçasına bölünür
	var pieces := clampi(ceili(coin_value / 5.0), 1, 20)
	var remaining := coin_value

	for i in pieces:
		var piece_value := int(float(remaining) / (pieces - i))
		remaining -= piece_value

		var coin := coin_scene.instantiate()
		add_child(coin)
		var spread := 4.0 if pieces == 1 else 14.0
		coin.global_position = pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, spread)
		coin.value = piece_value
