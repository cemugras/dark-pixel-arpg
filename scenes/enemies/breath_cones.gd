class_name BreathCones
extends Node2D

# Asmodeus'un üç başının nefesi: boss'un etrafında eşit aralıklı koniler. Sahne dosyası yok, enemy.gd koddan kurar,
# Main/FloorFx altına ekler (zeminde, yaratıkların ve oyuncunun altında). Çizim tamamen kodla (_draw), toplamalı renk.
# Akış: windup sn soluk uyarı (koniler dönmez, kenarları yanıp söner) -> duration sn nefes (koniler döner, içleri dolu,
# dışa akan alev puslari; içinde kalan oyuncuya try_hit) -> kısa sönme, yok olur.

const DEFAULT_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.1),    # boğa başı: kızıl ateş
	Color(0.7, 0.3, 1.0),    # taçlı baş: mor
	Color(0.35, 1.0, 0.25),  # koç başı: zehir yeşili
]
const ARC_STEPS: int = 10             # koni yayının nokta sayısı
const WARN_FILL_ALPHA: float = 0.10
const WARN_EDGE_ALPHA: float = 0.55
const FIRE_FILL_ALPHA: float = 0.32
const FIRE_CORE_ALPHA: float = 0.40
const FIRE_CORE_RATIO: float = 0.45   # parlak çekirdeğin koni açısına oranı
const PUFF_INTERVAL: float = 0.03     # her koniden yeni alev pusu aralığı (sn)
const PUFF_SPEED: float = 260.0       # pusların dışa akış hızı (px/sn)
const FADE_TIME: float = 0.2
const START_RADIUS: float = 10.0      # koninin başladığı uzaklık (boss'un gövdesinin içinden)
const PLAYER_MARGIN: float = 6.0      # oyuncunun gövdesi: koninin ucuna bu kadar yakınsa da yanar

var damage: int = 6
var count: int = 3
var cone_range: float = 110.0
var half_width: float = 0.44          # radyan
var spin: float = 1.05                # radyan/sn (işaretli)
var windup: float = 0.8
var duration: float = 2.0
var colors: Array[Color] = []

var _angle: float = 0.0               # ilk koninin yönü
var _t: float = 0.0
var _puff_timer: float = 0.0
var _puffs: Array = []                # {cone: int, offset: float (radyan, koni ekseninden), dist: float, size: float}

func setup(dmg: int, n: int, length: float, width_degrees: float, start_angle: float, spin_degrees: float,
		warn: float, breath: float, cone_colors: Array[Color]) -> void:
	damage = dmg
	count = maxi(n, 1)
	cone_range = length
	half_width = deg_to_rad(width_degrees) * 0.5
	_angle = start_angle
	spin = deg_to_rad(spin_degrees) * (1.0 if randf() < 0.5 else -1.0)  # her seferinde rastgele yöne döner
	windup = warn
	duration = breath
	colors = cone_colors if not cone_colors.is_empty() else DEFAULT_COLORS

func _ready() -> void:
	add_to_group("enemy_projectile")  # boss ölünce silinir (enemy.gd die)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func is_breathing() -> bool:
	return _t >= windup and _t < windup + duration

func _process(delta: float) -> void:
	_t += delta
	if is_breathing():
		_angle += spin * delta
		_update_puffs(delta)
		_check_hit()
	elif _t >= windup + duration:
		_update_puffs(delta)
		if _t >= windup + duration + FADE_TIME:
			queue_free()
	queue_redraw()

func _cone_angle(i: int) -> float:
	return _angle + TAU * i / count

func _update_puffs(delta: float) -> void:
	for p in _puffs:
		p.dist += PUFF_SPEED * delta
	_puffs = _puffs.filter(func(p): return p.dist < cone_range)
	if not is_breathing():
		return
	_puff_timer -= delta
	while _puff_timer <= 0.0:
		_puff_timer += PUFF_INTERVAL
		for i in count:
			_puffs.append({
				"cone": i,
				"offset": randf_range(-half_width, half_width) * 0.8,
				"dist": START_RADIUS,
				"size": randf_range(2.0, 4.0),
			})

func _check_hit() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("try_hit"):
		return
	if "is_dead" in player and player.is_dead:
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist > cone_range + PLAYER_MARGIN:
		return
	var a := to_player.angle()
	# Yakındaki oyuncunun gövdesi açıca daha geniş yer kaplar
	var margin := atan2(PLAYER_MARGIN, maxf(dist, 1.0))
	for i in count:
		if absf(angle_difference(_cone_angle(i), a)) <= half_width + margin:
			player.try_hit(damage)  # dokunulmazlıktaysa yok sayılır
			return

func _cone_points(center_angle: float, half: float, inner: float, outer: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in ARC_STEPS + 1:
		var a := center_angle - half + 2.0 * half * s / ARC_STEPS
		pts.append(Vector2.RIGHT.rotated(a) * outer)
	for s in ARC_STEPS + 1:
		var a := center_angle + half - 2.0 * half * s / ARC_STEPS
		pts.append(Vector2.RIGHT.rotated(a) * inner)
	return pts

func _draw() -> void:
	var fade := 1.0
	if _t >= windup + duration:
		fade = 1.0 - clampf((_t - windup - duration) / FADE_TIME, 0.0, 1.0)
	for i in count:
		var col: Color = colors[i % colors.size()]
		var ca := _cone_angle(i)
		var outline := _cone_points(ca, half_width, START_RADIUS, cone_range)
		if _t < windup:
			# Uyarı: soluk dolgu, kenarlar hızlanarak yanıp söner
			var p := _t / maxf(windup, 0.01)
			var fill := col
			fill.a = WARN_FILL_ALPHA + 0.1 * p
			draw_colored_polygon(outline, fill)
			var edge := col
			edge.a = WARN_EDGE_ALPHA * (0.5 + 0.5 * absf(sin(_t * lerpf(6.0, 20.0, p))))
			outline.append(outline[0])
			draw_polyline(outline, edge, 1.5)
		else:
			var flicker := 0.85 + 0.15 * sin(_t * 30.0 + i)
			var fill := col
			fill.a = FIRE_FILL_ALPHA * flicker * fade
			draw_colored_polygon(outline, fill)
			var core := col.lightened(0.5)
			core.a = FIRE_CORE_ALPHA * flicker * fade
			draw_colored_polygon(_cone_points(ca, half_width * FIRE_CORE_RATIO, START_RADIUS, cone_range * 0.85), core)
	for p in _puffs:
		var col: Color = colors[p.cone % colors.size()].lightened(0.3)
		var k: float = p.dist / cone_range
		col.a = (1.0 - k) * 0.8 * fade
		var dir := Vector2.RIGHT.rotated(_cone_angle(p.cone) + p.offset)
		draw_circle(dir * p.dist, p.size * (1.0 + k), col)
