extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var resume_button: Button = $Center/VBox/ResumeButton
@onready var main_menu_button: Button = $Center/VBox/MainMenuButton
@onready var center: CenterContainer = $Center

var _options_button: Button
var _options: OptionsMenu

func _ready() -> void:
	# Oyun durunca bu menü çalışmaya devam etmeli
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")  # HUD'daki pause butonu buradan bulur
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	_build_options()

# Options butonu koddan eklenir (Resume ile Main Menu arasına); tscn değişmez
func _build_options() -> void:
	_options_button = Button.new()
	_options_button.text = "Options"
	_options_button.custom_minimum_size = resume_button.custom_minimum_size
	_options_button.pressed.connect(_on_options_pressed)
	center.get_node("VBox").add_child(_options_button)
	center.get_node("VBox").move_child(_options_button, main_menu_button.get_index())

	_options = OptionsMenu.new()
	add_child(_options)
	_options.closed.connect(_on_options_closed)

func _on_options_pressed() -> void:
	Audio.play_sfx("ui_click")
	center.hide()  # Options açıkken pause butonları arkada görünmesin
	_options.open()

func _on_options_closed() -> void:
	center.show()
	_options_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _options.visible:
		return  # Esc'i Options ekranı kendisi işler (geri döner)
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
