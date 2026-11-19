class_name LocustTide
extends Node2D

# Abaddon'un çekirge seli: boss'tan oyuncuya doğru akan, oyuncunun yolunu kesen geniş bir çekirge duvarı.
# Sahne dosyası yok, enemy.gd koddan kurar, Main/FloorFx altına ekler. Uyarı zeminde çizilir (yaratıkların altında),
# çekirgeler ayrı bir çocuk düğümde z_index ile her şeyin üstünde uçar. Çizim tamamen kodla (_draw).
# Yerel eksenler: +x = selin aktığı yön, y = duvar boyunca. Düğüm, duvarın başladığı çizginin ortasındadır.
# Akış: warn sn uyarı (selin geçeceği alan soluk, kenarı ve yön okları yanıp söner; güvenli boşluğun şeridi açık
# bırakılır, kenarları parlak) -> duvar speed ile travel kadar akar (değen oyuncuya try_hit; boşluk ve uçlar güvenli)
# -> çekirgeler dağılarak söner, yok olur.

const WARN_FILL := Color(0.85, 0.55, 0.2, 0.10)
const WARN_EDGE := Color(1.0, 0.7, 0.25, 0.6)
const GAP_EDGE := Color(1.0, 0.95, 0.75, 0.85)
const WALL_SHADOW := Color(0.1, 0.06, 0.02, 0.35)   # duvarın zemindeki gölgesi
const BODY_COLOR := Color(0.18, 0.13, 0.08)
const WING_COLOR := Color(0.9, 0.68, 0.32)
const WING_DARK := Color(0.55, 0.4, 0.18)
const DENSITY: float = 1.0 / 55.0      # çekirge sayısı / px²
const ARROW_GAP: float = 70.0          # uyarıdaki yön okları arası (px)
const FADE_TIME: float = 0.45          # sel bitince dağılma süresi
const PLAYER_MARGIN: float = 6.0       # oyuncunun gövdesi: duvara/boşluk kenarına bu kadar yakınsa da değer
const SWARM_Z: int = 10                # çekirgeler oyuncu ve yaratıkların üstünde

var damage: int = 6
var length: float = 600.0              # duvarın boyu (y ekseni)
var thickness: float = 36.0            # duvarın kalınlığı (x ekseni)
var gap_center: float = 0.0            # güvenli boşluğun ortası (y)
var gap_width: float = 80.0
var speed: float = 140.0
var travel: float = 400.0              # duvarın toplam yolu
var warn: float = 1.0

var _t: float = 0.0
var _locusts: Array = []               # {x: float, y: float, phase: float, drift: Vector2}
var _swarm: Node2D
var _sound: String = ""
var _focus: bool = true                # true: ses play_sfx_focus ile (boss); kalabalık yaratıkta normal çalar
# Sel sesi kayıttan kısa olabilir: çalan oynatıcı tutulur, çekirgelerle birlikte kısılıp susturulur.
# Oynatıcı havuzdan gelir; bitince başka sese verilebileceği için hâlâ bizim sesimizi çaldığı (stream) kontrol edilir.
var _sfx: AudioStreamPlayer = null
var _sfx_stream: AudioStream = null
var _sfx_base_db: float = 0.0

var _warn_fill: Color = WARN_FILL
var _warn_edge: Color = WARN_EDGE
var _gap_edge: Color = GAP_EDGE
var _wall_shadow: Color = WALL_SHADOW
var _body_color: Color = BODY_COLOR
var _wing_color: Color = WING_COLOR
var _wing_dark: Color = WING_DARK

# Kehribar çekirgeler yerine başka renk (Lucifer: buz mavisi, EnemyData.fx_color; çekirgeler buz kırıntısı fırtınası olur)
func set_color(c: Color) -> void:
	_warn_fill = Color(c, WARN_FILL.a)
	_warn_edge = Color(c.lightened(0.2), WARN_EDGE.a)
	_gap_edge = Color(c.lightened(0.75), GAP_EDGE.a)
	_wall_shadow = Color(c.darkened(0.9), WALL_SHADOW.a)
	_body_color = c.darkened(0.75)
	_wing_color = c.lightened(0.55)
	_wing_dark = c.darkened(0.25)

# angle: selin aktığı yön (radyan). gap: boşluğun duvar ortasına uzaklığı (işaretli).
func setup(dmg: int, wall_length: float, wall_thickness: float, gap: float, gap_size: float, flow_speed: float,
		distance: float, warning: float, angle: float, sound: String, focus: bool = true) -> void:
	damage = dmg
	length = wall_length
	thickness = wall_thickness
	gap_center = gap
	gap_width = gap_size
	speed = maxf(flow_speed, 1.0)
	travel = distance
	warn = warning
	rotation = angle
	_sound = sound
	_focus = focus

func _has_gap() -> bool:
	return gap_width > 0.0

func _ready() -> void:
	add_to_group("enemy_projectile")  # boss ölünce silinir (enemy.gd die)
	_swarm = Node2D.new()
	_swarm.z_index = SWARM_Z
	_swarm.draw.connect(_draw_swarm)
	add_child(_swarm)
	var count := int(length * thickness * DENSITY)
	for i in count:
		var y := randf_range(-length * 0.5, length * 0.5)
		if _has_gap() and absf(y - gap_center) < gap_width * 0.5:
			continue  # boşlukta çekirge yok
		_locusts.append({
			"x": randf_range(-thickness * 0.5, thickness * 0.5),
			"y": y,
			"phase": randf() * TAU,
			"drift": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 90.0),
		})

func _flow_time() -> float:
	return travel / speed

func _front() -> float:
	# Duvarın ortasının başlangıç çizgisinden uzaklığı
	return clampf(_t - warn, 0.0, _flow_time()) * speed

func is_flowing() -> bool:
	return _t >= warn and _t < warn + _flow_time()

func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if before < warn and _t >= warn:
		if _focus:
			_sfx = Audio.play_sfx_focus(_sound)  # yaratık vuruş sesleri susar, sel duyulsun
		else:
			_sfx = Audio.play_sfx(_sound)
		if _sfx:
			_sfx_stream = _sfx.stream
			_sfx_base_db = _sfx.volume_db
	if is_flowing():
		_check_hit()
	elif _t >= warn + _flow_time() + FADE_TIME:
		_stop_sound()
		queue_free()
		return
	elif _t >= warn + _flow_time() and _owns_sound():
		# Sel bitti: ses çekirgelerle birlikte kısılır
		_sfx.volume_db = _sfx_base_db + linear_to_db(maxf(_fade(), 0.001))
	queue_redraw()
	_swarm.queue_redraw()

func _owns_sound() -> bool:
	return is_instance_valid(_sfx) and _sfx.playing and _sfx.stream == _sfx_stream

func _stop_sound() -> void:
	if _owns_sound():
		_sfx.stop()
	_sfx = null

# Boss ölünce sel erken silinir (enemy_projectile): ses de susar
func _exit_tree() -> void:
	_stop_sound()

func _check_hit() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("try_hit"):
		return
	if "is_dead" in player and player.is_dead:
		return
	var local := to_local(player.global_position)
	if absf(local.x - _front()) > thickness * 0.5 + PLAYER_MARGIN:
		return
	if absf(local.y) > length * 0.5 + PLAYER_MARGIN:
		return  # duvarın ucundan dolaşmış
	if _has_gap() and absf(local.y - gap_center) < gap_width * 0.5 - PLAYER_MARGIN:
		return  # güvenli boşlukta
	player.try_hit(damage)  # dokunulmazlıktaysa yok sayılır

# Zemindeki uyarı: selin geçeceği alan, boşluğun şeridi, yön okları; akarken duvarın gölgesi
func _draw() -> void:
	var half := length * 0.5
	var gap_lo := gap_center - gap_width * 0.5
	var gap_hi := gap_center + gap_width * 0.5
	if not _has_gap():
		# Boşluk yok: ilk şerit tüm boyu kaplar, ikincisi sıfır genişlikte kalır
		gap_lo = half
		gap_hi = half
	var x0 := -thickness * 0.5
	var x1 := travel + thickness * 0.5
	if _t < warn:
		var p := _t / maxf(warn, 0.01)
		var blink := 0.5 + 0.5 * absf(sin(_t * lerpf(6.0, 20.0, p)))
		var fill := _warn_fill
		fill.a = _warn_fill.a + 0.08 * p
		# Boşluğun iki yanındaki iki şerit (boşluk açık kalır)
		draw_rect(Rect2(x0, -half, x1 - x0, gap_lo + half), fill)
		draw_rect(Rect2(x0, gap_hi, x1 - x0, half - gap_hi), fill)
		var edge := _warn_edge
		edge.a *= blink
		# Duvarın başladığı çizgi (kalın) ve alanın uç kenarları
		draw_line(Vector2(0.0, -half), Vector2(0.0, gap_lo), edge, 3.0)
		draw_line(Vector2(0.0, gap_hi), Vector2(0.0, half), edge, 3.0)
		draw_line(Vector2(x0, -half), Vector2(x1, -half), edge, 1.0)
		draw_line(Vector2(x0, half), Vector2(x1, half), edge, 1.0)
		# Boşluk şeridinin parlak kenarları
		if _has_gap():
			var g := _gap_edge
			g.a *= 0.6 + 0.4 * blink
			draw_line(Vector2(x0, gap_lo), Vector2(x1, gap_lo), g, 1.5)
			draw_line(Vector2(x0, gap_hi), Vector2(x1, gap_hi), g, 1.5)
		# Akış yönünü gösteren oklar (öne doğru kayar)
		var shift := fmod(_t * 60.0, ARROW_GAP)
		var y := -half + ARROW_GAP * 0.5
		while y < half:
			if y < gap_lo - 10.0 or y > gap_hi + 10.0:
				var x := ARROW_GAP * 0.5 + shift
				while x < x1:
					_draw_chevron(Vector2(x, y), edge)
					x += ARROW_GAP
			y += ARROW_GAP
	else:
		var fade := _fade()
		var shadow := _wall_shadow
		shadow.a *= fade
		var f := _front()
		draw_rect(Rect2(f - thickness * 0.5, -half, thickness, gap_lo + half), shadow)
		draw_rect(Rect2(f - thickness * 0.5, gap_hi, thickness, half - gap_hi), shadow)

func _draw_chevron(at: Vector2, col: Color) -> void:
	draw_line(at + Vector2(-5.0, -6.0), at, col, 1.5)
	draw_line(at + Vector2(-5.0, 6.0), at, col, 1.5)

func _fade() -> float:
	var end := warn + _flow_time()
	if _t < end:
		return 1.0
	return 1.0 - clampf((_t - end) / FADE_TIME, 0.0, 1.0)

# Çekirgeler: kanat çırparak titreşen küçük gövdeler; sel bitince her biri kendi yönüne dağılır
func _draw_swarm() -> void:
	if _t < warn:
		return
	var f := _front()
	var fade := _fade()
	var scatter := maxf(_t - warn - _flow_time(), 0.0)
	for l in _locusts:
		var ph: float = l.phase
		var pos := Vector2(f + l.x + sin(_t * 9.0 + ph) * 2.0, l.y + cos(_t * 7.0 + ph) * 2.0)
		pos += l.drift * scatter
		var flap := sin(_t * 40.0 + ph) > 0.0
		var body := _body_color
		body.a = fade
		var wing := _wing_color if flap else _wing_dark
		wing.a = fade
		pos = pos.round()
		# Gövde 3x2, kanatlar gövdenin üstünde/altında 1-2 px (çırpınca açılır)
		_swarm.draw_rect(Rect2(pos + Vector2(-1.0, 0.0), Vector2(3.0, 2.0)), body)
		if flap:
			_swarm.draw_rect(Rect2(pos + Vector2(-1.0, -2.0), Vector2(2.0, 2.0)), wing)
			_swarm.draw_rect(Rect2(pos + Vector2(-1.0, 2.0), Vector2(2.0, 2.0)), wing)
		else:
			_swarm.draw_rect(Rect2(pos + Vector2(-2.0, -1.0), Vector2(3.0, 1.0)), wing)
