class_name CoinProjectile
extends Area2D

# Yaratığın fırlattığı kızgın sikke (Mammon'un sikke yağmuru). Sahne dosyası yok, enemy.gd koddan kurar.
# Yerdeki toplanabilir sikkeyle karışmasın diye kızıl-turuncu, parlak ve hızlı döner; arkasında toplamalı hale var.
# Oyuncuya değince try_hit (dokunulmazlıktaysa hasar yok, sikke yine yok olur), duvara değince yok olur.

const COIN_FRAMES: SpriteFrames = preload("res://data/pickups/coin_frames.tres")
const SPRITE_SCALE: float = 0.7
const SPIN_SPEED_SCALE: float = 2.5
const HOT_COLOR: Color = Color(1.7, 0.75, 0.35)          # 1'in üstü = kızgın parlaklık
const HALO_COLOR: Color = Color(1.0, 0.35, 0.1, 0.6)
const HALO_SCALE: float = 1.9
const HIT_RADIUS: float = 4.0
const FADE_DISTANCE: float = 30.0                        # yolun son bu kadarında solar

var damage: int = 5
var speed: float = 150.0
var max_distance: float = 320.0
var direction: Vector2 = Vector2.RIGHT

var _travelled: float = 0.0
var _hit: bool = false

func setup(dmg: int, spd: float, distance: float, dir: Vector2) -> void:
	damage = dmg
	speed = spd
	max_distance = distance
	direction = dir.normalized()

func _ready() -> void:
	add_to_group("enemy_projectile")  # boss ölünce havadakiler silinir (enemy.gd die)
	collision_layer = 0
	collision_mask = 1 | 2  # world + player
	var shape := CircleShape2D.new()
	shape.radius = HIT_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var halo := _make_sprite()
	halo.scale *= HALO_SCALE
	halo.modulate = HALO_COLOR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = mat
	add_child(halo)

	var sprite := _make_sprite()
	sprite.modulate = HOT_COLOR
	add_child(sprite)

	body_entered.connect(_on_body_entered)

func _make_sprite() -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = COIN_FRAMES
	s.scale = Vector2.ONE * SPRITE_SCALE
	s.speed_scale = SPIN_SPEED_SCALE
	s.play("spin")
	return s

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_travelled += step
	var left := max_distance - _travelled
	if left <= 0.0:
		queue_free()
	elif left < FADE_DISTANCE:
		modulate.a = left / FADE_DISTANCE

func _on_body_entered(body: Node) -> void:
	if _hit:
		return
	if body.has_method("try_hit"):
		if "is_dead" in body and body.is_dead:
			return
		body.try_hit(damage)
	_hit = true
	queue_free()
