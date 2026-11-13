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

# --- Saldırı durumu (bkz. EnemyData attack_*) ---
const ATTACK_HIT_RANGE_MULT: float = 1.4  # attack_hit_range boşsa: başlatma menzilinin bu katı (kılpayı ıska olmasın)
const ATTACK_LUNGE_FRAMES: int = 2        # vuruş karesinden önceki kaç karede ileri atılır
enum State { CHASE, ATTACK, WINDUP, CHARGE, TIRED }
var _state: State = State.CHASE

# --- Hamle durumu (bkz. EnemyData charge_*) ---
const CHARGE_RUN_SPEED_SCALE: float = 2.5     # charge_ animasyonu yoksa run bu hızda oynar
const CHARGE_SHAKE: float = 1.5               # uyarıda titreme (sprite pikseli)
const CHARGE_WINDUP_COLOR: Color = Color(1.8, 0.7, 0.6)  # uyarıda kızarma
const CHARGE_TIRED_COLOR: Color = Color(0.7, 0.7, 0.85)  # yorgunken solukluk
const CHARGE_STUCK_RATIO: float = 0.3         # hamlede beklenen yolun bu kadarından azı alınırsa (duvar) hamle biter
var _has_charge: bool = false
var charge_damage: int = 0
var _charge_timer: float = 0.0
var _state_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_left: float = 0.0
var _charge_hit_done: bool = false
var _has_attack: bool = false
var attack_damage: int = 0
var _attack_cooldown_left: float = 0.0
var _attack_dir: Vector2 = Vector2.RIGHT
var _attack_hit_done: bool = false
var _lunge_speed: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Dalga yöneticisi, düşmanı sahneye eklemeden önce bunu çağırır
func setup(enemy_data: EnemyData, wave: int) -> void:
	data = enemy_data
	var w := wave - 1
	max_health = roundi(data.max_health * (1.0 + HEALTH_PER_WAVE * w))
	contact_damage = int(data.contact_damage * (1.0 + 0.1 * w))
	attack_damage = int(data.attack_damage * (1.0 + 0.1 * w))
	charge_damage = int(data.charge_damage * (1.0 + 0.1 * w))
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

	# Saldırı: veri + 8 yönlü attack animasyonu varsa açılır, yoksa sadece temas hasarı
	_has_attack = data != null and data.attack_range > 0.0 and _mode == SpriteMode.EIGHT_DIR \
		and frames.has_animation("attack_east")
	if _has_attack:
		var fps := frames.get_animation_speed("attack_east")
		_lunge_speed = data.attack_lunge * fps / ATTACK_LUNGE_FRAMES
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	# Hamle: sadece 8 yönlü sprite'ta (yön kilidi 8 yön sistemine göre)
	_has_charge = data != null and data.charge_interval > 0.0 and _mode == SpriteMode.EIGHT_DIR
	if _has_charge:
		_charge_timer = data.charge_interval

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left -= delta

	match _state:
		State.WINDUP:
			_process_windup(delta)
			return
		State.CHARGE:
			_process_charge(delta)
			return
		State.TIRED:
			_process_tired(delta)
			return

	var separation := _separation() * maxf(move_speed, SEPARATION_MIN_SPEED) * SEPARATION_STRENGTH
	if _state == State.ATTACK:
		# Saldırırken durur (itme devam eder); vuruştan hemen önce saldırı yönüne atılır
		velocity = separation
		if _is_lunge_frame():
			velocity += _attack_dir * _lunge_speed
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	var dir := to_target.normalized()
	# Yön (bakış) oyuncuya göre kalır; itme sadece hareketi etkiler, böylece sprite titremez
	velocity = dir * move_speed + separation
	move_and_slide()

	if _has_charge:
		_charge_timer -= delta
		if _can_start_charge(to_target.length()):
			_start_windup(dir)
			return

	if _can_start_attack(to_target.length()):
		_start_attack(dir)
		return

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

func _can_start_attack(distance: float) -> bool:
	if not _has_attack or _attack_cooldown_left > 0.0 or _dying:
		return false
	if "is_dead" in target and target.is_dead:
		return false
	return distance <= data.attack_range

func _start_attack(dir: Vector2) -> void:
	_state = State.ATTACK
	_attack_dir = dir
	_attack_hit_done = false
	# Saldırı yönüne kesin dön (koşudaki titreme payı burada uygulanmaz)
	_dir8_idx = wrapi(roundi(dir.angle() / (PI / 4.0)), 0, 8)
	sprite.flip_h = DIR8_FLIP[_dir8_idx]
	sprite.play("attack_" + DIR8_NAMES[_dir8_idx])
	sprite.frame = 0

func _is_lunge_frame() -> bool:
	var f := sprite.frame
	return f >= data.attack_hit_frame - ATTACK_LUNGE_FRAMES and f < data.attack_hit_frame

# Vuruş karesi: oyuncu hâlâ menzildeyse hasar (kaçtıysa ıska)
func _on_sprite_frame_changed() -> void:
	if _state != State.ATTACK or _attack_hit_done or sprite.frame < data.attack_hit_frame:
		return
	_attack_hit_done = true
	if not is_instance_valid(target) or _dying:
		return
	var hit_range := data.attack_hit_range if data.attack_hit_range > 0.0 else data.attack_range * ATTACK_HIT_RANGE_MULT
	if global_position.distance_to(target.global_position) <= hit_range and target.has_method("try_hit"):
		target.try_hit(attack_damage)

func _on_sprite_animation_finished() -> void:
	if _state != State.ATTACK:
		return
	_state = State.CHASE
	_attack_cooldown_left = data.attack_cooldown
	sprite.play("run_" + DIR8_NAMES[_dir8_idx])

# --- Hamle: uyarı -> düz atılma -> yorgunluk ---
func _can_start_charge(distance: float) -> bool:
	if _charge_timer > 0.0 or _dying:
		return false
	if "is_dead" in target and target.is_dead:
		return false
	return distance >= data.charge_min_range and distance <= data.charge_max_range

func _start_windup(dir: Vector2) -> void:
	_state = State.WINDUP
	_state_timer = data.charge_windup
	# Yön uyarı başında kilitlenir: oyuncu uyarı süresince yana kaçabilir
	_charge_dir = dir
	var dist := global_position.distance_to(target.global_position)
	_charge_left = minf(dist + data.charge_overshoot, data.charge_max_distance)
	_face_exact(dir)
	sprite.pause()

func _process_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	var t := 1.0 - _state_timer / maxf(data.charge_windup, 0.01)
	sprite.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * CHARGE_SHAKE * t
	sprite.modulate = _base_color.lerp(CHARGE_WINDUP_COLOR, t)
	if _state_timer <= 0.0:
		_start_charge()

func _start_charge() -> void:
	_state = State.CHARGE
	_charge_hit_done = false
	sprite.position = Vector2.ZERO
	sprite.modulate = _base_color
	var anim := "charge_" + DIR8_NAMES[_dir8_idx]
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		sprite.play("run_" + DIR8_NAMES[_dir8_idx])
		sprite.speed_scale = CHARGE_RUN_SPEED_SCALE
	Audio.play_sfx(data.charge_sound)

func _process_charge(delta: float) -> void:
	var before := global_position
	velocity = _charge_dir * data.charge_speed
	move_and_slide()
	var moved := before.distance_to(global_position)
	_charge_left -= moved

	if not _charge_hit_done and is_instance_valid(target) and target.has_method("try_hit"):
		var hit_radius := data.charge_hit_radius if data.charge_hit_radius > 0.0 else _separation_radius() * 1.2
		if global_position.distance_to(target.global_position) <= hit_radius:
			_charge_hit_done = true
			target.try_hit(charge_damage)

	# Yol bitti ya da bir şeye takıldı (duvar): yorul
	if _charge_left <= 0.0 or moved < data.charge_speed * delta * CHARGE_STUCK_RATIO:
		_start_tired()

func _start_tired() -> void:
	_state = State.TIRED
	_state_timer = data.charge_tired
	sprite.speed_scale = 1.0
	var anim := "tired_" + DIR8_NAMES[_dir8_idx]
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		sprite.play("run_" + DIR8_NAMES[_dir8_idx])
		sprite.pause()
	sprite.modulate = CHARGE_TIRED_COLOR * _base_color

func _process_tired(delta: float) -> void:
	velocity = _separation() * SEPARATION_MIN_SPEED * SEPARATION_STRENGTH
	move_and_slide()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state = State.CHASE
		_charge_timer = data.charge_interval
		sprite.modulate = _base_color
		sprite.play("run_" + DIR8_NAMES[_dir8_idx])

# Verilen yöne kesin dön (8 yön, titreme payı uygulanmaz)
func _face_exact(dir: Vector2) -> void:
	_dir8_idx = wrapi(roundi(dir.angle() / (PI / 4.0)), 0, 8)
	sprite.flip_h = DIR8_FLIP[_dir8_idx]

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
