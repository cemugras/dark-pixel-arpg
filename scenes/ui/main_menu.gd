extends Control

# Oyun açılınca ilk gelen ekran. Arayüz koddan kurulur (main_menu.tscn sadece kök düğüm).
const GAME_SCENE: String = "res://scenes/levels/main.tscn"
const MENU_MUSIC: String = "menu"

var _play_button: Button
var _options_button: Button
var _options: OptionsMenu

func _ready() -> void:
	get_tree().paused = false  # pause menüsünden dönülürse oyun durmuş kalmasın
	_build_ui()
	Audio.play_music(MENU_MUSIC)
	_play_button.grab_focus.call_deferred()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.02, 0.02)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "HELLSTAKE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.85, 0.12, 0.08))
	vbox.add_child(title)

	# Başlık ile butonlar arası boşluk
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	_play_button = _add_button(vbox, "Play", _on_play_pressed)
	_options_button = _add_button(vbox, "Options", _on_options_pressed)
	_add_button(vbox, "Quit", _on_quit_pressed)

	_options = OptionsMenu.new()
	add_child(_options)
	_options.closed.connect(func() -> void: _options_button.grab_focus())

func _add_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button

func _on_play_pressed() -> void:
	Audio.play_sfx("ui_click")
	Audio.stop_music()
	GameState.reset()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_options_pressed() -> void:
	Audio.play_sfx("ui_click")
	_options.open()

func _on_quit_pressed() -> void:
	Audio.play_sfx("ui_click")
	get_tree().quit()
