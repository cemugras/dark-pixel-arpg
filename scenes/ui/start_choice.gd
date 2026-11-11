extends CanvasLayer

# Oyun başında seçilebilecek başlangıç silahları
const CHOICES: Array[String] = [
	"res://data/weapons/sword.tres",
	"res://data/weapons/glock.tres",
]

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun dururken de çalışsın
	get_tree().paused = true  # seçim yapılana kadar dalga başlamasın
	_build_ui()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Choose your starting weapon"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)

	for path in CHOICES:
		var weapon := load(path) as WeaponData
		var button := Button.new()
		button.text = "%s\n%s" % [weapon.display_name, weapon.description]
		button.icon = weapon.icon
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size = Vector2(180, 140)
		button.pressed.connect(_on_choice.bind(weapon))
		row.add_child(button)

	(row.get_child(0) as Button).grab_focus.call_deferred()

func _on_choice(weapon: WeaponData) -> void:
	Audio.play_sfx("ui_click")
	GameState.give_weapon(weapon)
	get_tree().paused = false
	queue_free()
