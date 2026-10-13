extends CanvasLayer

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var gold_label: Label = $MarginContainer/VBoxContainer/GoldLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var boss_bar: ProgressBar = $BossBar

var _boss: Node
var _wave_manager: Node

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_damaged)
	EventBus.wave_started.connect(_on_wave_started)
	GameState.gold_changed.connect(_on_gold_changed)
	
	EventBus.boss_spawned.connect(_on_boss_spawned)
	_style_bar(boss_bar, Color(0.8, 0.1, 0.1))
	_style_bar(health_bar, Color(0.2, 0.7, 0.2))
	boss_bar.hide()

	_wave_manager = get_tree().get_first_node_in_group("wave_manager")
	_refresh_initial.call_deferred()

# Oyun başında sinyal gelmeden önce değerleri doldur
func _refresh_initial() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_on_player_damaged(player.health, player.max_health)
	_on_gold_changed(GameState.gold)
	if _wave_manager:
		_on_wave_started(_wave_manager.wave)

func _process(_delta: float) -> void:
	if _boss != null:
		if is_instance_valid(_boss):
			boss_bar.value = _boss.health
		else:
			_boss = null
			boss_bar.hide()

	if _wave_manager == null:
		return

	if not _wave_manager.wave_active:
		timer_label.text = "Break"
	elif _wave_manager.spawning_stopped:
		timer_label.text = "Enemies: %d" % get_tree().get_nodes_in_group("enemy").size()
	elif _wave_manager.is_boss_wave:
		timer_label.text = "BOSS"
	elif _wave_manager.mode == _wave_manager.Mode.TIMED:
		timer_label.text = "Time: %d" % ceili(maxf(_wave_manager.time_left, 0.0))
	else:
		var remaining: int = _wave_manager.enemies_left_to_spawn + get_tree().get_nodes_in_group("enemy").size()
		timer_label.text = "Enemies: %d" % remaining

func _on_player_damaged(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "HP %d/%d" % [current, maximum]

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func _on_wave_started(wave: int) -> void:
	wave_label.text = "Wave %d" % wave

func _on_boss_spawned(boss: Node) -> void:
	_boss = boss
	boss_bar.max_value = boss.max_health
	boss_bar.value = boss.health
	boss_bar.show()

func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	bar.show_percentage = false
