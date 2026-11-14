extends Node2D

@export var coin_scene: PackedScene

const MERCHANT_SCRIPT: Script = preload("res://scenes/npc/merchant.gd")

# Sikkeler bu düğümün altına eklenir. Zeminin (TileMapLayer) hemen arkasına yerleşir, böylece
# zeminin üstünde ama oyuncu ve yaratıkların altında çizilir (yaratık üstünden geçince sikke altta kalır).
var _coins: Node2D

func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.coins_spilled.connect(_on_coins_spilled)
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

# Vuruldukça saçılan sikkeler (Mammon): 2'şer değerlik parçalar, yaratığın etrafına küçük bir sıçramayla savrulur
const SPILL_PIECE_VALUE: int = 2
const SPILL_MIN_DIST: float = 22.0
const SPILL_MAX_DIST: float = 50.0
const SPILL_TIME: float = 0.35
const SPILL_HOP: float = 14.0

func _on_coins_spilled(pos: Vector2, coin_value: int) -> void:
	var pieces := clampi(ceili(float(coin_value) / SPILL_PIECE_VALUE), 1, 8)
	var remaining := coin_value
	var start_angle := randf() * TAU
	for i in pieces:
		var piece_value := int(float(remaining) / (pieces - i))
		remaining -= piece_value
		var coin := coin_scene.instantiate()
		_coins.add_child(coin)
		coin.global_position = pos
		coin.value = piece_value
		var angle := start_angle + TAU * i / pieces + randf_range(-0.3, 0.3)
		var landing := pos + Vector2.from_angle(angle) * randf_range(SPILL_MIN_DIST, SPILL_MAX_DIST)
		# Yatayda düz gider, sprite yukarı sıçrayıp iner (yay gibi görünür)
		var tween := coin.create_tween()
		tween.tween_property(coin, "global_position", landing, SPILL_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		var hop := coin.create_tween()
		hop.tween_property(coin.sprite, "position:y", -SPILL_HOP, SPILL_TIME * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		hop.tween_property(coin.sprite, "position:y", 0.0, SPILL_TIME * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

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
