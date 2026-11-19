class_name HellBullet
extends Area2D

# Azazel'in ateş oku (düello atışı, mızrak uçlarından). Sahne dosyası yok, DuelGuns koddan kurar.
# Oyuncunun mermisiyle aynı görüntü (Bullet.png), ama kızgın turuncu + arkasında toplamalı hale: oyuncunun sarı ve
# gümüş mermilerinden ayrılsın. Oyuncuya değince try_hit, duvara değince yok olur.

const TEXTURE: Texture2D = preload("res://assets/sprites/gun/Bullet.png")
const SPRITE_SCALE: Vector2 = Vector2(0.45, 0.3)  # uzun ateş oku
const HOT_COLOR: Color = Color(1.8, 0.6, 0.3)
const HALO_COLOR: Color = Color(1.0, 0.3, 0.05, 0.6)
const HALO_SCALE: float = 1.9
const HIT_RADIUS: float = 3.5
const FADE_DISTANCE: float = 30.0

var damage: int = 5
var speed: float = 280.0
var max_distance: float = 420.0

var _travelled: float = 0.0
var _hit: bool = false
var _hot_color: Color = HOT_COLOR
var _halo_color: Color = HALO_COLOR

func setup(dmg: int, spd: float, distance: float, angle: float) -> void:
	damage = dmg
	speed = spd
	max_distance = distance
	rotation = angle

# Kızgın turuncu yerine başka renk (Lucifer: buz oku, EnemyData.fx_color); _ready'den önce çağrılır
func set_color(c: Color) -> void:
	_hot_color = Color(c.r * 1.8, c.g * 1.8, c.b * 1.8)
	_halo_color = Color(c, HALO_COLOR.a)

func _ready() -> void:
	add_to_group("enemy_projectile")  # boss ölünce havadakiler silinir (enemy.gd die)
	collision_layer = 0
	collision_mask = 1 | 2  # world + player
	var shape := CircleShape2D.new()
	shape.radius = HIT_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var halo := Sprite2D.new()
	halo.texture = TEXTURE
	halo.scale = SPRITE_SCALE * HALO_SCALE
	halo.modulate = _halo_color
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = mat
	add_child(halo)

	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.scale = SPRITE_SCALE
	sprite.modulate = _hot_color
	add_child(sprite)

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += Vector2.from_angle(rotation) * step
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
