class_name RuneBlast
extends Node2D

# Yere çizilen kan rünü (Lilith'in büyüsü). Sahne dosyası yok, enemy.gd koddan kurar, Main/FloorFx altına ekler
# (zeminin üstünde, yaratıkların ve oyuncunun altında). Çizim tamamen kodla (_draw): ileride sprite'a geçilebilir.
# Akış: delay sn uyarı (dış halka yanıp söner, içi dolan daire patlama anını gösterir, halkadaki rün işaretleri döner),
# sonra patlar: o an oyuncu çemberin içindeyse try_hit (dokunulmazlıktaysa yok sayılır), kısa parlama ve yok olur.

const RUNE_COLOR: Color = Color(0.85, 0.08, 0.12)        # kan kırmızısı
const FILL_ALPHA_START: float = 0.10
const FILL_ALPHA_END: float = 0.35
const RING_WIDTH: float = 2.0
const BLINK_SPEED_START: float = 6.0                     # dış halkanın yanıp sönme hızı (patlamaya doğru hızlanır)
const BLINK_SPEED_END: float = 22.0
const MARK_COUNT: int = 6                                # halkadaki küçük rün işaretleri
const MARK_SPIN: float = 1.5                             # işaretlerin dönme hızı (radyan/sn)
const BLAST_TIME: float = 0.25                           # patlama parlamasının süresi
const BLAST_COLOR: Color = Color(1.0, 0.35, 0.25)
const BLAST_GROW: float = 1.25                           # parlama bu kata kadar büyür

var damage: int = 10
var radius: float = 26.0
var delay: float = 1.0
var blast_sound: String = ""
var focus_sound: bool = true   # patlama sesi play_sfx_focus ile mi (boss rünü evet, Lilim rünü hayır)

var _t: float = 0.0
var _blasted: bool = false

func setup(dmg: int, r: float, warn: float, sound: String, focus: bool = true) -> void:
	focus_sound = focus
	damage = dmg
	radius = r
	delay = warn
	blast_sound = sound

func _ready() -> void:
	add_to_group("enemy_projectile")  # boss ölünce sahnedeki rünler silinir (enemy.gd die)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # zeminde kızıl parıltı
	material = mat

func _process(delta: float) -> void:
	_t += delta
	if not _blasted and _t >= delay:
		_blast()
	elif _blasted and _t >= delay + BLAST_TIME:
		queue_free()
	queue_redraw()

func _blast() -> void:
	_blasted = true
	if focus_sound:
		Audio.play_sfx_focus(blast_sound)  # yaratık vuruş sesleri susar, patlama duyulsun
	else:
		Audio.play_sfx(blast_sound)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("try_hit"):
		return
	if "is_dead" in player and player.is_dead:
		return
	if global_position.distance_to(player.global_position) <= radius:
		player.try_hit(damage)

func _draw() -> void:
	if _blasted:
		var b := clampf((_t - delay) / BLAST_TIME, 0.0, 1.0)
		var c := BLAST_COLOR
		c.a = 1.0 - b
		draw_circle(Vector2.ZERO, radius * lerpf(1.0, BLAST_GROW, b), c)
		return

	var p := clampf(_t / delay, 0.0, 1.0)  # 0 = yeni çizildi, 1 = patlıyor
	# Zemin dolgusu giderek koyulaşır
	var fill := RUNE_COLOR
	fill.a = lerpf(FILL_ALPHA_START, FILL_ALPHA_END, p)
	draw_circle(Vector2.ZERO, radius, fill)
	# İçten dolan daire: kenara değdiği an patlar
	var inner := RUNE_COLOR
	inner.a = 0.45
	draw_circle(Vector2.ZERO, radius * p, inner)
	# Dış halka: patlamaya yaklaştıkça hızlanarak yanıp söner
	var blink_speed := lerpf(BLINK_SPEED_START, BLINK_SPEED_END, p)
	var ring := RUNE_COLOR
	ring.a = 0.55 + 0.45 * absf(sin(_t * blink_speed))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring, RING_WIDTH)
	# Dönen rün işaretleri (halkanın hemen içinde küçük çizgiler)
	var spin := _t * MARK_SPIN
	for i in MARK_COUNT:
		var a := spin + TAU * i / MARK_COUNT
		var dir := Vector2.RIGHT.rotated(a)
		draw_line(dir * (radius - 6.0), dir * (radius - 2.0), ring, RING_WIDTH)
