extends CanvasLayer

@onready var title_label: Label = $Background/MarginContainer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $Background/MarginContainer/VBoxContainer/GoldLabel
@onready var upgrade_list: GridContainer = $Background/MarginContainer/VBoxContainer/UpgradeList
@onready var next_wave_button: Button = $Background/MarginContainer/VBoxContainer/NextWaveButton

var _buttons: Dictionary = {}  # geliştirme id -> Button

var _upgrades: Array[UpgradeData] = []

var _weapons: Array[WeaponData] = []
var _weapons_label: Label
var _weapon_list: GridContainer   # satın alma / değiştirme butonları (her yenilemede yeniden kurulur)
var _owned_label: Label
var _owned_list: GridContainer    # sahip olunan silahlar: satma butonları

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun dururken de çalışsın
	visible = false

	EventBus.shop_requested.connect(open)
	GameState.gold_changed.connect(func(_amount: int) -> void: _refresh())
	GameState.stats_changed.connect(_refresh)
	GameState.weapons_changed.connect(_refresh)
	next_wave_button.pressed.connect(_on_next_wave_pressed)

	_build_buttons()
	_build_weapon_section()

# Silah bölümleri koddan eklenir (shop.tscn'e dokunmamak için), Next Wave butonunun üstüne
func _build_weapon_section() -> void:
	_weapons = WeaponPool.load_all()

	_owned_label = _add_label("Your weapons (sell refunds 50% of everything spent on it)")
	_owned_list = _add_grid(3)
	_weapons_label = _add_label("")
	_weapon_list = _add_grid(2)

func _add_label(text: String) -> Label:
	var vbox := next_wave_button.get_parent()
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(label)
	vbox.move_child(label, next_wave_button.get_index())
	return label

func _add_grid(columns: int) -> GridContainer:
	var vbox := next_wave_button.get_parent()
	var grid := GridContainer.new()
	grid.columns = columns
	vbox.add_child(grid)
	vbox.move_child(grid, next_wave_button.get_index())
	return grid

func _build_buttons() -> void:
	_upgrades = UpgradePool.load_all()
	for upgrade in _upgrades:
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 8)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_upgrade_pressed.bind(upgrade))
		upgrade_list.add_child(button)
		_buttons[upgrade.id] = button

func open(wave: int) -> void:
	title_label.text = "Wave %d complete" % wave
	visible = true
	get_tree().paused = true
	_refresh()

func _refresh() -> void:
	if not visible:
		return
	gold_label.text = "Gold: %d" % GameState.gold
	for upgrade in _upgrades:
		var button: Button = _buttons[upgrade.id]
		var cost := GameState.get_upgrade_cost(upgrade)
		var level: int = GameState.upgrade_levels.get(upgrade.id, 0)
		var locked := not GameState.meets_requirement(upgrade.requires)
		var info := ("Requires %s" % upgrade.requires) if locked else upgrade.description
		button.text = "%s (Lv %d) - %d gold\n%s" % [upgrade.display_name, level, cost, info]
		button.disabled = locked or GameState.gold < cost

	_refresh_owned()
	_refresh_weapon_list()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _make_button(parent: Node, text: String, disabled: bool, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 8)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text
	button.disabled = disabled
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button

# Sahip olunan silah butonunun solunda silahın görseli (hangi yuvada ne var karışmasın)
func _set_weapon_icon(button: Button, weapon: WeaponData) -> void:
	if weapon == null or weapon.icon == null:
		return
	button.icon = weapon.icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 48)
	button.custom_minimum_size.y = 40

# Sahip olunan silahlar: her biri için "Sell (+X)" butonu. Son silah satılamaz.
func _refresh_owned() -> void:
	_clear(_owned_list)
	var can_sell := GameState.can_sell_weapon()
	var last_text := "\nLast weapon, can't sell" if not can_sell else ""

	for slot in GameState.guns.size():
		var gun := GameState.guns[slot]
		var text := "Slot %d: %s\nSell (+%d gold)%s" % [slot + 1, gun.display_name, GameState.get_gun_sell_price(slot), last_text]
		var button := _make_button(_owned_list, text, not can_sell, _on_sell_gun_pressed.bind(slot))
		_set_weapon_icon(button, gun)

	if GameState.has_sword():
		var text := "Sword x%d\nSell (+%d gold)%s" % [GameState.stats.sword_count, GameState.get_sword_sell_price(), last_text]
		var button := _make_button(_owned_list, text, not can_sell, _on_sell_sword_pressed)
		_set_weapon_icon(button, _sword_data())

# Satın alma; yuvalar doluyken menzilli silahlar "değiştir" butonu olarak görünür
func _refresh_weapon_list() -> void:
	_clear(_weapon_list)
	_weapons_label.text = "Weapons (gun slots %d/%d)" % [GameState.guns.size(), GameState.MAX_GUNS]

	for weapon in _weapons:
		if weapon.is_melee:
			var owned := GameState.has_sword()
			var info := "Owned" if owned else weapon.description
			var text := "%s - %d gold\n%s" % [weapon.display_name, weapon.cost, info]
			_make_button(_weapon_list, text, owned or GameState.gold < weapon.cost, _on_weapon_pressed.bind(weapon))
		elif not GameState.gun_slots_full():
			var text := "%s - %d gold\n%s" % [weapon.display_name, weapon.cost, weapon.description]
			_make_button(_weapon_list, text, GameState.gold < weapon.cost, _on_weapon_pressed.bind(weapon))
		else:
			# Yuvalar dolu: her farklı silahlı yuva için bir değiştirme butonu
			for slot in GameState.guns.size():
				var old := GameState.guns[slot]
				if old.id == weapon.id:
					continue
				var net := GameState.get_swap_cost(slot, weapon)
				var price := ("%d gold" % net) if net >= 0 else ("+%d gold" % -net)
				var text := "%s: replace %s (slot %d)\n%s" % [weapon.display_name, old.display_name, slot + 1, price]
				_make_button(_weapon_list, text, not GameState.can_swap_gun(slot, weapon), _on_swap_pressed.bind(slot, weapon))

func _sword_data() -> WeaponData:
	for weapon in _weapons:
		if weapon.is_melee:
			return weapon
	return null

# Alım/satım sesi sadece işlem başarılı olunca çalar (para yetmezse ses yok)
func _on_upgrade_pressed(upgrade: UpgradeData) -> void:
	if GameState.buy_upgrade(upgrade):
		Audio.play_sfx("ui_click")

func _on_weapon_pressed(weapon: WeaponData) -> void:
	if GameState.buy_weapon(weapon):
		Audio.play_sfx("ui_click")

func _on_sell_gun_pressed(slot: int) -> void:
	if GameState.sell_gun(slot):
		Audio.play_sfx("ui_click")

func _on_sell_sword_pressed() -> void:
	if GameState.sell_sword():
		Audio.play_sfx("ui_click")

func _on_swap_pressed(slot: int, weapon: WeaponData) -> void:
	if GameState.swap_gun(slot, weapon):
		Audio.play_sfx("ui_click")

func _on_next_wave_pressed() -> void:
	Audio.play_sfx("ui_click")
	visible = false
	get_tree().paused = false
	EventBus.next_wave_requested.emit()
