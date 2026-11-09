extends CanvasLayer

@onready var title_label: Label = $Background/MarginContainer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $Background/MarginContainer/VBoxContainer/GoldLabel
@onready var upgrade_list: GridContainer = $Background/MarginContainer/VBoxContainer/UpgradeList
@onready var next_wave_button: Button = $Background/MarginContainer/VBoxContainer/NextWaveButton

var _buttons: Dictionary = {}  # geliştirme id -> Button

var _upgrades: Array[UpgradeData] = []

var _weapons: Array[WeaponData] = []
var _weapon_buttons: Dictionary = {}  # silah id -> Button
var _weapons_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun dururken de çalışsın
	visible = false

	EventBus.shop_requested.connect(open)
	GameState.gold_changed.connect(func(_amount: int) -> void: _refresh())
	GameState.stats_changed.connect(_refresh)
	GameState.weapons_changed.connect(_refresh)
	next_wave_button.pressed.connect(_on_next_wave_pressed)

	_build_buttons()
	_build_weapon_buttons()

# Silah bölümü koddan eklenir (shop.tscn'e dokunmamak için), Next Wave butonunun üstüne
func _build_weapon_buttons() -> void:
	var vbox := next_wave_button.get_parent()

	_weapons_label = Label.new()
	_weapons_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_weapons_label)
	vbox.move_child(_weapons_label, next_wave_button.get_index())

	var weapon_list := GridContainer.new()
	weapon_list.columns = 2
	vbox.add_child(weapon_list)
	vbox.move_child(weapon_list, next_wave_button.get_index())

	_weapons = WeaponPool.load_all()
	for weapon in _weapons:
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 8)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_weapon_pressed.bind(weapon))
		weapon_list.add_child(button)
		_weapon_buttons[weapon.id] = button

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

	_weapons_label.text = "Weapons (gun slots %d/%d)" % [GameState.guns.size(), GameState.MAX_GUNS]
	for weapon in _weapons:
		var button: Button = _weapon_buttons[weapon.id]
		var status := ""
		if weapon.is_melee and GameState.has_sword():
			status = "Owned"
		elif not weapon.is_melee and GameState.gun_slots_full():
			status = "Gun slots full"
		var info := status if status != "" else weapon.description
		button.text = "%s - %d gold\n%s" % [weapon.display_name, weapon.cost, info]
		button.disabled = status != "" or GameState.gold < weapon.cost

func _on_upgrade_pressed(upgrade: UpgradeData) -> void:
	GameState.buy_upgrade(upgrade)

func _on_weapon_pressed(weapon: WeaponData) -> void:
	GameState.buy_weapon(weapon)

func _on_next_wave_pressed() -> void:
	visible = false
	get_tree().paused = false
	EventBus.next_wave_requested.emit()
