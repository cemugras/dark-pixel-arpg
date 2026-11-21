extends CanvasLayer

@onready var title_label: Label = $Background/MarginContainer/VBoxContainer/TitleLabel
@onready var gold_label: Label = $Background/MarginContainer/VBoxContainer/GoldLabel
@onready var upgrade_list: GridContainer = $Background/MarginContainer/VBoxContainer/UpgradeList
@onready var next_wave_button: Button = $Background/MarginContainer/VBoxContainer/NextWaveButton

var _buttons: Dictionary = {}  # geliştirme id -> Button

var _upgrades: Array[UpgradeData] = []

var _weapons: Array[WeaponData] = []
var _slot_row: HBoxContainer      # silah sütunları: Slot 1, Slot 2 (her yenilemede yeniden kurulur)

# Fiyatlarda "gold" yazısı yerine sabit sikke ikonu. Button resim gösteremediği için metin,
# butonun içine yerleştirilen RichTextLabel'a ([img] etiketiyle) yazılır.
const COIN_ICON_PATH: String = "res://assets/sprites/gold/coin_icon.png"
const COIN_ICON: Texture2D = preload("res://assets/sprites/gold/coin_icon.png")
const PRICE_ICON_SIZE: int = 10       # buton içindeki sikke (ikon 20 px, yarısı: piksel bozulmaz)
const HEADER_ICON_SIZE: int = 20      # üstteki altın satırındaki sikke
const BUTTON_FONT_SIZE: int = 11   # Departure Mono sadece 11 px katlarında keskin (11, 22, 33...)
const BUTTON_MIN_HEIGHT: float = 30.0
const WEAPON_ICON_WIDTH: int = 48     # silah görselli butonlarda yazı bu genişliğin sağından başlar
const SWAP_ICON_WIDTH: int = 32       # küçük "Replace" butonlarındaki silah görseli
const SELL_FRAME: Color = Color(0.85, 0.25, 0.22)     # yuva kutusundaki Sell çerçevesi (olumsuz)
const UPGRADE_FRAME: Color = Color(0.4, 0.8, 0.35)    # yuva kutusundaki geliştirme çerçevesi (olumlu)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun dururken de çalışsın
	visible = false

	EventBus.shop_requested.connect(open)
	GameState.gold_changed.connect(func(_amount: int) -> void: _refresh())
	GameState.stats_changed.connect(_refresh)
	GameState.weapons_changed.connect(_refresh)
	next_wave_button.pressed.connect(_on_next_wave_pressed)

	_build_merchant_panel()
	_build_gold_header()
	_build_buttons()
	_build_weapon_section()

# --- Tüccar şeridi (mağazanın en üstünde): nefes alan Brimm (idle animasyonu), adı ve her açılışta değişen replik ---
const MERCHANT_NAME: String = "Brimm"
const MERCHANT_FRAMES_PATH: String = "res://data/npc/merchant_frames.tres"
const MERCHANT_SCALE: float = 2.0                     # 88 px kare, karakter ~62x60 px -> ekranda ~124x120
const MERCHANT_BOX: Vector2 = Vector2(132, 124)       # animasyonun durduğu alan
const MERCHANT_LINES: Array[String] = [
	"Heard a cat was seen near the sleeping halls. Orange. Rude.",
	"Silver bullets. Demons hate 'em. Business loves 'em.",
	"Brimstone only. No refunds. Well... half.",
	"Your cat? Never seen it. Buy something and I might remember.",
	"Every lord down here has met your furball. None of them liked it.",
	"Fresh stock. Slightly cursed. Mostly fine.",
	"You again? Good. I was running low on your money.",
	"Word is Moloch said your cat was too hot to handle. Coming from him!",
	"Keep the guns clean and the coins coming.",
	"Deeper you go, the pricier it gets. That's just economics.",
]
var _merchant_line: Label

# shop.tscn'e dokunmamak için koddan, içerik VBox'ının en üstüne eklenir; mağazanın geri kalanı altında tam genişlikte kalır
func _build_merchant_panel() -> void:
	var content := title_label.get_parent()  # Background/MarginContainer/VBoxContainer
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # "Wave X complete" Brimm'in altında ortalı
	var column := VBoxContainer.new()
	column.name = "MerchantRow"
	column.add_theme_constant_override("separation", 2)
	content.add_child(column)
	content.move_child(column, 0)

	# Brimm ortada: mağaza açıkken oyun durur ama Shop PROCESS_MODE_ALWAYS olduğu için animasyon oynar
	var holder := Control.new()
	holder.custom_minimum_size = MERCHANT_BOX
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(holder)
	if ResourceLoader.exists(MERCHANT_FRAMES_PATH):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = load(MERCHANT_FRAMES_PATH)
		sprite.scale = Vector2.ONE * MERCHANT_SCALE
		sprite.position = MERCHANT_BOX * 0.5
		sprite.play("idle")
		holder.add_child(sprite)

	# Adı ve repliği hemen altında, ortalı
	var name_label := Label.new()
	name_label.text = MERCHANT_NAME
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	column.add_child(name_label)

	_merchant_line = Label.new()
	_merchant_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_merchant_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merchant_line.add_theme_font_size_override("font_size", 11)
	_merchant_line.modulate = Color(0.85, 0.8, 0.7)
	column.add_child(_merchant_line)

# Üstteki altın satırı: sabit sikke ikonu + sayı (shop.tscn'e dokunmamak için GoldLabel koddan bir HBox'a taşınır)
func _build_gold_header() -> void:
	var vbox := gold_label.get_parent()
	var row := HBoxContainer.new()
	row.name = "GoldRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER  # Brimm'in altında ortalı
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

# Geliştirme ızgarası ve silah sütunları kaydırılabilir bir alanda (ScrollContainer): içerik ekrana sığmazsa
# kaydırılır, Next Wave her zaman en altta görünür. Koddan kurulur (shop.tscn'e dokunmamak için).
func _build_weapon_section() -> void:
	_weapons = WeaponPool.load_all()

	var vbox := next_wave_button.get_parent()
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	vbox.move_child(scroll, upgrade_list.get_index())
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	upgrade_list.reparent(inner)

	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 8)
	inner.add_child(_slot_row)

# Genel geliştirmeler ızgarası: sadece scope "" olanlar (Max Health, Regen, Armor, Speed).
# Silah geliştirmeleri ilgili silah sütununun altında gösterilir.
func _build_buttons() -> void:
	for upgrade in UpgradePool.load_all():
		if upgrade.scope == "":
			_upgrades.append(upgrade)
	for upgrade in _upgrades:
		var button := Button.new()
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_upgrade_pressed.bind(upgrade))
		upgrade_list.add_child(button)
		_buttons[upgrade.id] = button

func open(wave: int) -> void:
	title_label.text = "Wave %d complete" % wave
	_merchant_line.text = "\"%s\"" % MERCHANT_LINES.pick_random()
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
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	_set_button_text(button, text)
	return button

# Silah butonlarının (Sell, Buy, Replace with) solunda silahın görseli (hangi yuvada ne var / ne gelecek karışmasın)
func _set_weapon_icon(button: Button, weapon: WeaponData, icon_width: int = WEAPON_ICON_WIDTH) -> void:
	if weapon == null or weapon.icon == null:
		return
	button.icon = weapon.icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", icon_width)
	button.custom_minimum_size.y = 40
	var rich := button.get_node_or_null("Rich") as Control
	if rich:
		rich.offset_left = icon_width + 4  # yazı silah görselinin üstüne binmesin
		_fit_button(button)

# Silah sütunları her zaman iki tane: Slot 1, Slot 2. Başlığın altında:
# - dolu sütun: silah (Sell), o silahın geliştirmeleri ve (menzilli ise) gümüş mermi + başka silahla değiştirme
# - boş sütun: o yuvaya alınabilecek silahlar. Menzilli silah her zaman ilk boş yuvaya girdiği için
#   satın alma listesi sadece ilk boş menzilli yuvada görünür, sonraki boş yuvada "Empty" yazar.
# Son silah satılamaz.
func _refresh_slots() -> void:
	_clear(_slot_row)
	var can_sell := GameState.can_sell_weapon()
	var last_text := "\nLast weapon, can't sell" if not can_sell else ""

	for slot in GameState.MAX_GUNS:
		var column := _add_slot_column("Slot %d" % (slot + 1))
		if slot < GameState.guns.size():
			_fill_gun_column(column, slot, can_sell, last_text)
		elif slot == GameState.guns.size():
			for weapon in _weapons:
				var text := "Buy %s - %s%s\n%s" % [weapon.display_name, _price(weapon.cost), _weapon_note(weapon), weapon.description]
				var blocked := GameState.gold < weapon.cost or not GameState.can_take_weapon(weapon) or not GameState.is_weapon_unlocked(weapon)
				_set_weapon_icon(_make_button(column, text, blocked, _on_weapon_pressed.bind(weapon)), weapon)
		else:
			_add_column_note(column, "Empty")

# Dolu yuva (kullanıcının düzeni, 2026-11-21): tıklanmayan bir kutu.
#   sol üst: silah görseli + adı + hasarı        sağ üst: 1. geliştirme (Damage)
#   sol alt: Sell (+X, 50% refund)                sağ alt: 2. geliştirme (Fire Rate / Attack Rate)
# Kutunun altında gümüş mermi (ateşli silah, alınmadıysa) ve tek satırda küçük "Replace" butonları
# (görsel + net fiyat; ayrıntı fareyle üzerine gelince).
func _fill_gun_column(column: VBoxContainer, slot: int, can_sell: bool, _last_text: String) -> void:
	var gun := GameState.guns[slot]
	var silver := GameState.has_silver(slot)
	var current := _gun_damage(slot)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.1, 0.85)
	style.border_color = Color(0.45, 0.35, 0.3)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	box.add_theme_stylebox_override("panel", style)
	column.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)

	# Sol üst: görsel + yazılar
	var info := HBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	if gun.icon:
		var icon := TextureRect.new()
		icon.texture = gun.icon
		icon.custom_minimum_size = Vector2(WEAPON_ICON_WIDTH, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		info.add_child(icon)
	var label := Label.new()
	label.text = "%s%s\nDamage: base %d, now %d" % [gun.display_name, " (Silver)" if silver else "", gun.damage, current]
	label.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_child(label)
	grid.add_child(info)

	# Bu silahın geliştirmeleri (yarı fiyat, sadece bu silaha; ateşli silahta Damage/Fire Rate, bomba ve katanada kendi geliştirmeleri)
	var upgrades := _scoped_upgrades(gun.upgrade_scope)
	_add_box_upgrade(grid, slot, upgrades[0] if upgrades.size() > 0 else null)

	# Sol alt: satış
	var sell_text: String = ("Sell (%s, 50%% refund)" % _price(GameState.get_gun_sell_price(slot), true)) if can_sell else "Last weapon, can't sell"
	var sell := _make_button(grid, sell_text, not can_sell, _on_sell_gun_pressed.bind(slot))
	sell.size_flags_vertical = Control.SIZE_SHRINK_END
	_frame_button(sell, SELL_FRAME)
	_add_box_upgrade(grid, slot, upgrades[1] if upgrades.size() > 1 else null)
	for i in range(2, upgrades.size()):  # ileride üçüncü geliştirme gelirse alt alta devam eder
		grid.add_child(Control.new())
		_add_box_upgrade(grid, slot, upgrades[i])

	# Gümüş mermi: tek seferlik, sadece ateşli silahlarda; alınınca buton kalkar (adın yanında "(Silver)" yazar)
	if GameState.is_gun_slot(slot) and not silver:
		_make_button(column, "Silver Bullets - %s  (x2 damage)" % _price(GameState.SILVER_COST), not GameState.can_buy_silver(slot), _on_silver_pressed.bind(slot))

	# Başka silahla değiştirme (eski silahın harcamasının yarısı fiyattan düşer, geliştirmeler ve gümüş silahla gider):
	# tek satırda küçük butonlar, ayrıntı ipucunda
	var swaps := HFlowContainer.new()
	column.add_child(swaps)
	swaps.add_theme_constant_override("h_separation", 2)
	swaps.add_theme_constant_override("v_separation", 2)
	var swap_label := Label.new()
	swap_label.text = "Replace:"
	swap_label.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	swap_label.custom_minimum_size.y = 34
	swap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swaps.add_child(swap_label)
	for weapon in _weapons:
		if weapon.id == gun.id:
			continue
		var net := GameState.get_swap_cost(slot, weapon)
		var price := _price(net) if net >= 0 else _price(-net, true)
		var note := _weapon_note(weapon, slot)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.disabled = not GameState.can_swap_gun(slot, weapon)
		button.pressed.connect(_on_swap_pressed.bind(slot, weapon))
		button.tooltip_text = "Replace with %s: %s %d%s\nDamage: %d -> %d\n%s" % [
			weapon.display_name, "costs" if net >= 0 else "refunds", absi(net), note, current, weapon.damage, weapon.description]
		swaps.add_child(button)
		_set_button_text(button, price)
		_set_weapon_icon(button, weapon, SWAP_ICON_WIDTH)
		button.custom_minimum_size.y = 34

# Yuva kutusunun sağ sütunundaki geliştirme butonu (upgrade null ise boş yer tutucu)
func _add_box_upgrade(grid: GridContainer, slot: int, upgrade: UpgradeData) -> void:
	if upgrade == null:
		grid.add_child(Control.new())
		return
	var cost := GameState.get_gun_upgrade_cost(slot, upgrade)
	var level := GameState.get_gun_upgrade_level(slot, upgrade)
	var text := "%s (Lv %d) - %s\n%s" % [upgrade.display_name, level, _price(cost), upgrade.description]
	var button := _make_button(grid, text, not GameState.can_buy_gun_upgrade(slot, upgrade), _on_gun_upgrade_pressed.bind(slot, upgrade))
	button.size_flags_horizontal = Control.SIZE_FILL
	_frame_button(button, UPGRADE_FRAME)

# Yuva kutusundaki butonlar çerçeveli (buton oldukları belli olsun): Sell kırmızı (olumsuz), geliştirmeler yeşilimsi (olumlu)
func _frame_button(button: Button, color: Color) -> void:
	var states := {"normal": 0.18, "hover": 0.32, "pressed": 0.45, "focus": 0.18, "disabled": 0.08}
	for state in states:
		var style := StyleBoxFlat.new()
		var disabled: bool = state == "disabled"
		style.bg_color = Color(color.r, color.g, color.b, states[state])
		style.border_color = Color(color, 0.35) if disabled else color
		style.set_border_width_all(2)
		style.set_content_margin_all(4)
		if state == "focus":
			style.draw_center = false
		button.add_theme_stylebox_override(state, style)

# Yuvadaki silahın şu anki mermi hasarı: taban x Damage geliştirmesi x gümüş (gun.gd _damage ile aynı hesap)
func _gun_damage(slot: int) -> int:
	var mult := GameState.get_gun_multiplier(slot, "damage_multiplier") * (GameState.SILVER_DAMAGE_MULT if GameState.has_silver(slot) else 1.0)
	return maxi(1, roundi(GameState.guns[slot].damage * mult))

# Kilitli silah (WeaponData.unlock_wave dalgası henüz bitmedi): butona "(after wave X)" eklenir, buton pasif.
# El kuralı engelliyorsa (Adım 52a) sebebi yazılır: "(needs both hands)", "(other hand holds AK47)", "(one secondary only)".
# slot -1 = boş yuvaya alım, değilse o yuvadaki silahla değiştirme.
func _weapon_note(weapon: WeaponData, slot: int = -1) -> String:
	var reason := GameState.weapon_block_reason(weapon, slot)
	if reason != "":
		return " (%s)" % reason
	return "" if GameState.is_weapon_unlocked(weapon) else " (after wave %d)" % weapon.unlock_wave

func _scoped_upgrades(scope: String) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade in UpgradePool.load_all():
		if upgrade.scope == scope:
			result.append(upgrade)
	return result

# Bir silah sütunu: üstte başlık (Slot 1 / Slot 2), altında o yuvanın butonları
func _add_slot_column(title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	column.add_child(label)
	_slot_row.add_child(column)
	return column

func _add_column_note(column: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.5
	label.add_theme_font_size_override("font_size", 11)
	column.add_child(label)

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

func _on_swap_pressed(slot: int, weapon: WeaponData) -> void:
	if GameState.swap_gun(slot, weapon):
		Audio.play_sfx("ui_click")

func _on_next_wave_pressed() -> void:
	Audio.play_sfx("ui_click")
	visible = false
	get_tree().paused = false
	# Tüccar varsa havalanır, gidince yeni dalgayı o başlatır; yoksa dalga hemen başlar
	if get_tree().get_first_node_in_group("merchant"):
		EventBus.shop_closed.emit()
	else:
		EventBus.next_wave_requested.emit()
