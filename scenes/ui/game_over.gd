extends CanvasLayer

@onready var wave_label: Label = $Background/CenterContainer/VBoxContainer/WaveLabel
@onready var retry_button: Button = $Background/CenterContainer/VBoxContainer/RetryButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun dururken de çalışsın
	visible = false
	EventBus.player_died.connect(_on_player_died)
	retry_button.pressed.connect(_on_retry_pressed)

func _on_player_died() -> void:
	var wave_manager := get_tree().get_first_node_in_group("wave_manager")
	var reached: int = wave_manager.wave if wave_manager else 0
	wave_label.text = "You reached wave %d" % reached

	await get_tree().create_timer(1.0).timeout  # ölüm anını görebilmek için kısa bekleme
	visible = true
	get_tree().paused = true

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
