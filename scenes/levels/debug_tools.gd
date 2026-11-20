extends CanvasLayer

# Test kısayolları. Sadece editörden / debug derlemeden çalıştırınca eklenir (main.gd, OS.is_debug_build());
# Steam'e giden release derlemesinde yoktur. Sağ üstte küçük bir yardım yazısı gösterir.
#   F1: ölümsüzlük aç/kapa (hiç hasar almaz)
#   F2: +1000 altın (mağazada da çalışır)
#   F3: sahnedeki boss'a canının %25'i kadar hasar (ölüm akışını test etmek için)
#   F4: sıradaki boss dalgasına atla (sahnedeki yaratıklar altınsız silinir)
#   F5: test donanımı: o dalgaya normal oyunla gelmiş ortalama bir oyuncunun yapısı (tools/balance_sim.ps1 tahmini):
#       1 AK47 (iki elli; kilidi açılmadıysa 2 SMG ya da 2 Glock) + gümüş mermi (20. dalgadan), Damage/Fire Rate dalga x KIT_GUN_PER_WAVE seviye,
#       Max Health/Regen/Armor dalga x KIT_PLAYER_PER_WAVE seviye (ör. 70. dalgada 23 ve 17)

const BOSS_HIT_RATIO: float = 0.25
const KIT_GUN_PER_WAVE: float = 0.33
const KIT_PLAYER_PER_WAVE: float = 0.25
const KIT_SILVER_WAVE: int = 20
const KIT_TWO_HANDED_MULT: float = 1.5  # tek AK47'de silah geliştirme seviyesi (balance_sim: 70. dalgada ~35)

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
	_label.text = "F1 god %s | F2 +1000 | F3 -25%% | F4 boss | F5 kit" % ("ON" if god else "off")

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
	# AK47 kilidi açılmadıysa (unlock_wave) o dalgadaki oyuncu gibi SMG ya da Glock; kilit sayacı dalgaya çekilir ki değiştirme çalışsın
	GameState.cleared_wave = maxi(GameState.cleared_wave, wave - 1)
	var ak := load("res://data/weapons/ak47.tres") as WeaponData
	for path in ["res://data/weapons/smg.tres", "res://data/weapons/glock.tres"]:  # kilitliyse sıradaki en iyi silah
		if GameState.is_weapon_unlocked(ak):
			break
		ak = load(path) as WeaponData
	GameState.add_gold(1000000)
	if ak.hands >= 2:
		# İki elli AK47 (Adım 52a): tek AK47, geliştirmeler tek silahta toplandığı için seviyesi ~1.5 kat (balance_sim)
		while GameState.guns.size() > 1:
			GameState.sell_gun(GameState.guns.size() - 1)
		if GameState.guns.is_empty():
			GameState.give_weapon(ak)
		elif GameState.guns[0].id != ak.id:
			GameState.swap_gun(0, ak)
		gun_levels = roundi(wave * KIT_GUN_PER_WAVE * KIT_TWO_HANDED_MULT)
	else:
		for slot in GameState.guns.size():
			if GameState.guns[slot].id != ak.id and GameState.can_swap_gun(slot, ak):
				GameState.swap_gun(slot, ak)
		while GameState.guns.size() < 2 and GameState.can_take_weapon(ak):
			GameState.give_weapon(ak)
	for slot in GameState.guns.size():
		for path in ["res://data/upgrades/gun_damage.tres", "res://data/upgrades/fire_rate.tres"]:
			var upgrade := load(path) as UpgradeData
			while GameState.get_gun_upgrade_level(slot, upgrade) < gun_levels:
				if not GameState.buy_gun_upgrade(slot, upgrade):
					break
		if wave >= KIT_SILVER_WAVE and not GameState.has_silver(slot):
			GameState.buy_silver(slot)
	for path in ["res://data/upgrades/max_health.tres", "res://data/upgrades/regen.tres", "res://data/upgrades/armor.tres"]:
		var upgrade := load(path) as UpgradeData
		while GameState.upgrade_levels.get(upgrade.id, 0) < player_levels:
			if not GameState.buy_upgrade(upgrade):
				break
	GameState.spend_gold(maxi(GameState.gold - 300, 0))
