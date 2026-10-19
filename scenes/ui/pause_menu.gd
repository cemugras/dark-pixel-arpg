extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"  # 17c'de yapacağız

@onready var resume_button: Button = $Center/VBox/ResumeButton
@onready var main_menu_button: Button = $Center/VBox/MainMenuButton

func _ready() -> void:
	# Oyun durunca bu menü çalışmaya devam etmeli
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(resume)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		resume()
	elif not get_tree().paused:
		# Oyuncu öldüyse (Game Over bekleniyorsa) duraklatma açma
		var player := get_tree().get_first_node_in_group("player")
		if player and player.is_dead:
			return
		pause()
	get_viewport().set_input_as_handled()

func pause() -> void:
	get_tree().paused = true
	visible = true
	resume_button.grab_focus()

func resume() -> void:
	get_tree().paused = false
	visible = false

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	# GameState içindeki altın, dalga, istatistikleri sıfırlayan bir fonksiyon çağıracağız (aşağıya bak)
	if GameState.has_method("reset"):
		GameState.reset()
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		print("Ana menü sahnesi henüz yok (17c'de yapılacak)")
