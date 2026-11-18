extends Node

signal gold_changed(amount: int)
signal stats_changed
signal weapons_changed

const MAX_GUNS: int = 2  # menzilli silah yuvası sayısı
const SELL_RATIO: float = 0.5  # satışta, o silah için harcanan toplam paranın bu oranı iade edilir
const START_GOLD: int = 0  # başlangıç altını (test için geçici olarak artırılabilir)

var gold: int = START_GOLD
var stats: PlayerStats = PlayerStats.new()
var upgrade_levels: Dictionary = {}  # geliştirme id -> kaç kez alındı
var guns: Array[WeaponData] = []     # takılı menzilli silahlar (yuva sırasıyla)
var cleared_wave: int = 0            # son biten dalga (mağaza silah kilidi WeaponData.unlock_wave buna bakar)

# Satış iadesi için harcama takibi
var gun_spent: Array[int] = []       # guns ile paralel: her yuvadaki silaha ödenen para (gümüş mermi dahil)
var gun_silver: Array[bool] = []     # guns ile paralel: yuvadaki silahta gümüş mermi var mı
var gun_upgrades: Array[Dictionary] = []  # guns ile paralel: yuvadaki silahın geliştirmeleri (scope "gun" geliştirme id -> seviye)

# Gümüş mermi: yuva başına tek seferlik yükseltme. Hasar Damage geliştirmesiyle çarpılır.
# Harcama yuvanın gun_spent'ine eklenir, satışta/değiştirmede %50'si iade edilir; değiştirince gümüş gider.
const SILVER_COST: int = 150  # Adım 43: 100 -> 200 -> 150 (100 çok çabuk güçlendiriyordu, 200 ile 13. dalgada ölündü)
const SILVER_DAMAGE_MULT: float = 2.0
var gun_upgrade_spent: int = 0       # menzilli silahlara bağlı ORTAK geliştirmeler (requires = "gun"); şu an yok (Damage/Fire Rate silah başına, gun_upgrades), ileride ortak bir geliştirme eklenirse son silah satılınca iade edilir

func _ready() -> void:
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.player_died.connect(reset)
	EventBus.wave_ended.connect(_on_wave_ended)

func _on_wave_ended(wave: int) -> void:
	cleared_wave = maxi(cleared_wave, wave)

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
	return _scaled_cost(upgrade, upgrade_levels.get(upgrade.id, 0))

func _scaled_cost(upgrade: UpgradeData, level: int) -> int:
	return ceili((upgrade.base_cost + upgrade.cost_step * level) * upgrade.price_ratio)

# --- Silah başına geliştirmeler (UpgradeData.scope == "gun": Damage, Fire Rate) ---
# Seviye o yuvadaki silaha aittir; harcama yuvanın gun_spent'ine eklenir (satışta %50 iade, değiştirince silahla gider).

func get_gun_upgrade_level(slot: int, upgrade: UpgradeData) -> int:
	if slot < 0 or slot >= gun_upgrades.size():
		return 0
	return gun_upgrades[slot].get(upgrade.id, 0)

func get_gun_upgrade_cost(slot: int, upgrade: UpgradeData) -> int:
	return _scaled_cost(upgrade, get_gun_upgrade_level(slot, upgrade))

func can_buy_gun_upgrade(slot: int, upgrade: UpgradeData) -> bool:
	return slot >= 0 and slot < guns.size() and gold >= get_gun_upgrade_cost(slot, upgrade)

func buy_gun_upgrade(slot: int, upgrade: UpgradeData) -> bool:
	if not can_buy_gun_upgrade(slot, upgrade):
		return false
	var cost := get_gun_upgrade_cost(slot, upgrade)
	if not spend_gold(cost):
		return false
	gun_upgrades[slot][upgrade.id] = get_gun_upgrade_level(slot, upgrade) + 1
	gun_spent[slot] += cost
	stats_changed.emit()
	return true

# Yuvadaki silahın bir istatistik çarpanı (ör. "damage_multiplier", "fire_rate_multiplier"): 1 + seviye x miktar
func get_gun_multiplier(slot: int, stat: String) -> float:
	var mult := 1.0
	if slot < 0 or slot >= gun_upgrades.size():
		return mult
	for upgrade in UpgradePool.load_all():
		if upgrade.scope == "gun" and upgrade.stat == stat:
			mult += upgrade.amount * gun_upgrades[slot].get(upgrade.id, 0)
	return mult

func buy_upgrade(upgrade: UpgradeData) -> bool:
	var cost := get_upgrade_cost(upgrade)
	if not spend_gold(cost):
		return false

	match upgrade.requires:
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

func gun_slots_full() -> bool:
	return guns.size() >= MAX_GUNS

# Silah boş yuva varsa alınır
func can_take_weapon(_weapon: WeaponData) -> bool:
	return not gun_slots_full()

# Ücretsiz verir (başlangıç Glock'u, F5); mağaza buy_weapon kullanır. paid = iade hesabı için ödenen para
func give_weapon(weapon: WeaponData, paid: int = 0) -> void:
	if not can_take_weapon(weapon):
		return
	guns.append(weapon)
	gun_spent.append(paid)
	gun_silver.append(false)
	gun_upgrades.append({})
	weapons_changed.emit()

# Mağaza kilidi: silah unlock_wave. dalga bitince alınabilir (give_weapon bedava verir, kilide bakmaz)
func is_weapon_unlocked(weapon: WeaponData) -> bool:
	return cleared_wave >= weapon.unlock_wave

func buy_weapon(weapon: WeaponData) -> bool:
	if not can_take_weapon(weapon) or not is_weapon_unlocked(weapon) or not spend_gold(weapon.cost):
		return false
	give_weapon(weapon, weapon.cost)
	return true

# --- Satma / değiştirme ---

func weapon_count() -> int:
	return guns.size()

# Son silah satılamaz (oyuncu silahsız kalmasın)
func can_sell_weapon() -> bool:
	return weapon_count() > 1

func _refund(spent: int) -> int:
	return int(spent * SELL_RATIO)

# Yuvadaki silahın iadesi; son menzilli silahsa ortak silah geliştirmeleri (Fire Rate) de dahil
func get_gun_sell_price(slot: int) -> int:
	if slot < 0 or slot >= guns.size():
		return 0
	var spent := gun_spent[slot]
	if guns.size() == 1:
		spent += gun_upgrade_spent
	return _refund(spent)

func sell_gun(slot: int) -> bool:
	if slot < 0 or slot >= guns.size() or not can_sell_weapon():
		return false
	add_gold(get_gun_sell_price(slot))
	guns.remove_at(slot)
	gun_spent.remove_at(slot)
	gun_silver.remove_at(slot)
	gun_upgrades.remove_at(slot)
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
	if slot < 0 or slot >= guns.size():
		return false
	if guns[slot].id == weapon.id or not is_weapon_unlocked(weapon):
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
	gun_silver[slot] = false  # gümüş ve geliştirmeler eski silahla gider (harcamalarının yarısı yukarıda iade edildi)
	gun_upgrades[slot] = {}
	weapons_changed.emit()
	return true

# --- Gümüş mermi ---

func has_silver(slot: int) -> bool:
	return slot >= 0 and slot < gun_silver.size() and gun_silver[slot]

func can_buy_silver(slot: int) -> bool:
	return slot >= 0 and slot < guns.size() and not has_silver(slot) and gold >= SILVER_COST

func buy_silver(slot: int) -> bool:
	if not can_buy_silver(slot) or not spend_gold(SILVER_COST):
		return false
	gun_silver[slot] = true
	gun_spent[slot] += SILVER_COST
	weapons_changed.emit()  # silahlar yeniden kurulur, yeni mermiyle ateş eder
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

# Geliştirmenin ön koşulu: "gun" = en az bir menzilli silah gerekli
func meets_requirement(requirement: String) -> bool:
	match requirement:
		"gun":
			return not guns.is_empty()
	return true

# Yeni oyun: her şeyi sıfırla
func reset() -> void:
	gold = START_GOLD
	stats = PlayerStats.new()
	upgrade_levels.clear()
	guns.clear()
	gun_spent.clear()
	gun_silver.clear()
	gun_upgrades.clear()
	gun_upgrade_spent = 0
	cleared_wave = 0
	gold_changed.emit(gold)
	stats_changed.emit()
	weapons_changed.emit()
