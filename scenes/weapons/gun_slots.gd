extends Node2D

@export var gun_scene: PackedScene
# Hedef yokken silahların durduğu yer (sol el, sağ el); çember üzerindeki açıları buradan hesaplanır
@export var slot_offsets: Array[Vector2] = [Vector2(-8, 5), Vector2(8, 5)]
# Silahların üzerinde kaydığı görünmez çember (oyuncuya göre)
@export var orbit_center: Vector2 = Vector2(0, 3)
@export var orbit_radius: float = 10.0
@export var orbit_speed: float = 9.0              # çember üzerinde dönüş hızı (radyan/sn)
# İki silah aynı düşmana nişan alırken üst üste binmesin diye aradaki açı farkının yarısı (derece)
@export var pair_spread_degrees: float = 25.0

func _ready() -> void:
	GameState.weapons_changed.connect(rebuild)
	rebuild()

func rebuild() -> void:
	# Ölüm anında GameState sıfırlanınca silahlar kaybolmasın
	var player := get_parent()
	if player and player.get("is_dead"):
		return

	for child in get_children():
		remove_child(child)
		child.queue_free()

	var count := mini(GameState.guns.size(), slot_offsets.size())
	for i in count:
		var gun := gun_scene.instantiate()
		gun.setup(GameState.guns[i])
		var rest_angle := (slot_offsets[i] - orbit_center).angle()
		# tek silah varsa ortadan, iki silah varsa yan yana nişan alır (sol yuva -, sağ yuva +)
		var aim_offset := 0.0
		if count > 1:
			aim_offset = deg_to_rad(pair_spread_degrees) * (-1.0 if i == 0 else 1.0)
		gun.setup_orbit(orbit_center, orbit_radius, orbit_speed, rest_angle, aim_offset)
		add_child(gun)
