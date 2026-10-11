extends Node

signal gold_changed(amount: int)
signal stats_changed

var gold: int = 0
var stats: PlayerStats = PlayerStats.new()
var upgrade_levels: Dictionary = {}  # geliştirme id -> kaç kez alındı

func _ready() -> void:
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.player_died.connect(reset)

func _on_coin_collected(value: int) -> void:
	add_gold(value)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func get_upgrade_cost(upgrade: UpgradeData) -> int:
	return upgrade.base_cost + upgrade.cost_step * upgrade_levels.get(upgrade.id, 0)

func buy_upgrade(upgrade: UpgradeData) -> bool:
	if not spend_gold(get_upgrade_cost(upgrade)):
		return false

	var current: Variant = stats.get(upgrade.stat)
	if current is int:
		stats.set(upgrade.stat, current + int(upgrade.amount))
	else:
		stats.set(upgrade.stat, current + upgrade.amount)

	upgrade_levels[upgrade.id] = upgrade_levels.get(upgrade.id, 0) + 1
	stats_changed.emit()
	return true

# Yeni oyun: her şeyi sıfırla
func reset() -> void:
	gold = 0
	stats = PlayerStats.new()
	upgrade_levels.clear()
	gold_changed.emit(gold)
	stats_changed.emit()
