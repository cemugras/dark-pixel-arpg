extends CharacterBody2D

@export var invulnerability_time: float = 0.5  # hasar aldıktan sonra dokunulmazlık süresi

# 45 derecelik 8 dilim. İndeks 0 = sağ, saat yönünde (Godot'ta y aşağı doğru artar).
# Sol yönler, sağ yönlerin yatay çevrilmiş halidir.
const DIR_NAMES: Array[String] = [
	"right", "down_right", "down", "down_right",
	"right", "up_right", "up", "up_right"
]
const DIR_FLIP: Array[bool] = [
	false, false, false, true,
	true, true, false, false
]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var hurtbox: Area2D = $Hurtbox

var move_speed: float = 90.0
var max_health: int = 100
var health: int = 100

var facing_idx: int = 2  # başlangıçta aşağı bakıyor
var invulnerable_timer: float = 0.0
var is_dead: bool = false
var _regen_accumulator: float = 0.0

func _ready() -> void:
	add_to_group("player")
	GameState.stats_changed.connect(_on_stats_changed)
	max_health = GameState.stats.max_health
	health = max_health
	_apply_stats()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * move_speed
	move_and_slide()

	if dir != Vector2.ZERO:
		facing_idx = wrapi(roundi(dir.angle() / (PI / 4.0)), 0, 8)

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

func take_damage(amount: int) -> void:
	if is_dead:
		return
	var final_damage := GameState.stats.reduce_damage(amount)
	health = maxi(health - final_damage, 0)
	invulnerable_timer = invulnerability_time
	EventBus.player_damaged.emit(health, max_health)
	EventBus.player_health_changed.emit(health, max_health)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	EventBus.player_died.emit()
	# Geçici: 1 saniye sonra sahneyi yeniden başlat. Sonra Game Over ekranı yapacağız.
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()

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
	weapon_pivot.apply_stats(s.sword_count, s.rotation_speed, s.sword_damage())
