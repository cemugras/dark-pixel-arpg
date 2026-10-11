extends Node

enum Mode { TIMED, CLEAR_ALL }

@export var enemy_scene: PackedScene
@export var mode: Mode = Mode.TIMED
@export var start_wave: int = 1                 # test için: 50 yaparsan oyun 50. dalgadan başlar
@export var max_wave: int = 100
@export var spawn_area: Rect2 = Rect2(16, 16, 1568, 1568)  # düşmanların doğabileceği alan (x, y, genişlik, yükseklik)
@export var min_spawn_distance: float = 120.0   # oyuncuya en az bu kadar uzakta doğsunlar
@export var break_time: float = 3.0             # dalgalar arası bekleme (mağazayı yazınca değişecek)

var wave: int = 0
var wave_active: bool = false
var time_left: float = 0.0
var enemies_left_to_spawn: int = 0

var _spawn_timer: float = 0.0
var _in_break: bool = false
var _break_left: float = 0.0
var _player: Node2D

func _ready() -> void:
	add_to_group("wave_manager")
	wave = start_wave - 1
	start_next_wave.call_deferred()

func start_next_wave() -> void:
	wave += 1
	if wave > max_wave:
		print("Tüm dalgalar tamamlandı!")
		return

	_player = get_tree().get_first_node_in_group("player")
	wave_active = true
	_spawn_timer = 0.0

	if mode == Mode.TIMED:
		time_left = _wave_duration(wave)
	else:
		enemies_left_to_spawn = _enemy_count(wave)

	EventBus.wave_started.emit(wave)
	print("Dalga ", wave, " başladı")

func _physics_process(delta: float) -> void:
	if _in_break:
		_break_left -= delta
		if _break_left <= 0.0:
			_in_break = false
			start_next_wave()
		return

	if not wave_active:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _can_spawn():
		_spawn_enemy()
		_spawn_timer = _spawn_interval(wave)

	if mode == Mode.TIMED:
		time_left -= delta
		if time_left <= 0.0:
			_end_wave()
	elif enemies_left_to_spawn <= 0 and get_tree().get_nodes_in_group("enemy").is_empty():
		_end_wave()

func _can_spawn() -> bool:
	return mode == Mode.TIMED or enemies_left_to_spawn > 0

func _spawn_enemy() -> void:
	if mode == Mode.CLEAR_ALL:
		enemies_left_to_spawn -= 1

	var enemy := enemy_scene.instantiate()
	enemy.setup(wave)
	enemy.position = _random_spawn_position()  # sahneye eklemeden ÖNCE konumlandır
	add_child(enemy)

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
	get_tree().call_group("enemy", "queue_free")      # süreli modda kalan düşmanlar silinir
	get_tree().call_group("coin", "attract_to_player")
	EventBus.wave_ended.emit(wave)
	print("Dalga ", wave, " bitti")
	_in_break = true
	_break_left = break_time

# --- Zorluk formülleri (ayarlanabilir) ---

func _wave_duration(w: int) -> float:
	return minf(20.0 + 2.0 * (w - 1), 60.0)  # 20 sn'den başlar, 60 sn'ye kadar çıkar

func _enemy_count(w: int) -> int:
	return 5 + 2 * w                          # "hepsini öldür" modunda dalgadaki toplam düşman

func _spawn_interval(w: int) -> float:
	return maxf(0.25, 1.2 - 0.015 * w)        # dalga ilerledikçe daha sık doğarlar
