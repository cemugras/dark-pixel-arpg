extends Area2D

var damage: int = 5
var speed: float = 320.0
var max_distance: float = 200.0

var _travelled: float = 0.0
var _hit: bool = false

# Silah, mermiyi sahneye eklemeden önce bunu çağırır
func setup(dmg: int, spd: float, distance: float, angle: float) -> void:
	damage = dmg
	speed = spd
	max_distance = distance
	rotation = angle

func _ready() -> void:
	body_entered.connect(_on_body_entered)

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
