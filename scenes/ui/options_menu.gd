class_name OptionsMenu
extends CanvasLayer

# Options ekranı: ana menüden ve duraklatma menüsünden açılır. Arayüz koddan kurulur.
# Müzik ve oyun içi sesler (SFX) ayrı ayrı ayarlanır. Ayarlar kaydedilmez (bkz. Audio.set_bus_volume).
# Kullanım: var options := OptionsMenu.new(); add_child(options); options.closed.connect(...); options.open()

signal closed

const STEP: float = 0.1  # - / + butonlarının adımı (%10)

var _first_focus: Control

func _ready() -> void:
	layer = 30  # duraklatma menüsünün (20) üstünde
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun duraklatılmışken de çalışır
	visible = false
	_build_ui()

func open() -> void:
	visible = true
	_first_focus.grab_focus.call_deferred()

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		Audio.play_sfx("ui_click")
		close()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)  # arkadaki butonlara tıklanmasın diye fareyi yakalar

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.03, 0.03, 0.95)
	style.border_color = Color(0.55, 0.1, 0.06)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.12, 0.08))
	vbox.add_child(title)

	_first_focus = _add_volume_row(vbox, "Music", Audio.MUSIC_BUS)
	_add_volume_row(vbox, "Sound Effects", Audio.SFX_BUS)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(220, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void:
		Audio.play_sfx("ui_click")
		close())
	vbox.add_child(back)

# Bir satır: ad, -, kaydırıcı, +, yüzde. Kaydırıcıyı döndürür (ilk odak için).
func _add_volume_row(parent: Node, label_text: String, bus_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(160, 0)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)

	var minus := _small_button("-")
	row.add_child(minus)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = Audio.get_bus_volume(bus_name)
	row.add_child(slider)

	var plus := _small_button("+")
	row.add_child(plus)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.text = _percent(slider.value)
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		Audio.set_bus_volume(bus_name, v)
		value_label.text = _percent(v))
	# Kaydırıcı bırakılınca örnek ses: SFX'te yeni seviye duyulsun
	slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play_sfx("ui_click"))
	minus.pressed.connect(func() -> void:
		slider.value -= STEP
		Audio.play_sfx("ui_click"))
	plus.pressed.connect(func() -> void:
		slider.value += STEP
		Audio.play_sfx("ui_click"))
	return slider

func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(40, 40)
	button.add_theme_font_size_override("font_size", 20)
	return button

func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
