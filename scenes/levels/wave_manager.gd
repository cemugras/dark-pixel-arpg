extends Node

enum Mode { TIMED, CLEAR_ALL }

@export var enemy_scene: PackedScene
@export var enemy_pool: Array[EnemyData] = []
@export var boss_pool: Array[EnemyData] = []
@export var boss_every: int = 10                # kaç dalgada bir boss (0 = boss yok)
@export var mode: Mode = Mode.TIMED
@export var start_wave: int = 1                 # test için: 50 yaparsan oyun 50. dalgadan başlar
@export var max_wave: int = 100
@export var spawn_area: Rect2 = Rect2(-152, -152, 304, 304)
@export var min_spawn_distance: float = 120.0
@export var break_time: float = 1.0             # dalga sonu altınların toplanması için bekleme

var wave: int = 0
var wave_active: bool = false
var is_boss_wave: bool = false
var time_left: float = 0.0
var enemies_left_to_spawn: int = 0

var _spawn_timer: float = 0.0
var spawning_stopped: bool = false   # doğma bitti, kalan düşmanlar bekleniyor
var _in_break: bool = false
var _break_left: float = 0.0
var _player: Node2D
var _boss: Node = null

func _ready() -> void:
	add_to_group("wave_manager")
	EventBus.next_wave_requested.connect(start_next_wave)
	wave = start_wave - 1
	start_next_wave.call_deferred()

func start_next_wave() -> void:
	wave += 1
	if wave > max_wave:
		print("Tüm dalgalar tamamlandı!")
		return

	_player = get_tree().get_first_node_in_group("player")
	wave_active = true
	spawning_stopped = false
	_spawn_timer = 0.0
	is_boss_wave = boss_every > 0 and wave % boss_every == 0

	if mode == Mode.TIMED:
		time_left = _wave_duration(wave)
	else:
		enemies_left_to_spawn = _enemy_count(wave)

	if is_boss_wave:
		_spawn_boss()

	EventBus.wave_started.emit(wave)

func _physics_process(delta: float) -> void:
	if _in_break:
		_break_left -= delta
		if _break_left <= 0.0:
			_in_break = false
			EventBus.shop_requested.emit(wave)
		return

	if not wave_active:
		return

	if spawning_stopped:
		# Doğma bitti: kalan düşmanlar öldürülünce dalga biter
		if get_tree().get_nodes_in_group("enemy").is_empty():
			_end_wave()
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _can_spawn():
		_spawn_enemy()
		var interval := _spawn_interval(wave)
		_spawn_timer = interval * (2.0 if is_boss_wave else 1.0)  # boss dalgasında daha seyrek

	if is_boss_wave:
		if not _is_boss_alive():
			spawning_stopped = true
	elif mode == Mode.TIMED:
		time_left -= delta
		if time_left <= 0.0:
			spawning_stopped = true
	elif enemies_left_to_spawn <= 0:
		spawning_stopped = true

func _can_spawn() -> bool:
	return mode == Mode.TIMED or is_boss_wave or enemies_left_to_spawn > 0

func _spawn_enemy() -> void:
	var data := _pick_enemy_data()
	if data == null:
		return

	if mode == Mode.CLEAR_ALL and not is_boss_wave:
		enemies_left_to_spawn -= 1

	var enemy := enemy_scene.instantiate()
	enemy.setup(data, wave)
	enemy.position = _random_spawn_position()
	add_child(enemy)

func _spawn_boss() -> void:
	var data := _pick_boss_data()
	if data == null:
		is_boss_wave = false  # boss tanımlı değilse normal dalga olarak devam et
		return

	_boss = enemy_scene.instantiate()
	_boss.setup(data, wave)
	_boss.position = _random_spawn_position()
	add_child(_boss)
	EventBus.boss_spawned.emit(_boss)

func _is_boss_alive() -> bool:
	return is_instance_valid(_boss) and not _boss.is_queued_for_deletion()

# Bu dalgada doğabilecek türlerden ağırlığa göre rastgele seç
func _pick_enemy_data() -> EnemyData:
	var candidates: Array[EnemyData] = []
	var total_weight := 0.0
	for e in enemy_pool:
		if not e.is_boss and wave >= e.min_wave and wave <= e.max_wave:
			candidates.append(e)
			total_weight += e.spawn_weight

	if candidates.is_empty():
		return null

	var roll := randf() * total_weight
	for e in candidates:
		roll -= e.spawn_weight
		if roll <= 0.0:
			return e
	return candidates.back()

# Önce tam o dalgaya ait boss, yoksa daha önceki en yakın boss, o da yoksa ilk boss
func _pick_boss_data() -> EnemyData:
	var best: EnemyData = null
	var fallback: EnemyData = null
	for e in boss_pool:
		if not e.is_boss:
			continue
		if fallback == null or e.boss_wave < fallback.boss_wave:
			fallback = e
		if e.boss_wave == wave:
			return e
		if e.boss_wave < wave and (best == null or e.boss_wave > best.boss_wave):
			best = e
	return best if best != null else fallback

func _random_spawn_position() -> Vector2:
	var pos := spawn_area.position
	for i in 10:
		pos = Vector2(
			randf_range(spawn_area.position.x, spawn_area.end.x),
			randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		if not is_instance_valid(_player) or pos.distance_to(_player.global_position) >= min_spawn_distance:
			break
	return pos

func _end_wave() -> void:
	wave_active = false
	is_boss_wave = false
	_boss = null
	get_tree().call_group("coin", "attract_to_player")
	EventBus.wave_ended.emit(wave)
	_in_break = true
	_break_left = break_time

# --- Zorluk formülleri (ayarlanabilir) ---

func _wave_duration(w: int) -> float:
	return minf(20.0 + 2.0 * (w - 1), 60.0)  # 20 sn'den başlar, 60 sn'ye kadar çıkar

func _enemy_count(w: int) -> int:
	return 5 + 2 * w                          # "hepsini öldür" modunda dalgadaki toplam düşman

func _spawn_interval(w: int) -> float:
	return maxf(0.25, 1.2 - 0.015 * w)        # dalga ilerledikçe daha sık doğarlar
