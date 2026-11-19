class_name VictoryScreen
extends CanvasLayer

# Oyunun sonu: son dalga (100, Lucifer) bitince EventBus.game_won ile açılır. Sahne dosyası yok, main.gd koddan ekler.
# GEÇİCİ: asıl final ara sahnesi (Biscuit, Walt'ın evi) ayrıca düşünülüp yapılacak; şimdilik tahtta oturan Biscuit
# kısa bir süre görünür, ekran kararır, THE END ve Main Menu.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const HOLD_TIME: float = 2.5     # son dalga bitince sahne bu kadar görünür kalır (tahttaki Biscuit)
const FADE_TIME: float = 2.0
const TEXT_FADE_TIME: float = 1.2

var _dim: ColorRect
var _box: VBoxContainer
var _button: Button

func _ready() -> void:
	layer = 40  # HUD ve menülerin üstünde
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	EventBus.game_won.connect(_on_game_won)

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 22)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.modulate.a = 0.0
	center.add_child(_box)

	_box.add_child(_label("THE END", 66, Color(0.9, 0.12, 0.08)))
	_box.add_child(_label("Hell took his cat. Walt took it back.", 22, Color(0.9, 0.88, 0.85)))
	_box.add_child(_label("Thanks for playing Hellstake", 22, Color(0.6, 0.58, 0.56)))
	_button = Button.new()
	_button.text = "Main Menu"
	_button.add_theme_font_size_override("font_size", 22)
	_button.custom_minimum_size = Vector2(220, 0)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_main_menu_pressed)
	_box.add_child(_button)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _on_game_won() -> void:
	await get_tree().create_timer(HOLD_TIME).timeout
	visible = true
	get_tree().paused = true  # oyuncu ölmesin, pause menüsü açılmasın
	Audio.stop_music(FADE_TIME)
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 1.0, FADE_TIME)
	tw.tween_property(_box, "modulate:a", 1.0, TEXT_FADE_TIME)
	await tw.finished
	_button.grab_focus()

func _on_main_menu_pressed() -> void:
	Audio.play_sfx("ui_click")
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
