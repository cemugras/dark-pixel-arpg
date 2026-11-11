extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"  # 17c'de yapacağız

@onready var resume_button: Button = $Center/VBox/ResumeButton
@onready var main_menu_button: Button = $Center/VBox/MainMenuButton

func _ready() -> void:
	# Oyun durunca bu menü çalışmaya devam etmeli
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")  # HUD'daki pause butonu buradan bulur
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		resume()
	else:
		try_pause()
	get_viewport().set_input_as_handled()

# Esc ve ekrandaki pause butonu bunu kullanır. Mağaza/başka menü açıksa ya da oyuncu öldüyse açılmaz.
func try_pause() -> void:
	if visible or get_tree().paused:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.is_dead:
		return
	pause()

func pause() -> void:
	get_tree().paused = true
	visible = true
	resume_button.grab_focus()

func resume() -> void:
	get_tree().paused = false
	visible = false

func _on_resume_pressed() -> void:
	Audio.play_sfx("ui_click")
	resume()

func _on_main_menu_pressed() -> void:
	Audio.play_sfx("ui_click")
	get_tree().paused = false
	# GameState içindeki altın, dalga, istatistikleri sıfırlayan bir fonksiyon çağıracağız (aşağıya bak)
	if GameState.has_method("reset"):
		GameState.reset()
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		print("Ana menü sahnesi henüz yok (17c'de yapılacak)")
