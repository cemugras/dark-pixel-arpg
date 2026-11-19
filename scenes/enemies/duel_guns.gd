class_name DuelGuns
extends Node2D

# Azazel'in etrafında havada süzülen iki silah (düello atışı, bkz. EnemyData duel_*). Sahne dosyası yok, enemy.gd
# yaratığın çocuğu olarak ekler. duel_weapon doluysa iki silah da odur (Azazel: iki mızrak); boşsa oyuncunun o an
# taşıdığı silahların kopyası (GameState.guns; tek silah varsa ikisi de aynı). Görüntü, ağız ateşi ve ses silahtan,
# hasar ve mermi sayısı EnemyData'dan.
#
# Akış: hep oyuncuya döner -> aim(): kızıl nişan çizgileri track sn oyuncuyu izler, lock sn kilitlenir (parlar; 0 ise
# kilit yok) -> fire(): iki silah sırayla mermi atar; duel_follow_fire açıksa seri boyunca da oyuncuyu izler (durmadan
# kaçmak gerekir), kapalıysa kilitli hatlar boyunca -> silahlar soğur (gri), cool sn içinde kızıllığa döner.
#
# Çizim sırası: kendisi boss sprite'ının önünde (öndeki silahlar + çizgiler); kuzeye nişan alırken silah,
# yaratığın sprite'ından önce eklenen _back düğümüne taşınır ve gövdenin arkasında kalır.

const CENTER: Vector2 = Vector2(0.0, -8.0)          # silah çemberinin merkezi (göğüs hizası, gövde merkezine göre)
const PAIR_ANGLE: float = 0.96                      # ~55 derece; silahlar nişan yönünün iki yanında bu açıda durur
const TURN_SPEED: float = 7.0                       # bakış dönme hızı (rad/sn)
const BOB_AMOUNT: float = 2.0                       # havada süzülme (px)
const BOB_SPEED: float = 2.4
const HOT_COLOR: Color = Color(1.35, 0.85, 0.65)    # kızgın demir
const COLD_COLOR: Color = Color(0.5, 0.5, 0.58)     # seriden sonra soğumuş (vurma penceresi)
const LINE_COLOR: Color = Color(1.0, 0.15, 0.08)
const LINE_TRACK_ALPHA: float = 0.35
const LINE_LOCK_ALPHA: float = 0.9
const FLASH_TIME: float = 0.05
const RECOIL_PX: float = 4.0
const SHOT_PITCH: float = 0.75                      # oyuncunun silah sesinin kalın hâli
const BACK_THRESHOLD: float = -0.35                 # nişan yönünün y'si bunun altındaysa (kuzey) silah gövdenin arkasında
const MOVE_RATE: float = 12.0                       # elden nişana / nişandan ele geçiş hızı (büyüdükçe daha çabuk)
# Elde dik dururken yumrukların konumu (gövde merkezine göre px, Azazel'in duruş karelerinden ölçüldü) ve gövdenin
# arkasında kalıp kalmadığı; doğu tarafı yönleri, batı aynalanır (_hand_points)
const DIR_NAMES: Array[String] = [  # enemy.gd DIR8_NAMES ile aynı sıra (_dir8_idx)
	"east", "south_east", "south", "south_east", "east", "north_east", "north", "north_east"
]
const HAND_POINTS: Dictionary = {
	"south": [[Vector2(-28, 13), false], [Vector2(18, 13), false]],
	"south_east": [[Vector2(-18, 16), false], [Vector2(25, 10), false]],
	"east": [[Vector2(-3, 16), false], [Vector2(6, 13), true]],
	"north_east": [[Vector2(-16, 12), true], [Vector2(20, 12), true]],
	"north": [[Vector2(-24, 12), true], [Vector2(24, 12), true]],
}

enum Phase { IDLE, TRACK, LOCK, FIRE, COOL }

var _data: EnemyData
var _damage: int = 0
var _target: Node2D = null
var _guns: Array[Dictionary] = []   # her silah: weapon, holder (Node2D), sprite, flash, muzzle (yerel), dir
var _back: Node2D = null
var _phase: Phase = Phase.IDLE
var _timer: float = 0.0
var _aim_angle: float = 0.0
var _shots_left: int = 0
var _shot_timer: float = 0.0
var _next_gun: int = 0
var _bob_time: float = 0.0

func setup(enemy_data: EnemyData, damage: int) -> void:
	_data = enemy_data
	_damage = damage

func _ready() -> void:
	_target = get_tree().get_first_node_in_group("player")
	_back = Node2D.new()
	_back.name = "DuelGunsBack"
	get_parent().add_child.call_deferred(_back)
	get_parent().move_child.call_deferred(_back, 0)  # yaratığın sprite'ından önce çizilir
	var weapons := _copied_weapons()
	for i in clampi(_data.duel_gun_count, 1, 2):
		_guns.append(_build_gun(weapons[i], i))
	if _guns.size() == 1:
		_guns[0]["side"] = 0.0  # tek silah nişan yönünün tam önünde
	if _target:
		_aim_angle = (_target.global_position - global_position).angle()
	_place_guns(0.0, true)  # delta 0: geçiş olmadan doğrudan yerine

func _copied_weapons() -> Array[WeaponData]:
	var list: Array[WeaponData] = []
	if _data.duel_weapon:
		list.append(_data.duel_weapon)
		list.append(_data.duel_weapon)
		return list
	for w in GameState.guns:
		if w:
			list.append(w)
	if list.is_empty() and _data.duel_fallback_weapon:
		list.append(_data.duel_fallback_weapon)
	if list.is_empty():
		list.append(preload("res://data/weapons/glock.tres"))
	if list.size() == 1:
		list.append(list[0])
	return list

func _build_gun(weapon: WeaponData, index: int) -> Dictionary:
	var holder := Node2D.new()  # konum + dönme; sprite kabza origin'de olacak şekilde kayık
	add_child(holder)
	var tex: Texture2D = weapon.sprite if weapon.sprite else weapon.icon
	var size := Vector2(tex.get_width(), tex.get_height())
	var grip := weapon.grip_point if weapon.grip_point.x >= 0.0 else size * Vector2(0.3, 0.65)
	var tip := weapon.muzzle_point if weapon.muzzle_point.x >= 0.0 else Vector2(size.x, size.y * 0.3)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = -grip
	s.scale = Vector2.ONE * _data.duel_gun_scale
	s.modulate = HOT_COLOR
	s.visible = _data.duel_show_weapon  # kapalıysa silah yaratığın kendi sprite'ında (Grigori'nin elindeki mızrak)
	holder.add_child(s)
	var flash: Sprite2D = null
	if weapon.muzzle_flash:
		flash = Sprite2D.new()
		flash.texture = weapon.muzzle_flash
		flash.hframes = maxi(weapon.muzzle_flash_frames, 1)
		flash.centered = false
		flash.position = tip - grip
		flash.offset = Vector2(0.0, -weapon.muzzle_flash.get_height() * 0.5)
		flash.modulate = Color(1.6, 0.7, 0.4)
		flash.visible = false
		s.add_child(flash)
	return {
		"weapon": weapon, "holder": holder, "sprite": s, "flash": flash, "flash_timer": 0.0,
		"muzzle": (tip - grip), "side": -1.0 if index == 0 else 1.0, "dir": Vector2.RIGHT, "back": false,
	}

# --- Enemy'nin çağırdıkları ---
func aim() -> void:
	_phase = Phase.TRACK
	_timer = _data.duel_track_time

func fire() -> void:
	_phase = Phase.FIRE
	_shots_left = _data.duel_shots * _guns.size()
	_shot_timer = 0.0
	_next_gun = randi() % _guns.size()

# Seri bitti mi (enemy toparlanmaya bunu bekleyerek geçer)
func is_busy() -> bool:
	return _phase == Phase.TRACK or _phase == Phase.LOCK or _phase == Phase.FIRE

func _physics_process(delta: float) -> void:
	_bob_time += delta
	match _phase:
		Phase.IDLE:
			_turn_toward_target(delta)
			_place_guns(delta, true)
		Phase.TRACK:
			_turn_toward_target(delta)
			_place_guns(delta, true)
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.LOCK
				_timer = _data.duel_lock_time
		Phase.LOCK:
			_place_guns(delta, false)  # yön kilitli
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.FIRE  # enemy fire() çağırana kadar bekleme olmasın diye doğrudan ateşe geçer
				fire()
		Phase.FIRE:
			if _data.duel_follow_fire:
				_turn_toward_target(delta)
			_place_guns(delta, _data.duel_follow_fire)
			_shot_timer -= delta
			while _shot_timer <= 0.0 and _shots_left > 0:
				_shoot(_guns[_next_gun])
				_next_gun = (_next_gun + 1) % _guns.size()
				_shots_left -= 1
				_shot_timer += _data.duel_shot_gap
			if _shots_left <= 0:
				_phase = Phase.COOL
				_timer = _data.duel_recover
				for g in _guns:
					g["sprite"].modulate = COLD_COLOR
		Phase.COOL:
			_turn_toward_target(delta)
			_place_guns(delta, true)
			_timer -= delta
			var t := 1.0 - clampf(_timer / maxf(_data.duel_recover, 0.01), 0.0, 1.0)
			for g in _guns:
				g["sprite"].modulate = COLD_COLOR.lerp(HOT_COLOR, t * t)
			if _timer <= 0.0:
				_phase = Phase.IDLE
	for g in _guns:
		if g["flash"] and g["flash_timer"] > 0.0:
			g["flash_timer"] -= delta
			if g["flash_timer"] <= 0.0:
				g["flash"].visible = false
	queue_redraw()

func _turn_toward_target(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var want := (_target.global_position - (global_position + CENTER)).angle()
	_aim_angle = rotate_toward(_aim_angle, want, TURN_SPEED * delta)

# Silahları yerleştirir. Nişan alırken (TRACK/LOCK/FIRE) nişan yönünün iki yanında süzülür, follow true ise her silah
# oyuncuya kendi namlusundan bakar. duel_rest_upright açıksa boştayken (IDLE/COOL) ellerde dik durur (Azazel'in
# mızrakları; el konumları gövdenin baktığı yöne göre HAND_POINTS). Geçişler yumuşak (MOVE_RATE).
func _place_guns(delta: float, follow: bool) -> void:
	var aiming := _phase == Phase.TRACK or _phase == Phase.LOCK or _phase == Phase.FIRE
	var rest := _data.duel_rest_upright and not aiming
	var hands := _hand_points() if rest else []
	var bob := Vector2(0.0, sin(_bob_time * BOB_SPEED) * BOB_AMOUNT)
	var k := 1.0 - exp(-MOVE_RATE * delta) if delta > 0.0 else 1.0
	for i in _guns.size():
		var g := _guns[i]
		var holder: Node2D = g["holder"]
		var want_pos: Vector2
		var want_angle: float
		var back: bool
		if rest:
			want_pos = hands[i][0]
			want_angle = -PI / 2.0  # uç yukarıda
			back = hands[i][1]
		else:
			want_pos = CENTER + Vector2.from_angle(_aim_angle + PAIR_ANGLE * g["side"]) * _data.duel_orbit_radius + bob
			if follow:
				var dir := Vector2.from_angle(_aim_angle)
				if is_instance_valid(_target):
					var to := _target.global_position - (global_position + want_pos)
					if to.length() > 1.0:
						dir = to.normalized()
				g["dir"] = dir
			var d: Vector2 = g["dir"]
			want_angle = d.angle()
			back = d.y < BACK_THRESHOLD
		holder.position = holder.position.lerp(want_pos, k)
		holder.rotation = lerp_angle(holder.rotation, want_angle, k)
		# Sola bakarken ters dönmesin: dikeyde aynalanır (kabza aşağıda kalır)
		g["sprite"].scale.y = _data.duel_gun_scale * (-1.0 if cos(holder.rotation) < -0.05 else 1.0)
		_set_back(g, back)

# Gövdenin baktığı yöne göre iki elin konumu ve gövdenin arkasında kalıp kalmadığı: [[konum, arkada], [konum, arkada]].
# Batı tarafı doğu tarafının aynası (x ters, eller yer değiştirir).
func _hand_points() -> Array:
	var enemy := get_parent()
	var idx: int = enemy._dir8_idx if "_dir8_idx" in enemy else 2
	var flip: bool = enemy.sprite.flip_h if "sprite" in enemy and enemy.sprite else false
	var pts: Array = HAND_POINTS.get(DIR_NAMES[wrapi(idx, 0, 8)], HAND_POINTS["south"])
	if not flip:
		return pts
	return [[Vector2(-pts[1][0].x, pts[1][0].y), pts[1][1]], [Vector2(-pts[0][0].x, pts[0][0].y), pts[0][1]]]

func _set_back(g: Dictionary, back: bool) -> void:
	if g["back"] == back or not is_instance_valid(_back) or not _back.is_inside_tree():
		return
	g["back"] = back
	var holder: Node2D = g["holder"]
	holder.reparent(_back if back else self, false)

func _muzzle_global(g: Dictionary) -> Vector2:
	var s: Sprite2D = g["sprite"]
	return s.to_global(g["muzzle"])

func _shoot(g: Dictionary) -> void:
	if not is_inside_tree():
		return
	var d: Vector2 = g["dir"]
	var angle := d.angle() + deg_to_rad(randf_range(-_data.duel_spread_degrees, _data.duel_spread_degrees))
	var b := HellBullet.new()
	b.setup(_damage, _data.duel_bullet_speed, _data.duel_bullet_distance, angle)
	b.position = _muzzle_global(g)
	# Yaratığın ebeveyninde (WaveManager) doğar, boss ölse de uçmaya devam eder (die() havadakileri siler)
	get_parent().get_parent().add_child(b)
	var flash: Sprite2D = g["flash"]
	if flash:
		flash.frame = randi() % flash.hframes
		flash.visible = true
		g["flash_timer"] = FLASH_TIME
	var s: Sprite2D = g["sprite"]
	var tw := s.create_tween()
	s.position = Vector2(-RECOIL_PX, 0.0)
	tw.tween_property(s, "position", Vector2.ZERO, _data.duel_shot_gap * 1.6)
	var weapon: WeaponData = g["weapon"]
	var p := Audio.play_sfx(weapon.shoot_sound, _data.duel_shot_db)
	if p:
		p.pitch_scale *= SHOT_PITCH

# Nişan çizgileri (izlerken soluk ve titrek, kilitliyken parlak ve kalın)
func _draw() -> void:
	var firing_follow := _phase == Phase.FIRE and _data.duel_follow_fire
	if _phase != Phase.TRACK and _phase != Phase.LOCK and not firing_follow:
		return
	# Küçük yaratıkta (body_scale 0.5) düğüm de ölçekli: çizgi boyu ve kalınlığı ekranda aynı kalsın diye düzeltilir
	var k := 1.0 / maxf(get_global_transform().get_scale().x, 0.01)
	for g in _guns:
		var from := to_local(_muzzle_global(g))
		var d: Vector2 = g["dir"]
		var to := from + d * _data.duel_bullet_distance * k
		if _phase == Phase.TRACK:
			var t := 1.0 - _timer / maxf(_data.duel_track_time, 0.01)
			if _data.duel_lock_time <= 0.0:
				t = maxf(t, 0.6)  # kilit yoksa izlerken de belirgin olsun (ateş yaklaşıyor)
			var c := LINE_COLOR
			c.a = LINE_TRACK_ALPHA * (0.6 + 0.4 * t) * (0.75 + 0.25 * sin(_bob_time * 40.0))
			draw_line(from, to, c, 1.0 * k)
		else:
			var c := LINE_COLOR
			c.a = LINE_LOCK_ALPHA
			draw_line(from, to, Color(c, 0.3), 4.0 * k)
			draw_line(from, to, c, 2.0 * k)
			draw_line(from, to, Color(1.0, 0.75, 0.6, 0.9), 1.0 * k)
