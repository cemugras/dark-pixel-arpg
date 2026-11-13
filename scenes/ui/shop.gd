extends CanvasLayer

@onready var title_label: Label = $Background/MarginContainer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $Background/MarginContainer/VBoxContainer/GoldLabel
@onready var upgrade_list: GridContainer = $Background/MarginContainer/VBoxContainer/UpgradeList
@onready var next_wave_button: Button = $Background/MarginContainer/VBoxContainer/NextWaveButton

var _buttons: Dictionary = {}  # geliştirme id -> Button

var _upgrades: Array[UpgradeData] = []

var _weapons: Array[WeaponData] = []
var _weapons_label: Label
var _slot_row: HBoxContainer      # silah sütunları: Melee, Slot 1, Slot 2 (her yenilemede yeniden kurulur)

# Fiyatlarda "gold" yazısı yerine sabit sikke ikonu. Button resim gösteremediği için metin,
# butonun içine yerleştirilen RichTextLabel'a ([img] etiketiyle) yazılır.
const COIN_ICON_PATH: String = "res://assets/sprites/gold/coin_icon.png"
const COIN_ICON: Texture2D = preload("res://assets/sprites/gold/coin_icon.png")
const PRICE_ICON_SIZE: int = 10       # buton içindeki sikke (ikon 20 px, yarısı: piksel bozulmaz)
const HEADER_ICON_SIZE: int = 20      # üstteki altın satırındaki sikke
const BUTTON_FONT_SIZE: int = 8
const BUTTON_MIN_HEIGHT: float = 30.0
const WEAPON_ICON_WIDTH: int = 48     # silah görselli butonlarda yazı bu genişliğin sağından başlar

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun dururken de çalışsın
	visible = false

	EventBus.shop_requested.connect(open)
	GameState.gold_changed.connect(func(_amount: int) -> void: _refresh())
	GameState.stats_changed.connect(_refresh)
	GameState.weapons_changed.connect(_refresh)
	next_wave_button.pressed.connect(_on_next_wave_pressed)

	_build_gold_header()
	_build_buttons()
	_build_weapon_section()

# Üstteki altın satırı: sabit sikke ikonu + sayı (shop.tscn'e dokunmamak için GoldLabel koddan bir HBox'a taşınır)
func _build_gold_header() -> void:
	var vbox := gold_label.get_parent()
	var row := HBoxContainer.new()
	row.name = "GoldRow"
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)
	vbox.move_child(row, gold_label.get_index())
	gold_label.reparent(row)
	var icon := TextureRect.new()
	icon.texture = COIN_ICON
	icon.custom_minimum_size = Vector2(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.move_child(icon, 0)
	gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

# "50 [sikke]" ; plus = true ise "+50 [sikke]" (satış iadesi)
func _price(amount: int, plus: bool = false) -> String:
	return "%s%d [img=%dx%d]%s[/img]" % ["+" if plus else "", amount, PRICE_ICON_SIZE, PRICE_ICON_SIZE, COIN_ICON_PATH]

# Butonun yazısını sikke ikonlu zengin metin olarak ayarlar (Button.text boş kalır)
func _set_button_text(button: Button, bbcode: String) -> void:
	button.text = ""
	var rich := button.get_node_or_null("Rich") as RichTextLabel
	if rich == null:
		rich = RichTextLabel.new()
		rich.name = "Rich"
		rich.bbcode_enabled = true
		rich.scroll_active = false
		rich.autowrap_mode = TextServer.AUTOWRAP_OFF
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rich.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rich.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rich.add_theme_font_size_override("normal_font_size", BUTTON_FONT_SIZE)
		button.add_child(rich)
		rich.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rich.offset_left = WEAPON_ICON_WIDTH + 4 if button.icon else 2
	rich.text = bbcode
	rich.modulate.a = 0.5 if button.disabled else 1.0  # pasif buton soluk görünsün
	_fit_button(button)

# Button.text boş olduğu için en küçük boyut yazıdan gelmez: zengin metnin ölçüsü fonttan hesaplanır
func _fit_button(button: Button) -> void:
	var rich := button.get_node_or_null("Rich") as RichTextLabel
	if rich == null:
		return
	var font := rich.get_theme_font("normal_font")
	var lines := rich.get_parsed_text().split("\n")
	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, BUTTON_FONT_SIZE).x)
	width += PRICE_ICON_SIZE + 4  # satırdaki sikke ikonu
	var height := lines.size() * font.get_height(BUTTON_FONT_SIZE) + 8.0
	button.custom_minimum_size = Vector2(
		maxf(button.custom_minimum_size.x, width + rich.offset_left + 8.0),
		maxf(button.custom_minimum_size.y, maxf(height, BUTTON_MIN_HEIGHT)))

# Silah bölümleri koddan eklenir (shop.tscn'e dokunmamak için), Next Wave butonunun üstüne
func _build_weapon_section() -> void:
	_weapons = WeaponPool.load_all()

	_weapons_label = _add_label("Weapons (selling refunds 50% of everything spent on it)")
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 8)
	var vbox := next_wave_button.get_parent()
	vbox.add_child(_slot_row)
	vbox.move_child(_slot_row, next_wave_button.get_index())

func _add_label(text: String) -> Label:
	var vbox := next_wave_button.get_parent()
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(label)
	vbox.move_child(label, next_wave_button.get_index())
	return label

# Genel geliştirmeler ızgarası: sadece scope "" olanlar (Max Health, Regen, Armor, Speed).
# Silah geliştirmeleri ilgili silah sütununun altında gösterilir.
func _build_buttons() -> void:
	for upgrade in UpgradePool.load_all():
		if upgrade.scope == "":
			_upgrades.append(upgrade)
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
	gold_label.text = "%d" % GameState.gold
	for upgrade in _upgrades:
		var button: Button = _buttons[upgrade.id]
		var cost := GameState.get_upgrade_cost(upgrade)
		var level: int = GameState.upgrade_levels.get(upgrade.id, 0)
		var locked := not GameState.meets_requirement(upgrade.requires)
		var info := ("Requires %s" % upgrade.requires) if locked else upgrade.description
		button.disabled = locked or GameState.gold < cost
		_set_button_text(button, "%s (Lv %d) - %s\n%s" % [upgrade.display_name, level, _price(cost), info])

	_refresh_slots()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _make_button(parent: Node, text: String, disabled: bool, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 8)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	_set_button_text(button, text)
	return button

# Sahip olunan silah butonunun solunda silahın görseli (hangi yuvada ne var karışmasın)
func _set_weapon_icon(button: Button, weapon: WeaponData) -> void:
	if weapon == null or weapon.icon == null:
		return
	button.icon = weapon.icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", WEAPON_ICON_WIDTH)
	button.custom_minimum_size.y = 40
	var rich := button.get_node_or_null("Rich") as Control
	if rich:
		rich.offset_left = WEAPON_ICON_WIDTH + 4  # yazı silah görselinin üstüne binmesin
		_fit_button(button)

# Silah sütunları her zaman üç tane: Melee, Slot 1, Slot 2. Başlığın altında:
# - dolu sütun: silah (Sell), o silahın geliştirmeleri ve (menzilli ise) gümüş mermi + başka silahla değiştirme
# - boş sütun: o yuvaya alınabilecek silahlar. Menzilli silah her zaman ilk boş yuvaya girdiği için
#   satın alma listesi sadece ilk boş menzilli yuvada görünür, sonraki boş yuvada "Empty" yazar.
# Son silah satılamaz.
func _refresh_slots() -> void:
	_clear(_slot_row)
	var can_sell := GameState.can_sell_weapon()
	var last_text := "\nLast weapon, can't sell" if not can_sell else ""

	# Melee
	var melee := _add_slot_column("Melee")
	var sword := _sword_data()
	if GameState.has_sword():
		var text := "Sword x%d\nSell (%s)%s" % [GameState.stats.sword_count, _price(GameState.get_sword_sell_price(), true), last_text]
		_set_weapon_icon(_make_button(melee, text, not can_sell, _on_sell_sword_pressed), sword)
		for upgrade in _scoped_upgrades("melee"):
			var cost := GameState.get_upgrade_cost(upgrade)
			var level: int = GameState.upgrade_levels.get(upgrade.id, 0)
			var up_text := "%s (Lv %d) - %s\n%s" % [upgrade.display_name, level, _price(cost), upgrade.description]
			_make_button(melee, up_text, GameState.gold < cost, _on_upgrade_pressed.bind(upgrade))
	elif sword:
		var text := "Buy %s - %s\n%s" % [sword.display_name, _price(sword.cost), sword.description]
		_set_weapon_icon(_make_button(melee, text, GameState.gold < sword.cost, _on_weapon_pressed.bind(sword)), sword)

	# Menzilli silah yuvaları
	for slot in GameState.MAX_GUNS:
		var column := _add_slot_column("Slot %d" % (slot + 1))
		if slot < GameState.guns.size():
			_fill_gun_column(column, slot, can_sell, last_text)
		elif slot == GameState.guns.size():
			for weapon in _weapons:
				if weapon.is_melee:
					continue
				var text := "Buy %s - %s\n%s" % [weapon.display_name, _price(weapon.cost), weapon.description]
				_set_weapon_icon(_make_button(column, text, GameState.gold < weapon.cost, _on_weapon_pressed.bind(weapon)), weapon)
		else:
			_add_column_note(column, "Empty")

func _fill_gun_column(column: VBoxContainer, slot: int, can_sell: bool, last_text: String) -> void:
	var gun := GameState.guns[slot]
	var silver := GameState.has_silver(slot)
	var gun_name := gun.display_name + (" (Silver)" if silver else "")
	var text := "%s\nSell (%s)%s" % [gun_name, _price(GameState.get_gun_sell_price(slot), true), last_text]
	_set_weapon_icon(_make_button(column, text, not can_sell, _on_sell_gun_pressed.bind(slot)), gun)

	# Bu silahın geliştirmeleri (yarı fiyat, sadece bu silaha)
	for upgrade in _scoped_upgrades("gun"):
		var cost := GameState.get_gun_upgrade_cost(slot, upgrade)
		var level := GameState.get_gun_upgrade_level(slot, upgrade)
		var up_text := "%s (Lv %d) - %s\n%s" % [upgrade.display_name, level, _price(cost), upgrade.description]
		_make_button(column, up_text, not GameState.can_buy_gun_upgrade(slot, upgrade), _on_gun_upgrade_pressed.bind(slot, upgrade))

	# Gümüş mermi: tek seferlik
	var silver_text := "Silver Bullets\nOwned" if silver \
		else "Silver Bullets - %s\nx2 damage, bright bullets" % _price(GameState.SILVER_COST)
	_make_button(column, silver_text, not GameState.can_buy_silver(slot), _on_silver_pressed.bind(slot))

	# Başka silahla değiştirme (eski silahın harcamasının yarısı fiyattan düşer, geliştirmeler silahla gider)
	for weapon in _weapons:
		if weapon.is_melee or weapon.id == gun.id:
			continue
		var net := GameState.get_swap_cost(slot, weapon)
		var price := _price(net) if net >= 0 else _price(-net, true)
		var swap_text := "Replace with %s - %s\n%s" % [weapon.display_name, price, weapon.description]
		_make_button(column, swap_text, not GameState.can_swap_gun(slot, weapon), _on_swap_pressed.bind(slot, weapon))

func _scoped_upgrades(scope: String) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade in UpgradePool.load_all():
		if upgrade.scope == scope:
			result.append(upgrade)
	return result

# Bir silah sütunu: üstte başlık (Melee / Slot 1 / Slot 2), altında o yuvanın butonları
func _add_slot_column(title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	column.add_child(label)
	_slot_row.add_child(column)
	return column

func _add_column_note(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.5
	label.add_theme_font_size_override("font_size", 8)
	column.add_child(label)

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

func _on_gun_upgrade_pressed(slot: int, upgrade: UpgradeData) -> void:
	if GameState.buy_gun_upgrade(slot, upgrade):
		Audio.play_sfx("ui_click")

func _on_silver_pressed(slot: int) -> void:
	if GameState.buy_silver(slot):
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
