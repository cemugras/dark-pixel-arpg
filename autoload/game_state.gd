extends Node

signal gold_changed(amount: int)
signal stats_changed
signal weapons_changed

const MAX_GUNS: int = 2  # menzilli silah yuvası sayısı

var gold: int = 0
var stats: PlayerStats = PlayerStats.new()
var upgrade_levels: Dictionary = {}  # geliştirme id -> kaç kez alındı
var guns: Array[WeaponData] = []     # takılı menzilli silahlar (yuva sırasıyla)

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

func has_sword() -> bool:
	return stats.sword_count > 0

func gun_slots_full() -> bool:
	return guns.size() >= MAX_GUNS

# Kılıç bir kez alınır; menzilli silah boş yuva varsa alınır
func can_take_weapon(weapon: WeaponData) -> bool:
	if weapon.is_melee:
		return not has_sword()
	return not gun_slots_full()

# Ücretsiz verir (başlangıç seçimi); mağaza buy_weapon kullanır
func give_weapon(weapon: WeaponData) -> void:
	if not can_take_weapon(weapon):
		return
	if weapon.is_melee:
		stats.sword_count = 1
		stats_changed.emit()
	else:
		guns.append(weapon)
	weapons_changed.emit()

func buy_weapon(weapon: WeaponData) -> bool:
	if not can_take_weapon(weapon) or not spend_gold(weapon.cost):
		return false
	give_weapon(weapon)
	return true

# Geliştirmenin ön koşulu: "sword" = kılıç gerekli, "gun" = en az bir menzilli silah gerekli
func meets_requirement(requirement: String) -> bool:
	match requirement:
		"sword":
			return has_sword()
		"gun":
			return not guns.is_empty()
	return true

# Yeni oyun: her şeyi sıfırla
func reset() -> void:
	gold = 0
	stats = PlayerStats.new()
	upgrade_levels.clear()
	guns.clear()
	gold_changed.emit(gold)
	stats_changed.emit()
	weapons_changed.emit()
