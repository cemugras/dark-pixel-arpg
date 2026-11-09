extends Node2D

@export var gun_scene: PackedScene
# Silah yuvalarının oyuncuya göre konumu (sol el, sağ el)
@export var slot_offsets: Array[Vector2] = [Vector2(-8, 5), Vector2(8, 5)]

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

	for i in mini(GameState.guns.size(), slot_offsets.size()):
		var gun := gun_scene.instantiate()
		gun.setup(GameState.guns[i])
		gun.position = slot_offsets[i]
		add_child(gun)
