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
enum State { CHASE, ATTACK, WINDUP, CHARGE, TIRED, THROW, SUMMON, CAST, DIVE, BURROW, SURFACING, EMERGE, BREATH }
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

# --- Fırlatma durumu (bkz. EnemyData throw_*) ---
var _has_throw: bool = false
var throw_damage: int = 0
var _throw_timer: float = 0.0
var _throw_released: bool = false
var _throw_count_toggle: bool = false  # throw_alternate: her ikinci atışta +1 mermi

# --- Çağırma durumu (bkz. EnemyData summon_*) ---
const MINION_GROUP: String = "summoned_minion"  # çağrılmış yaratıklar; çağıran boss ölünce silinir
var _has_summon: bool = false
var _summon_timer: float = 0.0
var _summon_released: bool = false
var _minions: Array = []  # bu yaratığın çağırdıkları (sayı sınırı için)
var _summon_sound_until: int = 0  # ms; çağırma sesi bu ana kadar çalar, o sürede hit sesi çalmaz (vızıltı duyulsun)
var _wave: int = 1

# --- Büyü durumu (bkz. EnemyData cast_*) ---
const FLOOR_FX_PATH: String = "FloorFx"   # Main altındaki zemin efektleri düğümü (main.gd kurar)
const SPECIAL_GAP: float = 1.2            # çağırma ile büyü arka arkaya gelmesin: biri bitince diğeri en az bu kadar bekler
var _has_cast: bool = false
var cast_damage: int = 0
var _cast_timer: float = 0.0
var _cast_released: bool = false

# --- Dalış durumu (bkz. EnemyData dive_* / burrow_* / emerge_*) ---
# DIVE: yürürken zemine batar (shader zemin çizgisinin altını gizler) -> BURROW: görünmez, vurulamaz, dalgacık oyuncuyu
# kovalar -> SURFACING: dalgacık durur, uyarı -> EMERGE: yerden yükselirken emerge animasyonu oynar, bırakma karesinde
# patlama; bitince emerge_recover sn yerinde durur -> CHASE
const DIVE_SINK_TIME: float = 0.45     # zemine batma süresi (sn)
const EMERGE_RISE_TIME: float = 0.25   # yerden yükselme süresi (sn; patlama karesinden önce bitsin)
const DIVE_GROUND_RATIO: float = 0.86  # karede zemin çizgisi (kare yüksekliğine oran, gövdenin alt kenarı)
const DIVE_DEPTH: float = 110.0        # tamamen gömülünce sprite bu kadar aşağı kayar (sprite pikseli)
const SINK_SHADER: String = "shader_type canvas_item;\nuniform float cut = 2.0;\nvoid fragment() {\n\tif (UV.y > cut) { COLOR.a = 0.0; }\n}\n"
var _has_dive: bool = false
var emerge_damage: int = 0
var _dive_timer: float = 0.0
var _emerge_released: bool = false
var _recovering: bool = false
var _sink: float = 0.0                 # 0 = yerde tam boy, 1 = tamamen gömülü
var _burrow_fx: LavaBurrow = null
var _collision_layer_saved: int = 0

# --- Nefes durumu (bkz. EnemyData breath_*) ---
# BREATH: dur, dön, animasyon (ağız açık karede bekler); koniler uyarı + dönen nefes -> animasyon biter -> toparlanma
var _has_breath: bool = false
var breath_damage: int = 0
var _breath_timer: float = 0.0
var _breath_phase: int = 0            # 0 = uyarı + nefes, 1 = animasyonun kalanı, 2 = toparlanma

# --- Sikke saçma (bkz. EnemyData spill_*) ---
var _spill_next: int = 0  # can bu değerin altına inince sikke saçılır

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Dalga yöneticisi, düşmanı sahneye eklemeden önce bunu çağırır
func setup(enemy_data: EnemyData, wave: int) -> void:
	data = enemy_data
	_wave = wave
	var w := wave - 1
	max_health = roundi(data.max_health * (1.0 + HEALTH_PER_WAVE * w))
	contact_damage = int(data.contact_damage * (1.0 + 0.1 * w))
	attack_damage = int(data.attack_damage * (1.0 + 0.1 * w))
	charge_damage = int(data.charge_damage * (1.0 + 0.1 * w))
	throw_damage = int(data.throw_damage * (1.0 + 0.1 * w))
	cast_damage = int(data.cast_damage * (1.0 + 0.1 * w))
	emerge_damage = int(data.emerge_damage * (1.0 + 0.1 * w))
	breath_damage = int(data.breath_damage * (1.0 + 0.1 * w))
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

	# Fırlatma: veri + 8 yönlü throw animasyonu varsa açılır
	_has_throw = data != null and data.throw_count > 0 and _mode == SpriteMode.EIGHT_DIR \
		and frames.has_animation("throw_east")
	if _has_throw:
		_throw_timer = data.throw_interval * 0.5  # boss belirince ilk atış biraz erken gelsin

	# Çağırma: veri + 8 yönlü summon animasyonu varsa açılır
	_has_summon = data != null and data.summon_data != null and data.summon_count > 0 \
		and _mode == SpriteMode.EIGHT_DIR and frames.has_animation("summon_east")
	if _has_summon:
		_summon_timer = data.summon_interval * 0.4  # boss belirince ilk sürü biraz erken gelsin

	# Büyü: veri + 8 yönlü cast animasyonu varsa açılır
	_has_cast = data != null and data.cast_count > 0 and _mode == SpriteMode.EIGHT_DIR \
		and frames.has_animation("cast_east")
	if _has_cast:
		_cast_timer = data.cast_interval * 0.5  # boss belirince ilk büyü biraz erken gelsin

	# Dalış: veri + 8 yönlü emerge animasyonu varsa açılır
	_has_dive = data != null and data.dive_interval > 0.0 and _mode == SpriteMode.EIGHT_DIR \
		and frames.has_animation("emerge_east")
	if _has_dive:
		_dive_timer = data.dive_interval * 0.5  # boss belirince ilk dalış biraz erken gelsin
		var shader := Shader.new()
		shader.code = SINK_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		sprite.material = mat

	# Nefes: veri + 8 yönlü breath animasyonu varsa açılır
	_has_breath = data != null and data.breath_count > 0 and _mode == SpriteMode.EIGHT_DIR \
		and frames.has_animation("breath_east")
	if _has_breath:
		_breath_timer = data.breath_interval * 0.5  # boss belirince ilk nefes biraz erken gelsin

	if _has_attack or _has_throw or _has_summon or _has_cast or _has_dive or _has_breath:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	# Hamle: sadece 8 yönlü sprite'ta (yön kilidi 8 yön sistemine göre)
	_has_charge = data != null and data.charge_interval > 0.0 and _mode == SpriteMode.EIGHT_DIR
	if _has_charge:
		_charge_timer = data.charge_interval

	if data and data.spill_health_step > 0.0 and data.spill_value > 0:
		_spill_next = max_health - roundi(max_health * data.spill_health_step)

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
		State.DIVE:
			_process_dive(delta)
			return
		State.BURROW:
			_process_burrow(delta)
			return
		State.SURFACING:
			_process_surfacing(delta)
			return
		State.EMERGE:
			_process_emerge(delta)
			return
		State.BREATH:
			_process_breath(delta)
			return

	var separation := _separation() * maxf(move_speed, SEPARATION_MIN_SPEED) * SEPARATION_STRENGTH
	if _state == State.THROW or _state == State.SUMMON or _state == State.CAST:
		# Atarken / çağırırken durur (itme devam eder)
		velocity = separation
		move_and_slide()
		return
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

	if _has_throw:
		_throw_timer -= delta
		if _can_start_throw(to_target.length()):
			_start_throw(dir)
			return

	if _has_summon:
		_summon_timer -= delta
		if _can_start_summon():
			_start_summon(dir)
			return

	if _has_cast:
		_cast_timer -= delta
		if _can_start_cast(to_target.length()):
			_start_cast(dir)
			return

	if _has_dive:
		_dive_timer -= delta
		if _can_start_dive(to_target.length()):
			_start_dive(dir)
			return

	if _has_breath:
		_breath_timer -= delta
		if _can_start_breath(to_target.length()):
			_start_breath(dir)
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

# --- Fırlatma: dur, dön, animasyon; bırakma karesinde oyuncuya yelpaze mermi ---
func _can_start_throw(distance: float) -> bool:
	if _throw_timer > 0.0 or _dying:
		return false
	if "is_dead" in target and target.is_dead:
		return false
	return distance >= data.throw_min_range and distance <= data.throw_max_range

func _start_throw(dir: Vector2) -> void:
	_state = State.THROW
	_throw_released = false
	_face_exact(dir)
	sprite.play("throw_" + DIR8_NAMES[_dir8_idx])
	sprite.frame = 0

# Yelpaze, bırakma anında oyuncunun o anki konumuna nişanlanır
func _release_throw() -> void:
	_throw_released = true
	if not is_instance_valid(target) or _dying:
		return
	var count := data.throw_count
	if data.throw_alternate:
		if _throw_count_toggle:
			count += 1
		_throw_count_toggle = not _throw_count_toggle
	var aim := (target.global_position - global_position).normalized()
	var step := deg_to_rad(data.throw_spread_degrees)
	var first := -step * (count - 1) * 0.5
	for i in count:
		var p := CoinProjectile.new()
		p.setup(throw_damage, data.throw_speed, data.throw_distance, aim.rotated(first + step * i))
		p.position = global_position  # yaratığın ebeveyninde (WaveManager) doğar, yaratık ölse de uçmaya devam eder
		get_parent().add_child(p)
	Audio.play_sfx(data.throw_sound)

# --- Çağırma: dur, dön, animasyon; bırakma karesinde etrafa yaratık ---
func _alive_minions() -> int:
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.is_queued_for_deletion())
	return _minions.size()

func _can_start_summon() -> bool:
	if _summon_timer > 0.0 or _dying:
		return false
	if "is_dead" in target and target.is_dead:
		return false
	return _alive_minions() < data.summon_max_alive  # sürü doluysa bekler, süre dolu kalır

func _start_summon(dir: Vector2) -> void:
	_state = State.SUMMON
	_summon_released = false
	_face_exact(dir)
	sprite.play("summon_" + DIR8_NAMES[_dir8_idx])
	sprite.frame = 0

# Yaratıklar çağıranın etrafına eşit aralıklı çember üzerinde çıkar (ilki rastgele açıda)
func _release_summon() -> void:
	_summon_released = true
	if _dying:
		return
	var count := mini(data.summon_count, data.summon_max_alive - _alive_minions())
	if count <= 0:
		return
	var scene := load(scene_file_path) as PackedScene
	var start := randf() * TAU
	for i in count:
		var m := scene.instantiate()
		m.setup(data.summon_data, _wave)
		m.coin_value = 0  # çağrılan yaratık altın düşürmez
		m.position = global_position + Vector2.RIGHT.rotated(start + TAU * i / count) * data.summon_radius
		m.add_to_group(MINION_GROUP)
		get_parent().add_child(m)
		_minions.append(m)
	# Çalan hit sesi kesilir, çağırma sesi bitene kadar yenisi çalmaz (take_damage)
	Audio.stop_sfx(data.get_hit_sound())
	# Oynatıcı havuzdan geldiği için kendisi tutulmaz (bitince başka sese verilir); bitiş zamanı saklanır
	var player := Audio.play_sfx(data.summon_sound)
	if player and player.stream:
		_summon_sound_until = Time.get_ticks_msec() + int(player.stream.get_length() / player.pitch_scale * 1000.0)

# --- Büyü: dur, dön, animasyon; bırakma karesinde yere rünler ---
func _can_start_cast(distance: float) -> bool:
	if _cast_timer > 0.0 or _dying:
		return false
	if "is_dead" in target and target.is_dead:
		return false
	return distance <= data.cast_max_range

func _start_cast(dir: Vector2) -> void:
	_state = State.CAST
	_cast_released = false
	_face_exact(dir)
	sprite.play("cast_" + DIR8_NAMES[_dir8_idx])
	sprite.frame = 0

# İlk rün oyuncunun tam altına, diğerleri çevresine eşit açılarla (rastgele uzaklıkta) düşer:
# yerinde duran vurulur, kaçan çoğunlukla kurtulur ama rastgele bir rünün içine de koşabilir.
func _release_cast() -> void:
	_cast_released = true
	if not is_instance_valid(target) or _dying:
		return
	var fx_parent: Node = get_tree().current_scene.get_node_or_null(FLOOR_FX_PATH)
	if fx_parent == null:
		fx_parent = get_parent()
	var center := target.global_position
	var start := randf() * TAU
	var extra := data.cast_count - 1
	for i in data.cast_count:
		var pos := center
		if i > 0:
			var angle := start + TAU * (i - 1) / extra + randf_range(-0.3, 0.3)
			pos += Vector2.RIGHT.rotated(angle) * randf_range(data.cast_radius * 1.4, data.cast_spread)
		var rune := RuneBlast.new()
		rune.setup(cast_damage, data.cast_radius, data.cast_delay, data.cast_blast_sound)
		rune.global_position = pos
		fx_parent.add_child(rune)
	Audio.play_sfx_focus(data.cast_sound)  # yaratık vuruş sesleri susar, büyü duyulsun

# --- Dalış: zemine batma -> yer altında kovalama -> uyarı -> yükselip patlama -> toparlanma ---
func _can_start_dive(distance: float) -> bool:
	if _dive_timer > 0.0 or _dying:
		return false
	if "is_dead" in target and target.is_dead:
		return false
	return distance <= data.dive_max_range

# Yerinde kıvrılmaya devam ederken zemine batar; kaynayan lav hemen altında belirir
func _start_dive(dir: Vector2) -> void:
	_state = State.DIVE
	_state_timer = DIVE_SINK_TIME
	_face_exact(dir)
	sprite.play("run_" + DIR8_NAMES[_dir8_idx])
	_burrow_fx = LavaBurrow.new()
	_burrow_fx.setup(data.emerge_radius)
	_floor_fx_parent().add_child(_burrow_fx)
	_burrow_fx.global_position = _ground_point()
	Audio.play_sfx(data.dive_sound)

func _process_dive(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	_set_sink(1.0 - _state_timer / DIVE_SINK_TIME)
	if _state_timer <= 0.0:
		_start_burrow()

# Tamamen gömüldü: görünmez ve vurulamaz olur
func _start_burrow() -> void:
	_state = State.BURROW
	_state_timer = data.burrow_time
	sprite.visible = false
	# Katman 0: mermi, kılıç ve oyuncunun temas alanı onu görmez (maske kalır, duvarlardan geçmez).
	# "enemy" grubundan çıkınca silahlar nişan almaz, ayrışma ızgarasına da girmez.
	_collision_layer_saved = collision_layer
	collision_layer = 0
	remove_from_group("enemy")

# Dalgacık (gövdenin zemin noktası) oyuncuya doğru gider
func _process_burrow(delta: float) -> void:
	var dir := (target.global_position - _ground_point()).normalized()
	velocity = dir * data.burrow_speed
	move_and_slide()
	if is_instance_valid(_burrow_fx):
		_burrow_fx.global_position = _ground_point()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_surfacing()

# Sprite'ın zemine değdiği nokta (dünya konumu): dalgacık ve patlama burada
func _ground_point() -> Vector2:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var h := float(tex.get_height()) if tex else 132.0
	return global_position + Vector2(0.0, (DIVE_GROUND_RATIO - 0.5) * h * scale.y)

# 0 = tam boy, 1 = tamamen gömülü: sprite aşağı kayar, zemin çizgisinin altı shader ile gizlenir
func _set_sink(value: float) -> void:
	_sink = clampf(value, 0.0, 1.0)
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var h := float(tex.get_height()) if tex else 132.0
	var shift := _sink * DIVE_DEPTH
	sprite.offset.y = shift
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("cut", 2.0 if _sink <= 0.0 else (h * DIVE_GROUND_RATIO - shift) / h)

# Dalgacık durur ve uyarır; uyarı süresi + emerge'in bırakma karesine kadarki süre boyunca daire dolar
func _start_surfacing() -> void:
	_state = State.SURFACING
	_state_timer = data.emerge_warning
	if is_instance_valid(_burrow_fx):
		var fps := sprite.sprite_frames.get_animation_speed("emerge_east")
		_burrow_fx.start_warning(data.emerge_warning + data.emerge_release_frame / maxf(fps, 1.0))

func _process_surfacing(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_emerge()

func _start_emerge() -> void:
	_state = State.EMERGE
	_state_timer = 0.0
	_emerge_released = false
	_recovering = false
	collision_layer = _collision_layer_saved
	add_to_group("enemy")
	_face_exact(target.global_position - _ground_point())
	sprite.play("emerge_" + DIR8_NAMES[_dir8_idx])
	sprite.frame = 0
	_set_sink(1.0)
	sprite.visible = true

func _process_emerge(delta: float) -> void:
	velocity = Vector2.ZERO
	if _recovering:
		# Son karede (ağız açık) emerge_recover sn durur: oyuncunun vurma penceresi
		velocity = _separation() * SEPARATION_MIN_SPEED * SEPARATION_STRENGTH
		move_and_slide()
		_state_timer -= delta
		if _state_timer <= 0.0:
			_end_dive()
		return
	_state_timer += delta
	_set_sink(1.0 - _state_timer / EMERGE_RISE_TIME)

func _release_emerge() -> void:
	_emerge_released = true
	var center := _ground_point()
	if is_instance_valid(_burrow_fx):
		center = _burrow_fx.global_position
		_burrow_fx.blast()
	_burrow_fx = null
	_set_sink(0.0)
	Audio.play_sfx_focus(data.emerge_sound)  # yaratık vuruş sesleri susar, çıkış duyulsun
	if not is_instance_valid(target) or _dying or not target.has_method("try_hit"):
		return
	if "is_dead" in target and target.is_dead:
		return
	if center.distance_to(target.global_position) <= data.emerge_radius:
		target.try_hit(emerge_damage)

func _end_dive() -> void:
	_state = State.CHASE
	_recovering = false
	_dive_timer = data.dive_interval
	sprite.play("run_" + DIR8_NAMES[_dir8_idx])

# --- Nefes: dur, dön, ağızlar açılır; etrafında dönen koniler; bitince toparlanma ---
func _can_start_breath(distance: float) -> bool:
	if _breath_timer > 0.0 or _dying:
		return false
	if "is_dead" in target and target.is_dead:
		return false
	return distance <= data.breath_max_range

func _start_breath(dir: Vector2) -> void:
	_state = State.BREATH
	_breath_phase = 0
	_state_timer = data.breath_windup + data.breath_duration
	_face_exact(dir)
	sprite.play("breath_" + DIR8_NAMES[_dir8_idx])
	sprite.frame = 0
	var cones := BreathCones.new()
	cones.setup(breath_damage, data.breath_count, data.breath_range, data.breath_width_degrees, dir.angle(),
		data.breath_spin_degrees, data.breath_windup, data.breath_duration, data.breath_colors)
	_floor_fx_parent().add_child(cones)
	cones.global_position = global_position

func _process_breath(delta: float) -> void:
	velocity = _separation() * SEPARATION_MIN_SPEED * SEPARATION_STRENGTH
	move_and_slide()
	match _breath_phase:
		0:
			var before := _state_timer
			_state_timer -= delta
			# Uyarı biterken (nefes başlarken) ses
			if before > data.breath_duration and _state_timer <= data.breath_duration:
				Audio.play_sfx_focus(data.breath_sound)  # yaratık vuruş sesleri susar, nefes duyulsun
			if _state_timer <= 0.0:
				_breath_phase = 1
				sprite.play()  # ağızlar kapanır, animasyonun kalanı (bitince _on_sprite_animation_finished)
		2:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.CHASE
				_breath_timer = data.breath_interval
				sprite.play("run_" + DIR8_NAMES[_dir8_idx])

func _floor_fx_parent() -> Node:
	var fx_parent: Node = get_tree().current_scene.get_node_or_null(FLOOR_FX_PATH)
	return fx_parent if fx_parent else get_parent()

# Vuruş karesi: oyuncu hâlâ menzildeyse hasar (kaçtıysa ıska)
func _on_sprite_frame_changed() -> void:
	if _state == State.BREATH:
		# Ağızlar açık karede nefes bitene kadar bekler
		if _breath_phase == 0 and sprite.frame >= data.breath_hold_frame:
			sprite.pause()
		return
	if _state == State.EMERGE:
		if not _emerge_released and sprite.frame >= data.emerge_release_frame:
			_release_emerge()
		return
	if _state == State.CAST:
		if not _cast_released and sprite.frame >= data.cast_release_frame:
			_release_cast()
		return
	if _state == State.SUMMON:
		if not _summon_released and sprite.frame >= data.summon_release_frame:
			_release_summon()
		return
	if _state == State.THROW:
		if not _throw_released and sprite.frame >= data.throw_release_frame:
			_release_throw()
		return
	if _state != State.ATTACK or _attack_hit_done or sprite.frame < data.attack_hit_frame:
		return
	_attack_hit_done = true
	if not is_instance_valid(target) or _dying:
		return
	var hit_range := data.attack_hit_range if data.attack_hit_range > 0.0 else data.attack_range * ATTACK_HIT_RANGE_MULT
	if global_position.distance_to(target.global_position) <= hit_range and target.has_method("try_hit"):
		target.try_hit(attack_damage)

func _on_sprite_animation_finished() -> void:
	if _state == State.BREATH:
		_breath_phase = 2
		_state_timer = data.breath_recover
		return
	if _state == State.EMERGE:
		if not _emerge_released:
			_release_emerge()
		_recovering = true
		_state_timer = data.emerge_recover
		return
	if _state == State.CAST:
		if not _cast_released:
			_release_cast()
		_state = State.CHASE
		_cast_timer = data.cast_interval
		if _has_summon:
			_summon_timer = maxf(_summon_timer, SPECIAL_GAP)
		sprite.play("run_" + DIR8_NAMES[_dir8_idx])
		return
	if _state == State.SUMMON:
		if not _summon_released:
			_release_summon()
		_state = State.CHASE
		_summon_timer = data.summon_interval
		if _has_cast:
			_cast_timer = maxf(_cast_timer, SPECIAL_GAP)
		sprite.play("run_" + DIR8_NAMES[_dir8_idx])
		return
	if _state == State.THROW:
		if not _throw_released:
			_release_throw()
		_state = State.CHASE
		_throw_timer = data.throw_interval
		sprite.play("run_" + DIR8_NAMES[_dir8_idx])
		return
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
		return
	if data:
		if Time.get_ticks_msec() >= _summon_sound_until:
			Audio.play_sfx(data.get_hit_sound())
		_check_spill()

# Canın her spill_health_step kadarı gidince sikke saçar (tek vuruşta birden çok eşik geçilirse hepsi birlikte)
func _check_spill() -> void:
	if data.spill_health_step <= 0.0 or data.spill_value <= 0:
		return
	var step := maxi(roundi(max_health * data.spill_health_step), 1)
	var total := 0
	while health <= _spill_next and _spill_next > 0:
		total += data.spill_value
		_spill_next -= step
	if total > 0:
		EventBus.coins_spilled.emit(global_position, total)
		Audio.play_sfx(data.spill_sound)

func die() -> void:
	# Aynı karede iki vuruş gelirse iki kez ölmesin (çift altın / çift ses olmasın)
	if _dying:
		return
	_dying = true
	if data:
		if data.is_boss:
			Audio.stop_music(BOSS_DEATH_MUSIC_FADE)  # boss müziği ölüm sesinden önce kesilir
			EventBus.boss_defeated.emit(data.id)  # Steam başarımı vb. için (ör. "moloch")
			for p in get_tree().get_nodes_in_group("enemy_projectile"):
				p.queue_free()  # havadaki sikkeler dalga sonunda (tüccar inerken) oyuncuya çarpmasın
			for m in get_tree().get_nodes_in_group(MINION_GROUP):
				m.queue_free()  # çağrılmış sinekler boss'la birlikte gider (altınsız, sessiz)
		Audio.play_sfx(data.get_death_sound())
	EventBus.enemy_died.emit(global_position, coin_value)
	queue_free()

func _flash() -> void:
	sprite.modulate = Color(3, 3, 3)  # kısa süreli parlama
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_color, 0.1)
