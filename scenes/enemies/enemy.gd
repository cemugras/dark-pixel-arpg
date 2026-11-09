extends CharacterBody2D

var data: EnemyData
var max_health: int = 30
var move_speed: float = 40.0
var contact_damage: int = 5
var coin_value: int = 1
var _base_color: Color = Color.WHITE

const DIRECTION_BIAS: float = 1.2  # 4 yön: eksen değiştirme eşiği (titreme önleme)
const SECTOR_MARGIN: float = 0.12  # 8 yön: dilim değiştirme payı (radyan, titreme önleme)

# 8 yön: 45 derecelik dilimler, indeks 0 = doğu, saat yönünde (Godot'ta y aşağı artar).
# Batı tarafı, doğu tarafının yatay çevrilmiş halidir (oyuncudaki gibi).
const DIR8_NAMES: Array[String] = [
	"east", "south_east", "south", "south_east",
	"east", "north_east", "north", "north_east"
]
const DIR8_FLIP: Array[bool] = [
	false, false, false, true,
	true, true, false, false
]

enum SpriteMode { SINGLE, FOUR_DIR, EIGHT_DIR }

var health: int
var target: Node2D
var _mode: SpriteMode = SpriteMode.SINGLE
var _facing: String = "down"   # 4 yön modu
var _dir8_idx: int = 2         # 8 yön modu, başlangıçta güney

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Dalga yöneticisi, düşmanı sahneye eklemeden önce bunu çağırır
func setup(enemy_data: EnemyData, wave: int) -> void:
	data = enemy_data
	var w := wave - 1
	max_health = int(data.max_health * (1.0 + 0.2 * w))
	contact_damage = int(data.contact_damage * (1.0 + 0.1 * w))
	move_speed = data.move_speed * minf(1.0 + 0.01 * w, 1.5)
	coin_value = data.coin_value
	scale = Vector2.ONE * data.body_scale

func _ready() -> void:
	add_to_group("enemy")
	if data:
		sprite.sprite_frames = data.sprite_frames
		_base_color = data.tint
		sprite.modulate = _base_color
	health = max_health
	target = get_tree().get_first_node_in_group("player")
	# Sprite'ta hangi animasyonlar varsa ona göre mod seçilir
	var frames := sprite.sprite_frames
	if frames.has_animation("run_east"):
		_mode = SpriteMode.EIGHT_DIR
		sprite.play("run_" + DIR8_NAMES[_dir8_idx])
	elif frames.has_animation("run_down"):
		_mode = SpriteMode.FOUR_DIR
		sprite.play("run_down")
	else:
		_mode = SpriteMode.SINGLE
		sprite.play("run")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return

	var dir := global_position.direction_to(target.global_position)
	velocity = dir * move_speed
	move_and_slide()

	match _mode:
		SpriteMode.EIGHT_DIR:
			_update_direction_8(dir)
		SpriteMode.FOUR_DIR:
			_update_direction(dir)
		SpriteMode.SINGLE:
			if absf(dir.x) > 0.05:
				# Tek yönlü sprite: sadece yatay çevir
				var faces_right := data.sprite_faces_right if data else true
				sprite.flip_h = (dir.x < 0.0) == faces_right

# 8 yönlü sprite: run_east/south_east/south/north_east/north + batı için flip.
# Mevcut dilimin sınırını biraz aşmadan yön değişmez (çaprazda titreme önleme).
func _update_direction_8(dir: Vector2) -> void:
	var angle := dir.angle()
	var current_center := _dir8_idx * PI / 4.0
	if absf(angle_difference(current_center, angle)) <= PI / 8.0 + SECTOR_MARGIN:
		return

	_dir8_idx = wrapi(roundi(angle / (PI / 4.0)), 0, 8)
	sprite.flip_h = DIR8_FLIP[_dir8_idx]
	_play_keep_frame("run_" + DIR8_NAMES[_dir8_idx])

# Animasyon karesi kaldığı yerden devam etsin, yön değişince baştan başlamasın
func _play_keep_frame(anim: String) -> void:
	if sprite.animation == anim:
		return
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.play(anim)
	sprite.set_frame_and_progress(frame, progress)

# 4 yönlü sprite: baskın eksene göre run_down/up/left/right seç.
# Çaprazda titremesin diye eksen değiştirmek için diğer eksenin belirgin şekilde baskın olması gerekir.
func _update_direction(dir: Vector2) -> void:
	var horizontal := _facing == "left" or _facing == "right"
	if horizontal and absf(dir.y) > absf(dir.x) * DIRECTION_BIAS:
		horizontal = false
	elif not horizontal and absf(dir.x) > absf(dir.y) * DIRECTION_BIAS:
		horizontal = true

	var new_facing: String
	if horizontal:
		new_facing = "right" if dir.x > 0.0 else "left"
	else:
		new_facing = "down" if dir.y > 0.0 else "up"

	if new_facing == _facing:
		return
	_facing = new_facing
	_play_keep_frame("run_" + _facing)

func take_damage(amount: int) -> void:
	health -= amount
	_flash()
	if health <= 0:
		die()

func die() -> void:
	EventBus.enemy_died.emit(global_position, coin_value)
	queue_free()

func _flash() -> void:
	sprite.modulate = Color(3, 3, 3)  # kısa süreli parlama
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_color, 0.1)
