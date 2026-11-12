extends CharacterBody2D

var data: EnemyData
var max_health: int = 30
var move_speed: float = 40.0
var contact_damage: int = 5
var coin_value: int = 1
var _base_color: Color = Color.WHITE

const DIRECTION_BIAS: float = 1.2  # 4 yön: eksen değiştirme eşiği (titreme önleme)
const SECTOR_MARGIN: float = 0.12  # 8 yön: dilim değiştirme payı (radyan, titreme önleme)
const BOSS_DEATH_MUSIC_FADE: float = 0.1  # boss ölünce müzik bu sürede kesilir (ani kesilme tıkırtısı olmasın)
const HEALTH_PER_WAVE: float = 0.12  # her dalgada can tabanın %12si kadar artar (Brotato tarzı: kalabalık hızlı, can yavaş artar)

# --- Ayrışma (yaratıklar iç içe girmesin) ---
# Fiziksel çarpışma yerine yumuşak itme: birbirine çok yaklaşan yaratıklar hafifçe ayrılır, kalabalık akıcı kalır.
const SEPARATION_RADIUS: float = 20.0    # body_scale uygulanmadan önceki kişisel alan yarıçapı (0.5 ölçekte 10 px)
const SEPARATION_STRENGTH: float = 1.2   # itmenin hıza göre gücü (artırırsan daha seyrek dururlar)
const SEPARATION_MAX: float = 1.5        # aynı anda çok komşudan gelen itmenin üst sınırı
const SEPARATION_MIN_SPEED: float = 40.0 # yavaş yaratıklar da yeterince hızlı ayrılsın
const GRID_CELL: float = 40.0            # komşu arama ızgarası hücre boyutu (px)

# Izgara her fizik karesinde bir kez (o karede ilk hareket eden yaratık tarafından) kurulur
static var _grid: Dictionary = {}        # Vector2i hücre -> Array (yaratıklar)
static var _grid_frame: int = -1
static var _grid_max_radius: float = 0.0 # en büyük kişisel alan (boss) -> arama mesafesi

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
var _dying: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Dalga yöneticisi, düşmanı sahneye eklemeden önce bunu çağırır
func setup(enemy_data: EnemyData, wave: int) -> void:
	data = enemy_data
	var w := wave - 1
	max_health = roundi(data.max_health * (1.0 + HEALTH_PER_WAVE * w))
	contact_damage = int(data.contact_damage * (1.0 + 0.1 * w))
	move_speed = data.move_speed * minf(1.0 + 0.01 * w, 1.5)
	coin_value = data.coin_value
	scale = Vector2.ONE * data.body_scale

func _ready() -> void:
	add_to_group("enemy")
	if data:
		sprite.sprite_frames = data.sprite_frames
		if not is_equal_approx(data.hitbox_scale, 1.0):
			# Şekil sahnede ortak kaynak: kopyalanmazsa tüm yaratıkların çemberi büyür
			var collision := $CollisionShape2D as CollisionShape2D
			collision.shape = collision.shape.duplicate()
			collision.shape.radius *= data.hitbox_scale
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
	# Yön (bakış) oyuncuya göre kalır; itme sadece hareketi etkiler, böylece sprite titremez
	velocity = dir * move_speed + _separation() * maxf(move_speed, SEPARATION_MIN_SPEED) * SEPARATION_STRENGTH
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

func _separation_radius() -> float:
	return SEPARATION_RADIUS * scale.x * (data.hitbox_scale if data else 1.0)

static func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / GRID_CELL), floori(pos.y / GRID_CELL))

func _ensure_grid() -> void:
	var frame := Engine.get_physics_frames()
	if _grid_frame == frame:
		return
	_grid_frame = frame
	_grid.clear()
	_grid_max_radius = 0.0
	for e in get_tree().get_nodes_in_group("enemy"):
		var cell := _cell_of(e.global_position)
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(e)
		_grid_max_radius = maxf(_grid_max_radius, e._separation_radius())

# Yakındaki yaratıklardan uzaklaştıran itme yönü (0 = rahat, büyüdükçe daha sıkışık)
func _separation() -> Vector2:
	_ensure_grid()
	var my_radius := _separation_radius()
	var reach := ceili((my_radius + _grid_max_radius) / GRID_CELL)
	var my_cell := _cell_of(global_position)
	var push := Vector2.ZERO
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var cell := my_cell + Vector2i(dx, dy)
			if not _grid.has(cell):
				continue
			for other in _grid[cell]:
				if other == self or not is_instance_valid(other):
					continue
				var other_radius: float = other._separation_radius()
				var min_dist := my_radius + other_radius
				var offset: Vector2 = global_position - other.global_position
				var dist_sq := offset.length_squared()
				if dist_sq >= min_dist * min_dist:
					continue
				var dist := sqrt(dist_sq)
				var away: Vector2
				if dist < 0.01:
					# Tam üst üste doğdularsa: her yaratık kendine özgü sabit bir yöne kaçar
					away = Vector2.RIGHT.rotated(float(get_instance_id() % 360) * PI / 180.0)
				else:
					away = offset / dist
				# Küçük yaratık büyüğünden (boss) daha çok itilir
				var share := other_radius / min_dist * 2.0
				push += away * (1.0 - dist / min_dist) * share
	return push.limit_length(SEPARATION_MAX)

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
	if _dying:
		return
	health -= amount
	_flash()
	if health <= 0:
		die()
	elif data:
		Audio.play_sfx(data.get_hit_sound())

func die() -> void:
	# Aynı karede iki vuruş gelirse iki kez ölmesin (çift altın / çift ses olmasın)
	if _dying:
		return
	_dying = true
	if data:
		if data.is_boss:
			Audio.stop_music(BOSS_DEATH_MUSIC_FADE)  # boss müziği ölüm sesinden önce kesilir
			EventBus.boss_defeated.emit(data.id)  # Steam başarımı vb. için (ör. "moloch")
		Audio.play_sfx(data.get_death_sound())
	EventBus.enemy_died.emit(global_position, coin_value)
	queue_free()

func _flash() -> void:
	sprite.modulate = Color(3, 3, 3)  # kısa süreli parlama
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_color, 0.1)
