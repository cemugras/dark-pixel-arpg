class_name LavaBurrow
extends Node2D

# Leviathan yerin altındayken zemindeki lav dalgacığı. Sahne dosyası yok, enemy.gd koddan kurar, Main/FloorFx altına
# ekler (zeminin üstünde, yaratıkların ve oyuncunun altında). Çizim tamamen kodla (_draw), toplamalı turuncu parıltı.
# Akış (fazları enemy.gd sürer):
#   MOVE: konumunu her karede boss verir; kaynayan kabarcıklar ve arkasında sönen iz.
#   WARN: start_warning(süre) ile durur; patlama çemberi yanıp söner, içten dolan daire ve büyüyen çatlaklar.
#   BLAST: blast() ile dışa yayılan halka + sıçrayan lav damlaları, sonra yok olur.
# Hasarı enemy.gd verir (patlama karesinde); bu düğüm sadece görüntüdür.

enum Phase { MOVE, WARN, BLAST }

const LAVA_COLOR: Color = Color(1.0, 0.42, 0.08)          # erimiş turuncu
const HOT_COLOR: Color = Color(1.0, 0.85, 0.35)           # patlama anındaki sarımsı beyaz
const MOVE_RADIUS: float = 13.0                           # hareket ederken kaynama alanı
const BUBBLE_INTERVAL: float = 0.05                       # yeni kabarcık aralığı (sn)
const BUBBLE_LIFE: float = 0.35
const TRAIL_STEP: float = 6.0                             # iz noktaları arası mesafe (px)
const TRAIL_LIFE: float = 0.6                             # iz noktasının sönme süresi (sn)
const RING_WIDTH: float = 2.0
const BLINK_SPEED_START: float = 7.0
const BLINK_SPEED_END: float = 24.0
const CRACK_COUNT: int = 7
const BLAST_TIME: float = 0.35
const SPLASH_COUNT: int = 12

var radius: float = 50.0

var _phase: Phase = Phase.MOVE
var _t: float = 0.0            # fazın başından beri geçen süre
var _warn_time: float = 0.6
var _bubble_timer: float = 0.0
var _bubbles: Array = []       # {pos: Vector2 (yerel), age: float, size: float}
var _trail: Array = []         # {pos: Vector2 (global), age: float}
var _last_trail_pos: Vector2 = Vector2.INF
var _crack_angles: Array[float] = []
var _splashes: Array = []      # {dir: Vector2, dist: float, size: float}

func setup(blast_radius: float) -> void:
	radius = blast_radius

func _ready() -> void:
	add_to_group("enemy_projectile")  # boss ölünce silinir (enemy.gd die)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in CRACK_COUNT:
		_crack_angles.append(TAU * i / CRACK_COUNT + randf_range(-0.35, 0.35))

func start_warning(duration: float) -> void:
	_phase = Phase.WARN
	_t = 0.0
	_warn_time = maxf(duration, 0.01)

func blast() -> void:
	_phase = Phase.BLAST
	_t = 0.0
	for i in SPLASH_COUNT:
		_splashes.append({
			"dir": Vector2.RIGHT.rotated(randf() * TAU),
			"dist": randf_range(radius * 0.6, radius * 1.3),
			"size": randf_range(1.5, 3.0),
		})

func _process(delta: float) -> void:
	_t += delta
	_update_bubbles(delta)
	_update_trail(delta)
	if _phase == Phase.BLAST and _t >= BLAST_TIME:
		queue_free()
	queue_redraw()

func _update_bubbles(delta: float) -> void:
	for b in _bubbles:
		b.age += delta
	_bubbles = _bubbles.filter(func(b): return b.age < BUBBLE_LIFE)
	if _phase == Phase.BLAST:
		return
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = BUBBLE_INTERVAL * (0.6 if _phase == Phase.WARN else 1.0)  # uyarıda daha hızlı kaynar
		var area := MOVE_RADIUS if _phase == Phase.MOVE else radius * 0.8
		_bubbles.append({
			"pos": Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf()) * area,
			"age": 0.0,
			"size": randf_range(1.5, 3.5),
		})

func _update_trail(delta: float) -> void:
	for p in _trail:
		p.age += delta
	_trail = _trail.filter(func(p): return p.age < TRAIL_LIFE)
	if _phase == Phase.MOVE and global_position.distance_to(_last_trail_pos) >= TRAIL_STEP:
		_last_trail_pos = global_position
		_trail.append({"pos": global_position, "age": 0.0})

func _draw() -> void:
	# Arkada sönen iz (dünya konumunda saklanır, düğüm hareket ettiği için yerele çevrilir)
	for p in _trail:
		var c := LAVA_COLOR
		c.a = 0.35 * (1.0 - p.age / TRAIL_LIFE)
		draw_circle(to_local(p.pos), MOVE_RADIUS * 0.45, c)

	match _phase:
		Phase.MOVE:
			_draw_move()
		Phase.WARN:
			_draw_warn()
		Phase.BLAST:
			_draw_blast()

	for b in _bubbles:
		var k: float = b.age / BUBBLE_LIFE
		var c := HOT_COLOR
		c.a = 0.8 * (1.0 - k)
		if k < 0.7:
			draw_circle(b.pos, b.size * (0.5 + k), c)
		else:
			draw_arc(b.pos, b.size * 1.6, 0.0, TAU, 8, c, 1.0)  # kabarcık patlıyor

func _draw_move() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	var c := LAVA_COLOR
	c.a = 0.35 + 0.15 * pulse
	draw_circle(Vector2.ZERO, MOVE_RADIUS, c)
	var ring := LAVA_COLOR
	ring.a = 0.6
	draw_arc(Vector2.ZERO, MOVE_RADIUS + 2.0 * pulse, 0.0, TAU, 20, ring, 1.5)

func _draw_warn() -> void:
	var p := clampf(_t / _warn_time, 0.0, 1.0)  # 0 = durdu, 1 = fırlıyor
	var fill := LAVA_COLOR
	fill.a = lerpf(0.12, 0.35, p)
	draw_circle(Vector2.ZERO, radius, fill)
	# İçten dolan daire: kenara değdiği an fırlar
	var inner := LAVA_COLOR
	inner.a = 0.45
	draw_circle(Vector2.ZERO, lerpf(MOVE_RADIUS, radius, p), inner)
	# Merkezden dışa büyüyen çatlaklar
	var crack := HOT_COLOR
	crack.a = 0.7
	for a in _crack_angles:
		var dir := Vector2.RIGHT.rotated(a)
		draw_line(dir * MOVE_RADIUS * 0.5, dir * lerpf(MOVE_RADIUS, radius, p), crack, 1.5)
	# Dış halka: fırlamaya yaklaştıkça hızlanarak yanıp söner
	var ring := LAVA_COLOR
	ring.a = 0.55 + 0.45 * absf(sin(_t * lerpf(BLINK_SPEED_START, BLINK_SPEED_END, p)))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, ring, RING_WIDTH)

func _draw_blast() -> void:
	var b := clampf(_t / BLAST_TIME, 0.0, 1.0)
	var c := HOT_COLOR.lerp(LAVA_COLOR, b)
	c.a = 1.0 - b
	draw_circle(Vector2.ZERO, radius * lerpf(0.9, 1.1, b), Color(c, c.a * 0.6))
	draw_arc(Vector2.ZERO, radius * lerpf(0.9, 1.35, b), 0.0, TAU, 40, c, 3.0 * (1.0 - b) + 1.0)
	for s in _splashes:
		draw_circle(s.dir * s.dist * b, s.size * (1.0 - b * 0.5), c)
