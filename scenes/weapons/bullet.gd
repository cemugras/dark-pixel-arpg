extends Area2D

var damage: int = 5
var speed: float = 320.0
var max_distance: float = 200.0

var silver: bool = false

var _travelled: float = 0.0
var _hit: bool = false

# Gümüş mermi görünümü: parlak gümüş-beyaz (1'in üstü = normalden aydınlık) + arkasında yarı saydam, toplamalı (additive) hale
const SILVER_TEXTURE: Texture2D = preload("res://assets/sprites/gun/bullet_silver.png")  # Bullet.png'nin sarı kenarı gümüş-mavi
const SILVER_COLOR: Color = Color(1.3, 1.35, 1.5)
const SILVER_HALO_COLOR: Color = Color(0.7, 0.85, 1.0, 0.55)
const SILVER_HALO_SCALE: float = 1.8

# Silah, mermiyi sahneye eklemeden önce bunu çağırır
func setup(dmg: int, spd: float, distance: float, angle: float, is_silver: bool = false) -> void:
	damage = dmg
	speed = spd
	max_distance = distance
	rotation = angle
	silver = is_silver

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if silver:
		_apply_silver_look()

func _apply_silver_look() -> void:
	var sprite := $Sprite2D as Sprite2D
	sprite.texture = SILVER_TEXTURE
	var halo := sprite.duplicate() as Sprite2D
	halo.scale = sprite.scale * SILVER_HALO_SCALE
	halo.modulate = SILVER_HALO_COLOR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = mat
	add_child(halo)
	move_child(halo, sprite.get_index())  # hale merminin arkasında
	sprite.modulate = SILVER_COLOR

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += Vector2.from_angle(rotation) * step
	_travelled += step
	if _travelled >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _hit:
		return
	_hit = true
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()  # düşmana ya da duvara çarpınca yok ol
