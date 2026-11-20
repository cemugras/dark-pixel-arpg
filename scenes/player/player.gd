extends CharacterBody2D

@export var invulnerability_time: float = 0.5  # hasar aldıktan sonra dokunulmazlık süresi

# 45 derecelik 8 dilim. İndeks 0 = sağ (doğu), saat yönünde (Godot'ta y aşağı doğru artar).
# Sol (batı) yönler, sağ yönlerin yatay çevrilmiş halidir. Adlar PixelLab yönleriyle aynı (yaratıklardaki gibi).
const DIR_NAMES: Array[String] = [
	"east", "south_east", "south", "south_east",
	"east", "north_east", "north", "north_east"
]

# Walt Ember: menzilli silah yokken eller cepte; varken "Aim Two" pozu (iki kol öne, silahlar yumruklarda, GunSlots el modu).
# Silahlıyken gövde nişan yönüne bakar, hareket klavyeyle olur.
const FRAMES_WALT: SpriteFrames = preload("res://data/player/walt_frames.tres")
const FRAMES_AIM: SpriteFrames = preload("res://data/player/walt_aim_frames.tres")          # 2 silah: iki kol öne
const FRAMES_AIM_ONE: SpriteFrames = preload("res://data/player/walt_aim_one_frames.tres")  # 1 silah: sağ kol öne, sol el cepte
const SPRITE_SCALE: float = 0.5  # yaratıklarla aynı ölçek (64 px PixelLab karakteri ~32 px görünür)
const DIR_FLIP: Array[bool] = [
	false, false, false, true,
	true, true, false, false
]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var gun_slots: Node2D = $GunSlots

var move_speed: float = 90.0
var max_health: int = 100
var health: int = 100

var facing_idx: int = 2  # gövdenin baktığı yön (silahlıyken nişan yönü); başlangıçta aşağı
var _move_facing_idx: int = 2  # klavyeyle son hareket yönü
var invulnerable_timer: float = 0.0
var is_dead: bool = false
var debug_god: bool = false  # test: F1 (DebugTools) ile açılır, hiç hasar almaz
var _regen_accumulator: float = 0.0
const KNOCKBACK_DECAY: float = 8.0   # geri itilmenin sönme hızı (hız / 8 ≈ itilme mesafesi)
var _knockback: Vector2 = Vector2.ZERO

# Yaratık vuruşuyla geri itilme (Ram Brute toslaması); speed px/sn başlangıç hızı
func knockback(dir: Vector2, speed: float) -> void:
	if is_dead or debug_god:
		return
	_knockback = dir.normalized() * speed

func _ready() -> void:
	add_to_group("player")
	GameState.stats_changed.connect(_on_stats_changed)
	EventBus.wave_started.connect(_on_wave_started)
	sprite.sprite_frames = FRAMES_WALT
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	sprite.play("idle_" + DIR_NAMES[facing_idx])
	# Silahlar gövdenin arkasında da çizilebilsin diye GunSlots sprite'tan önce çizilir (arkadakiler z 0, öndekiler z 1)
	move_child(gun_slots, 0)
	max_health = GameState.stats.max_health
	health = max_health
	_apply_stats()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * move_speed + _knockback
	move_and_slide()
	# Geri itilme (Ram Brute toslaması): hızla söner
	_knockback *= exp(-KNOCKBACK_DECAY * delta)
	if _knockback.length_squared() < 1.0:
		_knockback = Vector2.ZERO

	if dir != Vector2.ZERO:
		_move_facing_idx = wrapi(roundi(dir.angle() / (PI / 4.0)), 0, 8)

	var armed := GameState.guns.size() > 0
	# Duruş elde görünen eşya sayısına göre (el bombası sadece atarken sayılır, yoksa o el cepte)
	var held: int = gun_slots.held_count()
	var frames := FRAMES_WALT
	if held == 1:
		frames = FRAMES_AIM_ONE
	elif held >= 2:
		frames = FRAMES_AIM
	if sprite.sprite_frames != frames:
		# Bomba atarken duruş bir anlığına değişir: koşu/nefes animasyonu aynı karede devam etsin
		var anim := sprite.animation
		var frame := sprite.frame
		var progress := sprite.frame_progress
		sprite.sprite_frames = frames
		if frames.has_animation(anim):
			sprite.play(anim)
			sprite.set_frame_and_progress(mini(frame, frames.get_frame_count(anim) - 1), progress)
	# Silahlıyken gövde menzildeki en yakın düşmana döner; hedef yoksa hareket yönüne
	facing_idx = gun_slots.aim_facing(facing_idx, _move_facing_idx) if armed else _move_facing_idx

	_play_animation(dir != Vector2.ZERO)
	_handle_contact_damage(delta)
	_regenerate(delta)

func _play_animation(moving: bool) -> void:
	var prefix := "run_" if moving else "idle_"
	sprite.flip_h = DIR_FLIP[facing_idx]
	sprite.play(prefix + DIR_NAMES[facing_idx])

func _handle_contact_damage(delta: float) -> void:
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		# dokunulmazken yanıp sönme efekti
		sprite.modulate.a = 0.4 if int(invulnerable_timer * 20.0) % 2 == 0 else 1.0
		return

	sprite.modulate.a = 1.0
	for body in hurtbox.get_overlapping_bodies():
		if "contact_damage" in body:
			take_damage(body.contact_damage)
			break

func _regenerate(delta: float) -> void:
	var regen := GameState.stats.health_regen
	if regen <= 0.0 or health >= max_health:
		return
	_regen_accumulator += regen * delta
	if _regen_accumulator >= 1.0:
		var heal := int(_regen_accumulator)
		_regen_accumulator -= heal
		health = mini(health + heal, max_health)
		EventBus.player_health_changed.emit(health, max_health)

# Yaratık saldırıları bunu kullanır: dokunulmazlık süresindeyken ya da ölüyken hasar yok sayılır.
func try_hit(amount: int) -> bool:
	if is_dead or invulnerable_timer > 0.0:
		return false
	take_damage(amount)
	return true

func take_damage(amount: int) -> void:
	if is_dead or debug_god:
		return
	var final_damage := GameState.stats.reduce_damage(amount)
	health = maxi(health - final_damage, 0)
	invulnerable_timer = invulnerability_time
	EventBus.player_damaged.emit(health, max_health)
	EventBus.player_health_changed.emit(health, max_health)
	if health <= 0:
		die()
	else:
		Audio.play_sfx("player_hurt")

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	Audio.play_sfx("player_death")
	Audio.stop_music(0.5)  # game over ekranı bilerek sessiz (müzik yok)
	EventBus.player_died.emit()

func _on_stats_changed() -> void:
	if is_dead:
		return
	var old_max := max_health
	max_health = GameState.stats.max_health
	if max_health > old_max:
		health += max_health - old_max  # maksimum can artınca aynı miktarda iyileş
	health = mini(health, max_health)
	EventBus.player_health_changed.emit(health, max_health)
	_apply_stats()

func _apply_stats() -> void:
	var s := GameState.stats
	move_speed = s.move_speed

func _on_wave_started(_wave: int) -> void:
	if is_dead:
		return
	health = max_health
	EventBus.player_health_changed.emit(health, max_health)
