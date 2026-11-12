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
# İki silahın atışları arasındaki boşluk = en hızlı silahın atış aralığı / silah sayısı x bu oran (1 = tam eşit aralık)
@export var shot_gap_ratio: float = 1.0

# --- El modu: silahlar Walt'ın nişan pozundaki yumruklarında durur ---
# Walt gövdesi nişan yönüne döner; her bakış yönünde silah sadece +-22.5 derece oynar, bu yüzden yön başına tek el pozu yeter.
# 1 silah: "Aim One" (sağ kol öne, sol el cepte), 2 silah: "Aim Two" (iki kol öne).
# Yumruk konumları her animasyon karesi için ölçülüp walt_hand_anchors.json'a yazıldı (koşarken kollar oynasa da silah elde kalır);
# dosya/kare yoksa aşağıdaki sabit noktalar kullanılır.
@export var hand_mode: bool = true
const HAND_SPRITE_SCALE: float = 0.5   # Walt sprite ölçeği (player.gd SPRITE_SCALE)
const AIM_SECTOR_MARGIN: float = 0.15  # bakış yönü değiştirme payı (radyan, sınırda titreme olmasın)
const FRAME_ANCHORS_PATH: String = "res://data/player/walt_hand_anchors.json"
# Yumruk noktaları: 64 px sprite pikseli, sprite merkezine göre. [yakın el, uzak el]. Batı yönleri x aynalanır.
const HAND_ANCHORS_ONE: Dictionary = {
	"south": [Vector2(-10.5, -7.7)],
	"south_east": [Vector2(17.7, -3.7)],
	"east": [Vector2(20.3, -11.4)],
	"north_east": [Vector2(21.3, -19.6)],
	"north": [Vector2(6.5, -26.8)],
}
const HAND_ANCHORS: Dictionary = {
	"south": [Vector2(3, -9), Vector2(-7, -9)],
	"south_east": [Vector2(11, -8), Vector2(20, -11)],
	"east": [Vector2(16, -12), Vector2(19, -16)],
	"north_east": [Vector2(20, -17), Vector2(8, -20)],  # uzak yumruk kafanın önünde
	"north": [Vector2(9, -22), Vector2(-11, -22)],
}
const FRONT_FACINGS: Array[int] = [1, 2, 3]  # güneye bakan yönlerde silahlar gövdenin önünde çizilir

var _time: float = 0.0
var _last_shot_time: float = -100.0
var _frame_anchors: Dictionary = {}  # durum ("aim_one"/"aim_two") -> anim ("run"/"idle") -> yön -> kare -> [[x, y], ...]

func _ready() -> void:
	GameState.weapons_changed.connect(rebuild)
	if FileAccess.file_exists(FRAME_ANCHORS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FRAME_ANCHORS_PATH))
		if parsed is Dictionary:
			_frame_anchors = parsed
	rebuild()

func _physics_process(delta: float) -> void:
	_time += delta
	if hand_mode:
		_place_guns_in_hands()

# Oyuncu her karede sorar: menzildeki en yakın düşmanın yönü (bakış dilimi). Hedef yoksa fallback (hareket yönü).
func aim_facing(current_idx: int, fallback_idx: int) -> int:
	if not hand_mode or get_child_count() == 0:
		return fallback_idx
	var target := _nearest_target()
	if target == null:
		return fallback_idx
	var center := (get_parent() as Node2D).global_position
	var angle := center.direction_to(target.global_position).angle()
	# Mevcut dilimin sınırını biraz aşmadan dönme (düşmanlar kıpırdarken titremesin)
	if absf(angle_difference(current_idx * PI / 4.0, angle)) <= PI / 8.0 + AIM_SECTOR_MARGIN:
		return current_idx
	return wrapi(roundi(angle / (PI / 4.0)), 0, 8)

func _nearest_target() -> Node2D:
	var max_range := 0.0
	for gun in get_children():
		if gun.data:
			max_range = maxf(max_range, gun.data.attack_range)
	var center := (get_parent() as Node2D).global_position
	var best: Node2D = null
	var best_dist := max_range * max_range
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_queued_for_deletion():
			continue
		var d := center.distance_squared_to(enemy.global_position)
		if d <= best_dist:
			best_dist = d
			best = enemy
	return best

func _place_guns_in_hands() -> void:
	var player := get_parent()
	if player == null or not ("facing_idx" in player):
		return
	var idx: int = player.facing_idx
	var anchors := _current_anchors(player, idx)
	var flip: bool = player.DIR_FLIP[idx]
	var front := idx in FRONT_FACINGS
	var rest_dir := Vector2.from_angle(idx * PI / 4.0)
	var guns := get_children()
	for i in guns.size():
		var a: Vector2 = anchors[mini(i, anchors.size() - 1)]
		if flip:
			a.x = -a.x
		guns[i].set_hand(a * HAND_SPRITE_SCALE, front, rest_dir)

# Şu anki animasyon karesindeki yumruklar (yoksa sabit noktalar). Dönen değer: Array[Vector2], sprite pikseli.
func _current_anchors(player: Node, idx: int) -> Array:
	var dir_key: String = player.DIR_NAMES[idx]
	var one := get_child_count() == 1
	var fallback: Array = (HAND_ANCHORS_ONE if one else HAND_ANCHORS)[dir_key]
	var sprite: AnimatedSprite2D = player.sprite
	var anim := String(sprite.animation)          # ör. "run_south_east"
	var kind := anim.get_slice("_", 0)             # "run" / "idle"
	var frames: Variant = _frame_anchors.get("aim_one" if one else "aim_two", {}).get(kind, {}).get(dir_key)
	if not (frames is Array) or sprite.frame >= frames.size():
		return fallback
	var result: Array = []
	var pts: Array = frames[sprite.frame]
	if pts.size() == 2 and not (pts[0] is Array):
		pts = [pts]  # tek nokta düz [x, y] olarak gelmiş olabilir
	for p in pts:
		result.append(Vector2(p[0], p[1]))
	return result if not result.is_empty() else fallback

# Silahlar ateş etmeden önce sorar; diğer silah az önce ateş ettiyse false döner
func request_shot() -> bool:
	if _time - _last_shot_time < _shot_gap():
		return false
	_last_shot_time = _time
	return true

func _shot_gap() -> float:
	var guns := get_children()
	if guns.size() < 2:
		return 0.0
	var fastest := INF
	for gun in guns:
		if gun.has_method("fire_interval"):
			fastest = minf(fastest, gun.fire_interval())
	if fastest == INF:
		return 0.0
	return fastest / guns.size() * shot_gap_ratio

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
		gun.use_hand_grip = hand_mode
		var rest_angle := (slot_offsets[i] - orbit_center).angle()
		# tek silah varsa ortadan, iki silah varsa yan yana nişan alır (sol yuva -, sağ yuva +)
		var aim_offset := 0.0
		if count > 1:
			aim_offset = deg_to_rad(pair_spread_degrees) * (-1.0 if i == 0 else 1.0)
		gun.setup_orbit(orbit_center, orbit_radius, orbit_speed, rest_angle, aim_offset)
		add_child(gun)
