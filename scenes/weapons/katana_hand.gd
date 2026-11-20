class_name KatanaHand
extends Node2D

# Katana (Adım 52c): ikincil, yakın dövüş silahı. Bomba gibi o el normalde cepte, katana görünmez (Walt'ın duruşu
# saymaz). Menzile (WeaponData.attack_range, oyuncunun merkezinden) yaratık girince el çıkar, katana belirir ve geri çekilir, swing_degrees'lik yay
# boyunca hızla savrulur, arkasında kodla çizilen gümüş-beyaz kesik izi kalır. Savrulma başında yaydaki ve menzildeki
# bütün yaratıklar hasar alır ve geri itilir (boss'lar itilmez). Her kesik bir öncekinin tersi yönde savrulur. Menzilde yaratık kaldıkça katana elde (ucu yukarıda)
# bekler; POCKET_DELAY sn boyunca menzilde kimse yoksa el cebe döner.
# Sahne dosyası yok: GunSlots, WeaponData.hand_script dolu olduğu için gun.tscn yerine bunu kurar.
# Geliştirmeler (yuvaya ait): Damage (damage_multiplier) ve Attack Rate (fire_rate_multiplier).

const REST_LEAN: float = deg_to_rad(30.0)   # elde beklerken bıçak dik yukarı, baktığı yana bu kadar yatık (tutuyor gibi)
const WINDUP_TIME: float = 0.06             # geri çekilme (katana zaten eldeyken)
const DRAW_TIME: float = 0.1               # cepten çıkarken: katana küçükten büyüyerek belirir ve geri çekilir
const POCKET_DELAY: float = 0.4            # menzilde kimse kalmayınca el bu kadar sonra cebe döner
const SWING_TIME: float = 0.1               # savrulma
const RECOVER_TIME: float = 0.16            # boşta duruşa dönüş
const TRAIL_FADE: float = 0.16              # savrulma bitince izin sönmesi
const TRAIL_COLOR: Color = Color(0.85, 0.92, 1.0)
const TRAIL_INNER_RATIO: float = 0.45       # iz bandının iç kenarı (dış kenar = vuruş menzili)
const TRAIL_STEPS: int = 14
const HAND_OFFSET: float = 6.0              # yumruk oyuncu merkezinden yaklaşık bu kadar uzakta (izin dış kenarı menzile otursun)
const HIT_PAD: float = 6.0                  # yaratığın gövdesi: merkezi menzilin bu kadar dışındaysa da vurulur
const SLASH_SOUND: String = "katana_slash"

enum State { REST, WINDUP, SWING, RECOVER }

# GunSlots'un her silaha verdiği alanlar (ateşli silahla aynı arayüz)
var data: WeaponData
var slot: int = -1
var silver: bool = false              # kullanılmaz: gümüş mermi katanaya uygulanmaz
var use_hand_grip: bool = true

var _blade: Node2D                    # dönen kısım (kabza orijinde)
var _sprite: Sprite2D
var _trail: Node2D                    # dönmeyen, toplamalı iz çizimi
var _grip_offset: Vector2
var _state: State = State.REST
var _t: float = 0.0
var _cooldown: float = 0.0
var _rest_dir: Vector2 = Vector2.RIGHT
var _aim_angle: float = 0.0
var _swing_sign: float = 1.0          # +1: saat yönünde, -1: tersi (her kesikte değişir)
var _from: float = 0.0                # savrulmanın başladığı / bittiği açılar
var _to: float = 0.0
var _trail_alpha: float = 0.0
var _player: Node
var _out: bool = false                # el cepten çıkmış, katana görünüyor
var _pocket_timer: float = 0.0
var _windup_time: float = WINDUP_TIME

func setup(weapon_data: WeaponData) -> void:
	data = weapon_data

func setup_orbit(_center: Vector2, _radius: float, _speed: float, _rest_angle: float, _aim_offset: float) -> void:
	pass  # katana çemberde dönmez, hep elde durur

# GunSlots sorar: el cepten çıkmış mı (Walt'ın duruşu ve yumruk ataması buna göre)
func is_held() -> bool:
	return _out

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_blade = Node2D.new()
	add_child(_blade)
	_sprite = Sprite2D.new()
	var tex: Texture2D = data.sprite if data.sprite else data.icon
	_sprite.texture = tex
	_sprite.scale = Vector2.ONE * data.sprite_scale
	var size := tex.get_size()
	var grip := data.grip_point if data.grip_point.x >= 0.0 else Vector2(size.x * 0.15, size.y * 0.5)
	_grip_offset = size * 0.5 - grip  # dönme noktası kabzada
	_sprite.offset = _grip_offset
	_sprite.visible = false
	_blade.add_child(_sprite)

	_trail = Node2D.new()
	_trail.z_as_relative = false
	_trail.z_index = 6  # iz yaratıkların üstünde
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_trail.material = mat
	_trail.draw.connect(_draw_trail)
	add_child(_trail)
	_cooldown = randf() * _interval()

# GunSlots el modunda her karede çağırır: yumruğun konumu, öne/arkaya çizim, bakış yönü
func set_hand(pos: Vector2, front: bool, rest_dir: Vector2) -> void:
	position = pos
	z_index = 1 if front else 0
	_rest_dir = rest_dir

func _physics_process(delta: float) -> void:
	if data == null or (_player and _player.is_dead):
		return
	_cooldown -= delta
	_t += delta
	match _state:
		State.REST:
			_set_blade_angle(_rest_angle())
			var target := _find_target()
			if target:
				_pocket_timer = POCKET_DELAY
				if _cooldown <= 0.0:
					_start_windup(target)
			elif _out:
				_pocket_timer -= delta
				if _pocket_timer <= 0.0:
					_out = false  # el cebe döner
					_sprite.visible = false
		State.WINDUP:
			var k := clampf(_t / _windup_time, 0.0, 1.0)
			_set_blade_angle(lerp_angle(_rest_angle(), _from, k))
			if k >= 1.0:
				_start_swing()
		State.SWING:
			var k := clampf(_t / SWING_TIME, 0.0, 1.0)
			var eased := 1.0 - (1.0 - k) * (1.0 - k)
			_set_blade_angle(_from + (_to - _from) * eased)
			_trail_alpha = 1.0
			if k >= 1.0:
				_state = State.RECOVER
				_t = 0.0
		State.RECOVER:
			var k := clampf(_t / RECOVER_TIME, 0.0, 1.0)
			_set_blade_angle(lerp_angle(_to, _rest_angle(), k))
			if k >= 1.0:
				_state = State.REST
	if _state == State.RECOVER or _state == State.REST:
		_trail_alpha = maxf(_trail_alpha - delta / TRAIL_FADE, 0.0)
	_trail.queue_redraw()

func _rest_angle() -> float:
	# Bıçak ucu yukarıda, baktığı yana hafif yatık (sola bakarken aynalanır; tam kuzey/güneyde sağa yatık)
	return -PI / 2.0 + (REST_LEAN if _rest_dir.x >= -0.01 else -REST_LEAN)

func _set_blade_angle(angle: float) -> void:
	_blade.rotation = angle
	# Sola dönükken kılıç ters görünmesin: dikeyde aynala, kabza noktası da aynalanır
	var left := cos(angle) < 0.0
	_sprite.flip_v = left
	_sprite.offset = Vector2(_grip_offset.x, -_grip_offset.y if left else _grip_offset.y)

func _interval() -> float:
	return 1.0 / maxf(data.fire_rate * GameState.get_gun_multiplier(slot, "fire_rate_multiplier"), 0.01)

func _damage() -> int:
	return maxi(1, roundi(data.damage * GameState.get_gun_multiplier(slot, "damage_multiplier")))

func _center() -> Vector2:
	return (_player as Node2D).global_position if _player else global_position

func _find_target() -> Node2D:
	var center := _center()
	var best: Node2D = null
	var best_d := (data.attack_range + HIT_PAD) * (data.attack_range + HIT_PAD)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_queued_for_deletion():
			continue
		var d := center.distance_squared_to(enemy.global_position)
		if d <= best_d:
			best_d = d
			best = enemy
	return best

func _start_windup(target: Node2D) -> void:
	_aim_angle = _center().direction_to(target.global_position).angle()
	var half := deg_to_rad(data.swing_degrees) * 0.5
	_swing_sign = -_swing_sign
	_from = _aim_angle - half * _swing_sign
	_to = _aim_angle + half * _swing_sign
	_state = State.WINDUP
	_t = 0.0
	_pocket_timer = POCKET_DELAY
	if _out:
		_windup_time = WINDUP_TIME
	else:
		# Cepten çıkıyor: el kalkar, katana küçükten büyüyerek belirir
		_out = true
		_windup_time = DRAW_TIME
		_sprite.visible = true
		_sprite.scale = Vector2.ZERO
		var pop := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(_sprite, "scale", Vector2.ONE * data.sprite_scale, DRAW_TIME)

func _start_swing() -> void:
	_state = State.SWING
	_t = 0.0
	_cooldown = _interval()
	Audio.play_sfx(SLASH_SOUND)
	var center := _center()
	var half := deg_to_rad(data.swing_degrees) * 0.5
	var reach := data.attack_range + HIT_PAD
	var dmg := _damage()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
			continue
		var to_enemy: Vector2 = enemy.global_position - center
		if to_enemy.length() > reach:
			continue
		if absf(angle_difference(_aim_angle, to_enemy.angle())) > half:
			continue
		enemy.take_damage(dmg)
		if enemy.has_method("knockback"):
			enemy.knockback(to_enemy, data.knockback)

# Kesik izi: savrulmanın başından bıçağın şu anki açısına kadar hilal biçimli bant, uca doğru incelir.
# Dış kenar vuruş menziline oturur (yumruktan ölçüldüğü için HAND_OFFSET düşülür).
func _draw_trail() -> void:
	if _trail_alpha <= 0.0:
		return
	var current := _blade.rotation if _state == State.SWING else _to
	var span := current - _from
	if absf(span) < 0.01:
		return
	var outer := maxf(data.attack_range - HAND_OFFSET, 8.0)
	var inner := outer * TRAIL_INNER_RATIO
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	# Dış kenar (baştan uca), sonra iç kenar (uçtan başa); kuyruk saydam, uç parlak
	for i in TRAIL_STEPS + 1:
		var f := float(i) / TRAIL_STEPS
		points.append(Vector2.from_angle(_from + span * f) * outer)
		colors.append(Color(TRAIL_COLOR, _trail_alpha * f * 0.85))
	for i in range(TRAIL_STEPS, -1, -1):
		var f := float(i) / TRAIL_STEPS
		var r := lerpf(outer * 0.96, inner, f)  # kuyrukta ince, uçta kalın (kuyrukta iki nokta çakışmasın)
		points.append(Vector2.from_angle(_from + span * f) * r)
		colors.append(Color(TRAIL_COLOR, _trail_alpha * f * 0.35))
	_trail.draw_polygon(points, colors)
	# Keskin parlak kenar çizgisi
	var edge := PackedVector2Array()
	for i in TRAIL_STEPS + 1:
		edge.append(Vector2.from_angle(_from + span * float(i) / TRAIL_STEPS) * outer)
	_trail.draw_polyline(edge, Color(1.0, 1.0, 1.0, _trail_alpha), 1.0)
