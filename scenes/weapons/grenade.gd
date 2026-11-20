class_name Grenade
extends Node2D

# Atılan el bombası (Adım 52b). Sahne dosyası yok, GrenadeHand koddan kurar, Main'e (current_scene) ekler.
# Düğümün konumu bombanın YERDEKİ noktasıdır; yükseklik sprite'ın yukarı kaydırılmasıyla sahte yapılır
# (oyun yukarıdan bakıyor): yerde gölge küçülüp büyür, bomba kavis çizer ve döner.
# Akış: FLY (kavisle uçuş) -> BOUNCE (küçük zıplama) -> FUSE (kırmızı fitil ışığı hızlanarak yanıp söner, yerde
# patlama alanı soluk halka) -> BLAST (yarıçaptaki yaratıklara hasar, parlama + alev topu + halka + kıvılcım + duman,
# kısa ekran sarsıntısı). Oyuncuya hasar vermez. Çizim tamamen kodla (_draw).

const FLIGHT_SPEED: float = 260.0      # px/sn (uçuş süresi mesafeden)
const MIN_FLIGHT: float = 0.3
const MAX_FLIGHT: float = 0.7
const ARC_BASE: float = 12.0           # kavisin tepe yüksekliği: taban + mesafe x oran
const ARC_PER_PX: float = 0.12
const SPIN_SPEED: float = 14.0         # uçarken dönme (radyan/sn)
const BOUNCE_TIME: float = 0.14
const BOUNCE_HEIGHT: float = 4.0
const BLINK_START: float = 8.0         # fitil ışığının yanıp sönme hızı (patlamaya doğru hızlanır)
const BLINK_END: float = 28.0
const FUSE_LIGHT_COLOR: Color = Color(1.0, 0.15, 0.1)
const WARN_COLOR: Color = Color(1.0, 0.45, 0.15, 0.22)   # fitil sırasında yerdeki patlama alanı halkası
const HIT_PAD: float = 6.0             # yaratığın gövdesi: merkezi yarıçapın bu kadar dışındaysa da vurulur

const BLAST_TIME: float = 0.55
const FLASH_TIME: float = 0.08
const FLASH_COLOR: Color = Color(1.0, 0.95, 0.75)
const FIRE_COLOR: Color = Color(1.0, 0.55, 0.15)
const RING_COLOR: Color = Color(1.0, 0.8, 0.35)
const SPARK_COLOR: Color = Color(1.0, 0.75, 0.3)
const SMOKE_COLOR: Color = Color(0.22, 0.2, 0.2, 0.55)
const SPARK_COUNT: int = 12
const SMOKE_COUNT: int = 6
const SHAKE_PX: float = 2.5
const SHAKE_TIME: float = 0.18
const EXPLODE_SOUND: String = "grenade_explode"

enum Phase { FLY, BOUNCE, FUSE, BLAST }

var _phase: Phase = Phase.FLY
var _t: float = 0.0
var _start: Vector2
var _end: Vector2
var _flight: float = 0.5
var _arc: float = 20.0
var _damage: int = 20
var _radius: float = 40.0
var _fuse: float = 0.4
var _height: float = 0.0
var _sprite: Sprite2D
var _glow: Node2D                       # toplamalı (additive) çizim: parlama, alev topu, halka, kıvılcım
var _sparks: Array = []                 # [{pos, vel}]
var _smoke: Array = []                  # [{pos, vel, size}]
var _camera: Camera2D

# Uçuş süresi (GrenadeHand hareket eden hedefin önüne atarken de kullanır)
static func flight_time(distance: float) -> float:
	return clampf(distance / FLIGHT_SPEED, MIN_FLIGHT, MAX_FLIGHT)

func setup(from: Vector2, to: Vector2, dmg: int, radius: float, fuse: float, texture: Texture2D, sprite_scale: float) -> void:
	_start = from
	_end = to
	_damage = dmg
	_radius = radius
	_fuse = fuse
	var dist := from.distance_to(to)
	_flight = flight_time(dist)
	_arc = ARC_BASE + dist * ARC_PER_PX
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.scale = Vector2.ONE * sprite_scale

func _ready() -> void:
	global_position = _start
	z_index = 5  # havadayken yaratıkların üstünde
	add_child(_sprite)
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.FLY:
			var k := clampf(_t / _flight, 0.0, 1.0)
			global_position = _start.lerp(_end, k)
			_height = 4.0 * _arc * k * (1.0 - k)
			_sprite.rotation += SPIN_SPEED * delta
			if k >= 1.0:
				_next(Phase.BOUNCE)
		Phase.BOUNCE:
			var k := clampf(_t / BOUNCE_TIME, 0.0, 1.0)
			_height = 4.0 * BOUNCE_HEIGHT * k * (1.0 - k)
			_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, 0.3)
			if k >= 1.0:
				_height = 0.0
				z_index = 0  # yerde: yaratıklar üstünden geçer
				_next(Phase.FUSE)
		Phase.FUSE:
			if _t >= _fuse:
				_explode()
		Phase.BLAST:
			_update_particles(delta)
			_update_shake()
			if _t >= BLAST_TIME:
				_stop_shake()
				queue_free()
	_sprite.position = Vector2(0.0, -_height)
	queue_redraw()
	_glow.queue_redraw()

func _next(phase: Phase) -> void:
	_phase = phase
	_t = 0.0

func _explode() -> void:
	_next(Phase.BLAST)
	_sprite.visible = false
	z_index = 5  # patlama yaratıkların üstünde
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
			continue
		if global_position.distance_to(enemy.global_position) <= _radius + HIT_PAD:
			enemy.take_damage(_damage)
	for i in SPARK_COUNT:
		var dir := Vector2.from_angle(randf() * TAU)
		_sparks.append({"pos": Vector2.ZERO, "vel": dir * randf_range(80.0, 180.0)})
	for i in SMOKE_COUNT:
		var dir := Vector2.from_angle(randf() * TAU)
		_smoke.append({"pos": dir * randf_range(0.0, _radius * 0.4), "vel": dir * randf_range(8.0, 25.0) + Vector2(0, -18.0),
			"size": randf_range(_radius * 0.18, _radius * 0.3)})
	_camera = get_viewport().get_camera_2d()
	Audio.play_sfx(EXPLODE_SOUND)

func _update_particles(delta: float) -> void:
	for s in _sparks:
		s.pos += s.vel * delta
		s.vel *= 0.9
	for s in _smoke:
		s.pos += s.vel * delta
		s.size += 10.0 * delta

func _update_shake() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	if _t < SHAKE_TIME:
		var strength := SHAKE_PX * (1.0 - _t / SHAKE_TIME)
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	else:
		_stop_shake()

func _stop_shake() -> void:
	if _camera and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
	_camera = null

func _exit_tree() -> void:
	_stop_shake()

# Normal çizim: gölge, fitil ışığı, yerdeki uyarı halkası, duman
func _draw() -> void:
	match _phase:
		Phase.FLY, Phase.BOUNCE, Phase.FUSE:
			# Gölge: bomba yükseldikçe küçülür ve soluklaşır
			var lift := clampf(_height / 40.0, 0.0, 1.0)
			draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, lerpf(4.0, 2.5, lift), Color(0, 0, 0, lerpf(0.4, 0.2, lift)))
			draw_set_transform(Vector2.ZERO)
			if _phase == Phase.FUSE:
				var p := clampf(_t / _fuse, 0.0, 1.0)
				draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, WARN_COLOR, 1.0)
				var c := WARN_COLOR
				c.a *= 0.35 * p
				draw_circle(Vector2.ZERO, _radius * p, c)
		Phase.BLAST:
			var b := clampf(_t / BLAST_TIME, 0.0, 1.0)
			for s in _smoke:
				var c := SMOKE_COLOR
				c.a *= (1.0 - b)
				draw_circle(s.pos, s.size, c)

# Toplamalı çizim: fitil ışığı, parlama, alev topu, genişleyen halka, kıvılcımlar
func _draw_glow() -> void:
	if _phase == Phase.FUSE:
		var p := clampf(_t / _fuse, 0.0, 1.0)
		var speed := lerpf(BLINK_START, BLINK_END, p)
		if sin(_t * speed * TAU * 0.5) > 0.0:
			var top := Vector2(0.0, -_height - _sprite.texture.get_height() * _sprite.scale.y * 0.5)
			_glow.draw_rect(Rect2(top - Vector2(1, 1), Vector2(2, 2)), FUSE_LIGHT_COLOR)
			_glow.draw_circle(top, 3.0, Color(FUSE_LIGHT_COLOR, 0.35))
		return
	if _phase != Phase.BLAST:
		return
	var b := clampf(_t / BLAST_TIME, 0.0, 1.0)
	if _t < FLASH_TIME:
		_glow.draw_circle(Vector2.ZERO, _radius * 0.7, Color(FLASH_COLOR, 1.0 - _t / FLASH_TIME))
	var ease_out := 1.0 - pow(1.0 - b, 3.0)
	_glow.draw_circle(Vector2.ZERO, _radius * lerpf(0.4, 0.9, ease_out), Color(FIRE_COLOR, pow(1.0 - b, 1.5) * 0.8))
	_glow.draw_arc(Vector2.ZERO, _radius * lerpf(0.5, 1.1, ease_out), 0.0, TAU, 48, Color(RING_COLOR, 1.0 - b), 2.0)
	for s in _sparks:
		_glow.draw_rect(Rect2(s.pos - Vector2(1, 1), Vector2(2, 2)), Color(SPARK_COLOR, 1.0 - b))
