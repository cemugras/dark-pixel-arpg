class_name GrenadeHand
extends Node2D

# El bombası (Adım 52b): ikincil silah. Bomba elde durmaz: o el cepte kalır (Walt'ın duruşu bu yuvayı saymaz).
# Bekleme bitip menzile (WeaponData.attack_range) yaratık girince el kalkar (GunSlots is_held ile duruşu bir kol
# fazlasına geçirir: Aim One -> Aim Two, silahsızsa eller cepte -> Aim One), elde bomba kısa süre görünür, en kalabalık
# noktaya atılır, el biraz sonra cebe döner. Sahne dosyası yok: GunSlots, WeaponData.hand_script dolu olduğu için
# gun.tscn yerine bunu kurar. Uçuş, fitil ve patlama Grenade'de (grenade.gd).
# Geliştirmeler (yuvaya ait): Damage (damage_multiplier) ve Fire Rate (fire_rate_multiplier).

const RAISE_TIME: float = 0.18        # el kalkıp bomba elde görünür, sonra atılır
const FOLLOW_TIME: float = 0.15       # atıştan sonra el cebe dönmeden önce
const LEAD_RATIO: float = 0.6         # hareket eden hedefin önüne atma payı (uçuş süresi x hız x bu)
const CLUSTER_PAD: float = 6.0        # kalabalık sayarken yarıçapa eklenen pay (yaratığın gövdesi)

enum State { POCKET, RAISE, FOLLOW }

# GunSlots'un her silaha verdiği alanlar (ateşli silahla aynı arayüz)
var data: WeaponData
var slot: int = -1
var silver: bool = false              # kullanılmaz: gümüş mermi bombaya uygulanmaz
var use_hand_grip: bool = true

var _sprite: Sprite2D
var _state: State = State.POCKET
var _timer: float = 0.0
var _cooldown: float = 0.0
var _aim: Vector2 = Vector2.INF
var _player: Node

func setup(weapon_data: WeaponData) -> void:
	data = weapon_data

func setup_orbit(_center: Vector2, _radius: float, _speed: float, _rest_angle: float, _aim_offset: float) -> void:
	pass  # bomba çemberde dönmez

# GunSlots sorar: el şu an cepten çıkmış mı (Walt'ın duruşu ve yumruk ataması buna göre)
func is_held() -> bool:
	return _state != State.POCKET

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_sprite = Sprite2D.new()
	_sprite.texture = data.sprite if data.sprite else data.icon
	_sprite.scale = Vector2.ONE * data.sprite_scale
	_sprite.visible = false
	add_child(_sprite)
	_cooldown = _interval() * 0.5  # dalga başında hemen atmasın

# GunSlots el modunda her karede çağırır: yumruğun konumu, öne/arkaya çizim
func set_hand(pos: Vector2, front: bool, _rest_dir: Vector2) -> void:
	position = pos
	z_index = 1 if front else 0

func _physics_process(delta: float) -> void:
	if data == null or (_player and _player.is_dead):
		return
	match _state:
		State.POCKET:
			_cooldown -= delta
			if _cooldown > 0.0:
				return
			_aim = _pick_target()
			if _aim == Vector2.INF:
				return
			_state = State.RAISE
			_timer = RAISE_TIME
			_sprite.visible = true
		State.RAISE:
			_timer -= delta
			if _timer > 0.0:
				return
			var fresh := _pick_target()  # kalkarken hedef ölmüş/kaçmış olabilir
			_throw(fresh if fresh != Vector2.INF else _aim)
			_cooldown = _interval()
			_state = State.FOLLOW
			_timer = FOLLOW_TIME
		State.FOLLOW:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.POCKET

func _interval() -> float:
	return 1.0 / maxf(data.fire_rate * GameState.get_gun_multiplier(slot, "fire_rate_multiplier"), 0.01)

func _damage() -> int:
	return maxi(1, roundi(data.damage * GameState.get_gun_multiplier(slot, "damage_multiplier")))

# Menzildeki yaratıklardan çevresinde en çok yaratık olanı (patlama yarıçapında); eşitse en yakını.
# Dönen değer atış noktası (hareket edenin biraz önü), menzilde kimse yoksa Vector2.INF.
func _pick_target() -> Vector2:
	var center := (_player as Node2D).global_position if _player else global_position
	var max_d := data.attack_range * data.attack_range
	var in_range: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_queued_for_deletion():
			continue
		if center.distance_squared_to(enemy.global_position) <= max_d:
			in_range.append(enemy)
	if in_range.is_empty():
		return Vector2.INF
	var all := get_tree().get_nodes_in_group("enemy")
	var cluster_d := (data.blast_radius + CLUSTER_PAD) * (data.blast_radius + CLUSTER_PAD)
	var best: Node2D = null
	var best_count := -1
	var best_dist := INF
	for e in in_range:
		var count := 0
		for other in all:
			if e.global_position.distance_squared_to(other.global_position) <= cluster_d:
				count += 1
		var dist := center.distance_squared_to(e.global_position)
		if count > best_count or (count == best_count and dist < best_dist):
			best = e
			best_count = count
			best_dist = dist
	var aim := best.global_position
	var vel: Variant = best.get("velocity")
	if vel is Vector2:
		aim += vel * Grenade.flight_time(global_position.distance_to(aim)) * LEAD_RATIO
	return aim

func _throw(target: Vector2) -> void:
	var grenade := Grenade.new()
	grenade.setup(global_position, target, _damage(), data.blast_radius, data.fuse_time, _sprite.texture, data.sprite_scale)
	get_tree().current_scene.add_child(grenade)
	_sprite.visible = false
	Audio.play_sfx(data.shoot_sound)
