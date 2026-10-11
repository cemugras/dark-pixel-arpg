extends CanvasLayer

@onready var title_label: Label = $Background/MarginContainer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $Background/MarginContainer/VBoxContainer/GoldLabel
@onready var upgrade_list: GridContainer = $Background/MarginContainer/VBoxContainer/UpgradeList
@onready var next_wave_button: Button = $Background/MarginContainer/VBoxContainer/NextWaveButton

var _buttons: Dictionary = {}  # geliştirme id -> Button

var _upgrades: Array[UpgradeData] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun dururken de çalışsın
	visible = false

	EventBus.shop_requested.connect(open)
	GameState.gold_changed.connect(func(_amount: int) -> void: _refresh())
	GameState.stats_changed.connect(_refresh)
	next_wave_button.pressed.connect(_on_next_wave_pressed)

	_build_buttons()

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
		button.text = "%s (Lv %d) - %d gold\n%s" % [upgrade.display_name, level, cost, upgrade.description]
		button.disabled = GameState.gold < cost

func _on_upgrade_pressed(upgrade: UpgradeData) -> void:
	GameState.buy_upgrade(upgrade)

func _on_next_wave_pressed() -> void:
	visible = false
	get_tree().paused = false
	EventBus.next_wave_requested.emit()
