extends Node

signal gold_changed(amount: int)
signal stats_changed
signal weapons_changed

const MAX_GUNS: int = 2  # menzilli silah yuvası sayısı
const SELL_RATIO: float = 0.5  # satışta, o silah için harcanan toplam paranın bu oranı iade edilir

var gold: int = 0
var stats: PlayerStats = PlayerStats.new()
var upgrade_levels: Dictionary = {}  # geliştirme id -> kaç kez alındı
var guns: Array[WeaponData] = []     # takılı menzilli silahlar (yuva sırasıyla)

# Satış iadesi için harcama takibi
var gun_spent: Array[int] = []       # guns ile paralel: her yuvadaki silaha ödenen para
var sword_spent: int = 0             # kılıç fiyatı + kılıca bağlı geliştirmeler (requires = "sword")
var gun_upgrade_spent: int = 0       # menzilli silahlara bağlı ortak geliştirmeler (requires = "gun"); son silah satılınca iade edilir

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
	var cost := get_upgrade_cost(upgrade)
	if not spend_gold(cost):
		return false

	match upgrade.requires:
		"sword":
			sword_spent += cost
		"gun":
			gun_upgrade_spent += cost

	_add_stat(upgrade.stat, upgrade.amount)
	upgrade_levels[upgrade.id] = upgrade_levels.get(upgrade.id, 0) + 1
	stats_changed.emit()
	return true

func _add_stat(stat: String, amount: float) -> void:
	var current: Variant = stats.get(stat)
	if current is int:
		stats.set(stat, current + int(amount))
	else:
		stats.set(stat, current + amount)

func has_sword() -> bool:
	return stats.sword_count > 0

func gun_slots_full() -> bool:
	return guns.size() >= MAX_GUNS

# Kılıç bir kez alınır; menzilli silah boş yuva varsa alınır
func can_take_weapon(weapon: WeaponData) -> bool:
	if weapon.is_melee:
		return not has_sword()
	return not gun_slots_full()

# Ücretsiz verir (başlangıç seçimi); mağaza buy_weapon kullanır. paid = iade hesabı için ödenen para
func give_weapon(weapon: WeaponData, paid: int = 0) -> void:
	if not can_take_weapon(weapon):
		return
	if weapon.is_melee:
		stats.sword_count = 1
		sword_spent = paid
		stats_changed.emit()
	else:
		guns.append(weapon)
		gun_spent.append(paid)
	weapons_changed.emit()

func buy_weapon(weapon: WeaponData) -> bool:
	if not can_take_weapon(weapon) or not spend_gold(weapon.cost):
		return false
	give_weapon(weapon, weapon.cost)
	return true

# --- Satma / değiştirme ---

func weapon_count() -> int:
	return guns.size() + (1 if has_sword() else 0)

# Son silah satılamaz (oyuncu silahsız kalmasın)
func can_sell_weapon() -> bool:
	return weapon_count() > 1

func _refund(spent: int) -> int:
	return int(spent * SELL_RATIO)

# Kılıç iadesi: kılıç + kılıç geliştirmeleri (Extra Sword, Spin Speed) harcamasının yarısı
func get_sword_sell_price() -> int:
	return _refund(sword_spent)

# Yuvadaki silahın iadesi; son menzilli silahsa ortak silah geliştirmeleri (Fire Rate) de dahil
func get_gun_sell_price(slot: int) -> int:
	if slot < 0 or slot >= guns.size():
		return 0
	var spent := gun_spent[slot]
	if guns.size() == 1:
		spent += gun_upgrade_spent
	return _refund(spent)

func sell_sword() -> bool:
	if not has_sword() or not can_sell_weapon():
		return false
	add_gold(get_sword_sell_price())
	_reset_upgrades_requiring("sword")
	stats.sword_count = 0
	sword_spent = 0
	stats_changed.emit()
	weapons_changed.emit()
	return true

func sell_gun(slot: int) -> bool:
	if slot < 0 or slot >= guns.size() or not can_sell_weapon():
		return false
	add_gold(get_gun_sell_price(slot))
	guns.remove_at(slot)
	gun_spent.remove_at(slot)
	if guns.is_empty():
		_reset_upgrades_requiring("gun")
		gun_upgrade_spent = 0
		stats_changed.emit()
	weapons_changed.emit()
	return true

# Değiştirme: yuvadaki silah satılır, yerine yenisi aynı yuvaya alınır.
# Ortak geliştirmeler korunur (yuva boşalmıyor). Net fiyat negatifse fark oyuncuya verilir.
func get_swap_cost(slot: int, weapon: WeaponData) -> int:
	return weapon.cost - _refund(gun_spent[slot])

func can_swap_gun(slot: int, weapon: WeaponData) -> bool:
	if weapon.is_melee or slot < 0 or slot >= guns.size():
		return false
	if guns[slot].id == weapon.id:
		return false
	return gold >= get_swap_cost(slot, weapon)

func swap_gun(slot: int, weapon: WeaponData) -> bool:
	if not can_swap_gun(slot, weapon):
		return false
	var net := get_swap_cost(slot, weapon)
	if net >= 0:
		spend_gold(net)
	else:
		add_gold(-net)
	guns[slot] = weapon
	gun_spent[slot] = weapon.cost
	weapons_changed.emit()
	return true

# Silah satılınca ona bağlı geliştirmelerin seviyesi ve etkisi geri alınır
func _reset_upgrades_requiring(requirement: String) -> void:
	for upgrade in UpgradePool.load_all():
		if upgrade.requires != requirement:
			continue
		var level: int = upgrade_levels.get(upgrade.id, 0)
		if level > 0:
			_add_stat(upgrade.stat, -upgrade.amount * level)
		upgrade_levels.erase(upgrade.id)

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
	gun_spent.clear()
	sword_spent = 0
	gun_upgrade_spent = 0
	gold_changed.emit(gold)
	stats_changed.emit()
	weapons_changed.emit()
