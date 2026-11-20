extends CanvasLayer

# Test kısayolları. Sadece editörden / debug derlemeden çalıştırınca eklenir (main.gd, OS.is_debug_build());
# Steam'e giden release derlemesinde yoktur. Sağ üstte küçük bir yardım yazısı gösterir.
#   F1: ölümsüzlük aç/kapa (hiç hasar almaz)
#   F2: +1000 altın (mağazada da çalışır)
#   F3: sahnedeki boss'a canının %25'i kadar hasar (ölüm akışını test etmek için)
#   F4: sıradaki boss dalgasına atla (sahnedeki yaratıklar altınsız silinir)
#   F5: test donanımı: o dalgaya normal oyunla gelmiş ortalama bir oyuncunun yapısı (tools/balance_sim.ps1 tahmini):
#       açık en iyi silah (Glock, 10. dalgadan SMG, 20. dalgadan AK47) + ikincil silah; her basışta sırayla katana (K), el bombası (G),
#       ikincilsiz (-: iki Glock/SMG ya da tek AK47). Gümüş mermi (20. dalgadan, sadece ateşli silah), her yuvanın geliştirmeleri
#       dalga x KIT_GUN_PER_WAVE seviye (tek AK47'de x KIT_TWO_HANDED_MULT),
#       Max Health/Regen/Armor dalga x KIT_PLAYER_PER_WAVE seviye (ör. 70. dalgada 23 ve 17)

const BOSS_HIT_RATIO: float = 0.25
const KIT_GUN_PER_WAVE: float = 0.33
const KIT_PLAYER_PER_WAVE: float = 0.25
const KIT_SILVER_WAVE: int = 20
const KIT_TWO_HANDED_MULT: float = 1.5  # tek AK47'de silah geliştirme seviyesi (balance_sim: 70. dalgada ~35)
# F5 her basışta sırayla: katana, el bombası, ikincilsiz (yardım yazısında K / G / -)
const KIT_SECONDARIES: Array[String] = ["res://data/weapons/katana.tres", "res://data/weapons/grenade.tres", ""]
var _kit_index: int = 0
var _kit_label: String = ""

var _label: Label

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS  # mağaza açıkken (oyun dururken) de altın verilebilsin
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.6, 0.85))
	# Sağ üst köşeye yaslı; kutu yazının boyuna göre sola doğru büyür (sabit genişlik yazıyı ekran dışına itiyordu)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -4
	_label.offset_top = 4
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			_toggle_god()
		KEY_F2:
			GameState.add_gold(1000)
		KEY_F3:
			_hit_boss()
		KEY_F4:
			_skip_to_boss()
		KEY_F5:
			_give_kit()
		_:
			return
	get_viewport().set_input_as_handled()

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _toggle_god() -> void:
	var p := _player()
	if p and "debug_god" in p:
		p.debug_god = not p.debug_god
	_update_label()

func _update_label() -> void:
	var p := _player()
	var god: bool = p != null and "debug_god" in p and p.debug_god
	# Tek satır ve kısa: ekranın ortasındaki boss çubuğunun (x 392-632) sağına sığsın (11 px'de karakter 7 px, ~350 px)
	_label.text = "F1 god %s | F2 +1000 | F3 -25%% | F4 boss | F5 kit%s" % ["ON" if god else "off", " " + _kit_label if _kit_label != "" else ""]

func _hit_boss() -> void:
	if get_tree().paused:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.data and e.data.is_boss:
			e.take_damage(maxi(1, roundi(e.max_health * BOSS_HIT_RATIO)))
			return

func _skip_to_boss() -> void:
	if get_tree().paused:
		return
	var wm := get_tree().get_first_node_in_group("wave_manager")
	if wm == null or not wm.wave_active or wm.boss_every <= 0:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()  # die() değil: altın ve ses yok
	for p in get_tree().get_nodes_in_group("enemy_projectile"):
		p.queue_free()
	var next_boss: int = (wm.wave / wm.boss_every + 1) * wm.boss_every
	wm.wave = next_boss - 1
	wm.start_next_wave()

func _give_kit() -> void:
	var wm := get_tree().get_first_node_in_group("wave_manager")
	var wave: int = maxi(wm.wave if wm else 1, 1)
	var gun_levels := roundi(wave * KIT_GUN_PER_WAVE)
	var player_levels := roundi(wave * KIT_PLAYER_PER_WAVE)
	# Her basışta ikincil silah sırayla değişir: katana -> el bombası -> ikincilsiz (Adım 52)
	var secondary_path: String = KIT_SECONDARIES[_kit_index]
	_kit_index = (_kit_index + 1) % KIT_SECONDARIES.size()
	# AK47 kilidi açılmadıysa (unlock_wave) o dalgadaki oyuncu gibi SMG ya da Glock; kilit sayacı dalgaya çekilir
	GameState.cleared_wave = maxi(GameState.cleared_wave, wave - 1)
	var gun := load("res://data/weapons/ak47.tres") as WeaponData
	for path in ["res://data/weapons/smg.tres", "res://data/weapons/glock.tres"]:  # kilitliyse sıradaki en iyi silah
		if GameState.is_weapon_unlocked(gun):
			break
		gun = load(path) as WeaponData
	# Yapı: silah + ikincil; ikincilsizde iki tek elli silah ya da tek iki elli AK47
	var loadout: Array[WeaponData] = [gun]
	if secondary_path != "":
		loadout.append(load(secondary_path) as WeaponData)
	elif gun.hands < 2:
		loadout.append(gun)
	else:
		gun_levels = roundi(wave * KIT_GUN_PER_WAVE * KIT_TWO_HANDED_MULT)  # tek AK47: geliştirmeler tek silahta (balance_sim)
	# Eski yapı silinir (test kısayolu: iade yok), yenisi bedava verilir
	GameState.guns.clear()
	GameState.gun_spent.clear()
	GameState.gun_silver.clear()
	GameState.gun_upgrades.clear()
	for w in loadout:
		GameState.give_weapon(w)
	GameState.add_gold(1000000)
	for slot in GameState.guns.size():
		# Yuvadaki silahın kendi geliştirmeleri (ateşli: Damage/Fire Rate, bomba ve katana: kendi Damage/hız)
		for upgrade in UpgradePool.load_all():
			if upgrade.scope != GameState.guns[slot].upgrade_scope:
				continue
			while GameState.get_gun_upgrade_level(slot, upgrade) < gun_levels:
				if not GameState.buy_gun_upgrade(slot, upgrade):
					break
		if wave >= KIT_SILVER_WAVE and GameState.is_gun_slot(slot) and not GameState.has_silver(slot):
			GameState.buy_silver(slot)
	for path in ["res://data/upgrades/max_health.tres", "res://data/upgrades/regen.tres", "res://data/upgrades/armor.tres"]:
		var upgrade := load(path) as UpgradeData
		while GameState.upgrade_levels.get(upgrade.id, 0) < player_levels:
			if not GameState.buy_upgrade(upgrade):
				break
	GameState.spend_gold(maxi(GameState.gold - 300, 0))
	_kit_label = ["K", "G", "-"][(_kit_index + KIT_SECONDARIES.size() - 1) % KIT_SECONDARIES.size()]
	_update_label()
