extends Node2D

@export var coin_scene: PackedScene

const MERCHANT_SCRIPT: Script = preload("res://scenes/npc/merchant.gd")

# Sikkeler bu düğümün altına eklenir. Zeminin (TileMapLayer) hemen arkasına yerleşir, böylece
# zeminin üstünde ama oyuncu ve yaratıkların altında çizilir (yaratık üstünden geçince sikke altta kalır).
var _coins: Node2D

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	_coins = Node2D.new()
	_coins.name = "Coins"
	add_child(_coins)
	var floor_layer := get_node_or_null("TileMapLayer")
	move_child(_coins, floor_layer.get_index() + 1 if floor_layer else 0)

	# Kanatlı tüccar: oyuncunun hemen arkasında (oyuncunun üstünde çizilir); dalga sonu akışını o yürütür
	var merchant: Node2D = MERCHANT_SCRIPT.new()
	merchant.name = "Merchant"
	add_child(merchant)
	var player := get_node_or_null("Player")
	if player:
		move_child(merchant, player.get_index() + 1)

func _on_enemy_died(pos: Vector2, coin_value: int) -> void:
	# Büyük ödüller (boss) birden çok altın parçasına bölünür
	var pieces := clampi(ceili(coin_value / 5.0), 1, 20)
	var remaining := coin_value

	for i in pieces:
		var piece_value := int(float(remaining) / (pieces - i))
		remaining -= piece_value

		var coin := coin_scene.instantiate()
		_coins.add_child(coin)
		var spread := 4.0 if pieces == 1 else 14.0
		coin.global_position = pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, spread)
		coin.value = piece_value
