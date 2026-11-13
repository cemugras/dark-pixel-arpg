class_name Merchant
extends Node2D

# Kanatlı iblis tüccar Brimm (bkz. STORY.md). Dalga sonunda havadan Walt'ın yanına iner, indiğinde mağazayı açar;
# mağazada Next Wave basılınca (EventBus.shop_closed) havalanır, ekrandan çıkınca yeni dalgayı başlatır.
# Main koddan ekler (main.tscn'e dokunmamak için). Görsel yoksa (FRAMES_PATH) akış görünmez şekilde aynen çalışır.
# Sesler: merchant_wings (iniş/kalkış), merchant_land (yere değince), merchant_greet (mağaza açılırken); dosya yoksa sessiz.

const FRAMES_PATH: String = "res://data/npc/merchant_frames.tres"  # animasyonlar: "fly", "idle" (güney)
const SPRITE_SCALE: float = 0.5
const FEET_OFFSET: float = 29.0                # karelerde (88x88) ayakların merkezden uzaklığı (sprite pikseli)
const LAND_OFFSET: Vector2 = Vector2(34, -4)   # oyuncuya göre iniş noktası (sağında)
const FLY_HEIGHT: float = 260.0                # inişe ekranın bu kadar üstünden başlar
const DESCEND_TIME: float = 1.0
const ASCEND_TIME: float = 0.8
const LAND_SQUASH: Vector2 = Vector2(1.15, 0.85)  # yere değince kısa esneme
const SQUASH_TIME: float = 0.15
const GREET_DELAY: float = 0.25                # yere indikten sonra mağaza açılmadan önce kısa bekleme
const SHADOW_SIZE: Vector2 = Vector2(12, 4)    # gölge elipsinin yarıçapları (px)
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.35)

var _wave: int = 0
var _busy: bool = false
var _body: Node2D               # yükseklik (y) ve esneme buna uygulanır, gölge yerde kalır
var _sprite: AnimatedSprite2D
var _shadow: Polygon2D
var _dust: CPUParticles2D

func _ready() -> void:
	add_to_group("merchant")
	visible = false
	EventBus.shop_closed.connect(depart)
	_build()

func _build() -> void:
	_shadow = Polygon2D.new()
	var points := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		points.append(Vector2(cos(a) * SHADOW_SIZE.x, sin(a) * SHADOW_SIZE.y))
	_shadow.polygon = points
	_shadow.color = SHADOW_COLOR
	add_child(_shadow)

	_body = Node2D.new()
	add_child(_body)
	_sprite = AnimatedSprite2D.new()
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	_sprite.offset = Vector2(0, -FEET_OFFSET)  # ayaklar yere (gölgeye) otursun
	if ResourceLoader.exists(FRAMES_PATH):
		_sprite.sprite_frames = load(FRAMES_PATH)
	_body.add_child(_sprite)

	# Yere değince küçük toz bulutu
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 10
	_dust.lifetime = 0.45
	_dust.explosiveness = 1.0
	_dust.direction = Vector2.UP
	_dust.spread = 80.0
	_dust.gravity = Vector2(0, 40)
	_dust.initial_velocity_min = 15.0
	_dust.initial_velocity_max = 35.0
	_dust.scale_amount_min = 1.5
	_dust.scale_amount_max = 2.5
	_dust.color = Color(0.55, 0.5, 0.45, 0.7)
	add_child(_dust)

func _play(anim: String) -> void:
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)

# WaveManager dalga sonu beklemesi bitince çağırır
func arrive(wave: int) -> void:
	if _busy:
		return
	_busy = true
	_wave = wave
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		# Arena ortası (0,0) civarında: oyuncu sağ yarıdaysa tüccar soluna iner, duvar dışına düşmesin
		var side := -1.0 if player.global_position.x > 0.0 else 1.0
		global_position = player.global_position + Vector2(LAND_OFFSET.x * side, LAND_OFFSET.y)
	visible = true
	_body.position = Vector2(0, -FLY_HEIGHT)
	_body.scale = Vector2.ONE
	_shadow.scale = Vector2.ONE * 0.3
	_shadow.modulate.a = 0.3
	_play("fly")
	Audio.play_sfx("merchant_wings")

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_body, "position:y", 0.0, DESCEND_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shadow, "scale", Vector2.ONE, DESCEND_TIME)
	tween.tween_property(_shadow, "modulate:a", 1.0, DESCEND_TIME)
	tween.chain().tween_callback(_land)

func _land() -> void:
	_play("idle")
	Audio.play_sfx("merchant_land")
	_dust.restart()
	_body.scale = LAND_SQUASH
	var tween := create_tween()
	tween.tween_property(_body, "scale", Vector2.ONE, SQUASH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(GREET_DELAY)
	tween.tween_callback(_open_shop)

func _open_shop() -> void:
	Audio.play_sfx("merchant_greet")
	EventBus.shop_requested.emit(_wave)

# Mağaza kapanınca (EventBus.shop_closed): havalanır, ekrandan çıkınca yeni dalga başlar
func depart() -> void:
	_play("fly")
	Audio.play_sfx("merchant_wings")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_body, "position:y", -FLY_HEIGHT, ASCEND_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_shadow, "scale", Vector2.ONE * 0.3, ASCEND_TIME)
	tween.tween_property(_shadow, "modulate:a", 0.0, ASCEND_TIME)
	tween.chain().tween_callback(_gone)

func _gone() -> void:
	visible = false
	_busy = false
	EventBus.next_wave_requested.emit()
