extends Node2D

@export var sword_scene: PackedScene
@export var radius: float = 14.0          # görünmez çemberin yarıçapı
@export var rotation_speed: float = 3.0   # radyan/saniye
@export var damage: int = 10
@export var debug_circle: bool = false    # çemberi görmek için Inspector'dan aç

var sword_count: int = 1

func _ready() -> void:
	rebuild()

func _process(delta: float) -> void:
	rotation += rotation_speed * delta

func set_sword_count(count: int) -> void:
	sword_count = maxi(count, 0)
	rebuild()

func rebuild() -> void:
	
	print("REBUILD radius=", radius, " count=", sword_count, " scene=", sword_scene)
	
	for child in get_children():
		remove_child(child)
		child.queue_free()

	for i in sword_count:
		var sword := sword_scene.instantiate()
		sword.damage = damage
		var angle := TAU * i / sword_count
		sword.position = Vector2.from_angle(angle) * radius
		sword.rotation = angle
		add_child(sword)

	queue_redraw()

func _draw() -> void:
	if debug_circle:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 0, 0, 1), 2.0)

func apply_stats(count: int, speed: float, dmg: int) -> void:
	sword_count = maxi(count, 0)
	rotation_speed = speed
	damage = dmg
	rebuild()
