class_name Arena
extends Node2D

# Oyun alanı: ortada yürünebilir arena (ARENA_TILES), çevresinde MARGIN tile'lık yürünemez dış alan
# (bölgeye göre lav denizi vb.), kenarda görünmez duvar. Haritayı RegionData'ya göre koddan dizer;
# bölge değişince (10 dalgada bir) kararıp yeniden kurulur. Main koddan ekler (zeminin en altta çizilmesi için ilk çocuk).
# Arena dünya merkezine (0, 0) göre ortalıdır; oyuncu ortadan başlar.

const TILE: int = 16
const ARENA_TILES: Vector2i = Vector2i(48, 36)   # yürünebilir alan (768x576 px, ekranın ~1.5 katı)
const MARGIN: int = 18                           # dış alan kalınlığı (tile); kamera kenarda bile dış alanın sonunu görmez
const WALL_THICKNESS: float = 64.0
const ASH_SEED_EDGE: int = 3                     # lekeler arena kenarına bu kadar köşe yaklaşmaz
const FADE_TIME: float = 0.6
const LAVA_SHADER: Shader = preload("res://scenes/levels/lava_glow.gdshader")

var region: RegionData

var _ground: TileMapLayer
var _walls: StaticBody2D
var _fx: Node2D

# Yürünebilir alan (dünya pikseli)
static func play_rect() -> Rect2:
	var size := Vector2(ARENA_TILES * TILE)
	return Rect2(-size / 2.0, size)

# Dış alan dahil tüm harita (kamera sınırı)
static func world_rect() -> Rect2:
	return play_rect().grow(MARGIN * TILE)

func _ready() -> void:
	EventBus.wave_started.connect(_on_wave_started)

func build(new_region: RegionData) -> void:
	region = new_region
	for child in get_children():
		child.queue_free()
	if region == null:
		return
	_build_ground()
	_build_walls()
	_build_decor()
	_build_effects()

# Bölge değişince ekran kararır, harita yeniden kurulur, açılır
func _on_wave_started(wave: int) -> void:
	var next := RegionPool.for_wave(wave)
	if next == null or next == region:
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	get_tree().root.add_child(layer)
	build(next)
	var tween := layer.create_tween()
	tween.tween_property(black, "color:a", 0.0, FADE_TIME)
	tween.tween_callback(layer.queue_free)

# --- Zemin ---

func _build_ground() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var floor_id := tile_set.add_source(_make_source(region.floor_texture))
	var edge_id := tile_set.add_source(_make_source(region.edge_texture))

	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = tile_set
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if region.animate_outside:
		var lava_material := ShaderMaterial.new()
		lava_material.shader = LAVA_SHADER
		_ground.material = lava_material
	add_child(_ground)

	# Köşe ızgarası: 1 = arena (upper), 0 = dış (lower), 2 = uçurum yüzü (transition, güney kenarın altı)
	var w := ARENA_TILES.x + MARGIN * 2
	var h := ARENA_TILES.y + MARGIN * 2
	var land := _grid(w + 1, h + 1)
	for x in range(MARGIN, MARGIN + ARENA_TILES.x + 1):
		for y in range(MARGIN, MARGIN + ARENA_TILES.y + 1):
			land[x][y] = 1
	if region.edge_tall:
		for x in range(MARGIN, MARGIN + ARENA_TILES.x + 1):
			land[x][MARGIN + ARENA_TILES.y + 1] = 2
	var ash := _ash_grid(w + 1, h + 1)

	var offset := Vector2i(-MARGIN - ARENA_TILES.x / 2, -MARGIN - ARENA_TILES.y / 2)
	for x in w:
		for y in h:
			var corners := [land[x][y], land[x + 1][y], land[x][y + 1], land[x + 1][y + 1]]
			var cell := Vector2i(x, y) + offset
			if corners == [1, 1, 1, 1]:
				var key := "%d%d%d%d" % [ash[x][y], ash[x + 1][y], ash[x][y + 1], ash[x + 1][y + 1]]
				_set_tile(cell, floor_id, region.floor_tiles, key, key == "0000")
			else:
				var key := "%d%d%d%d" % corners
				_set_tile(cell, edge_id, region.edge_tiles, key, key == "0000")

# Tekrarı kırmak için düz (tek terrain) tile'lar rastgele aynalanır
func _set_tile(cell: Vector2i, source_id: int, tiles: Dictionary, key: String, can_flip: bool) -> void:
	if not tiles.has(key):
		push_warning("Arena: '%s' köşe kombinasyonu için tile yok (%s)" % [key, region.id])
		return
	var alt := 0
	if can_flip:
		if randf() < 0.5:
			alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
		if randf() < 0.5:
			alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	_ground.set_cell(cell, source_id, tiles[key], alt)

func _make_source(texture: Texture2D) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for x in texture.get_width() / TILE:
		for y in texture.get_height() / TILE:
			source.create_tile(Vector2i(x, y))
	return source

func _grid(w: int, h: int) -> Array:
	var grid := []
	for x in w:
		var column := []
		column.resize(h)
		column.fill(0)
		grid.append(column)
	return grid

# Arenaya serpiştirilen sönük lekeler: her biri birkaç üst üste binen rastgele daire
func _ash_grid(w: int, h: int) -> Array:
	var ash := _grid(w, h)
	var x0 := MARGIN + ASH_SEED_EDGE
	var x1 := MARGIN + ARENA_TILES.x - ASH_SEED_EDGE
	var y0 := MARGIN + ASH_SEED_EDGE
	var y1 := MARGIN + ARENA_TILES.y - ASH_SEED_EDGE
	for i in region.floor_patches:
		var center := Vector2(randi_range(x0, x1), randi_range(y0, y1))
		for b in randi_range(2, 4):
			var blob := center + Vector2(randi_range(-3, 3), randi_range(-2, 2))
			var r := randf_range(1.0, 3.2)
			for x in range(maxi(x0 - 2, int(blob.x - r)), mini(x1 + 2, int(blob.x + r)) + 1):
				for y in range(maxi(y0 - 2, int(blob.y - r)), mini(y1 + 2, int(blob.y + r)) + 1):
					if Vector2(x, y).distance_squared_to(blob) <= r * r:
						ash[x][y] = 1
	return ash

# --- Görünmez duvar ---

func _build_walls() -> void:
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	_walls.collision_layer = 1  # eski tile duvarıyla aynı katman: oyuncu, yaratık, mermi buna çarpar
	_walls.collision_mask = 0
	add_child(_walls)
	var r := play_rect()
	var t := WALL_THICKNESS
	_add_wall(Rect2(r.position.x - t, r.position.y - t, r.size.x + t * 2, t))  # üst
	_add_wall(Rect2(r.position.x - t, r.end.y, r.size.x + t * 2, t))          # alt
	_add_wall(Rect2(r.position.x - t, r.position.y, t, r.size.y))             # sol
	_add_wall(Rect2(r.end.x, r.position.y, t, r.size.y))                      # sağ

func _add_wall(rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	_walls.add_child(collision)

# --- Süsler: arena dışında, zeminin üstünde, korların altında. Lav shader'ı kızgın piksellerini denizle birlikte dalgalandırır ---

const SCATTER_EDGE_GAP: float = 28.0   # serpiştirilen süsler arena kenarına (parıltılı kıyı) bu kadar yaklaşmaz
const SCATTER_TRIES: int = 40

func _build_decor() -> void:
	var decor := Node2D.new()
	decor.name = "Decor"
	add_child(decor)
	var taken: Array[Rect2] = []  # çakışmayı önlemek için kaplanan alanlar
	for item in region.decor:
		var texture: Texture2D = item.get("texture")
		if texture == null:
			continue
		var pos: Vector2 = item.get("position", Vector2.ZERO)
		_add_decor_sprite(decor, texture, pos, item.get("flip", false))
		taken.append(Rect2(pos - texture.get_size() / 2.0, texture.get_size()))
	if region.scatter_textures.is_empty():
		return
	var play := play_rect()
	var area := play.grow(region.scatter_reach).intersection(world_rect())
	var g := SCATTER_EDGE_GAP
	var keep_out := play.grow_individual(g, g, g, g + (TILE * 2 if region.edge_tall else 0))  # güneyde uçurum yüzü de
	# Dört kenar şeridi; süsler sırayla dağıtılır ki dar şerit (güney, uçurum yüzü yüzünden) boş kalmasın
	var sides: Array[Rect2] = [
		Rect2(area.position.x, area.position.y, area.size.x, keep_out.position.y - area.position.y),
		Rect2(area.position.x, keep_out.end.y, area.size.x, area.end.y - keep_out.end.y),
		Rect2(area.position.x, keep_out.position.y, keep_out.position.x - area.position.x, keep_out.size.y),
		Rect2(keep_out.end.x, keep_out.position.y, area.end.x - keep_out.end.x, keep_out.size.y),
	]
	for i in region.scatter_count:
		var texture: Texture2D = region.scatter_textures.pick_random()
		var size := texture.get_size()
		var side := sides[i % sides.size()]
		for attempt in SCATTER_TRIES:
			var pos := Vector2(randf_range(side.position.x, side.end.x), randf_range(side.position.y, side.end.y))
			var rect := Rect2(pos - size / 2.0, size)
			if rect.intersects(keep_out) or not area.encloses(rect):
				continue
			if taken.any(func(r: Rect2) -> bool: return r.grow(8.0).intersects(rect)):
				continue
			_add_decor_sprite(decor, texture, pos, randf() < 0.5)
			taken.append(rect)
			break

func _add_decor_sprite(parent: Node2D, texture: Texture2D, pos: Vector2, flip: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos.round()
	sprite.flip_h = flip
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if region.animate_outside:
		sprite.material = _ground.material
	parent.add_child(sprite)

# --- Dış alan efektleri: yükselen korlar ve duman (sadece arena dışında doğar) ---

func _build_effects() -> void:
	_fx = Node2D.new()
	_fx.name = "Effects"
	add_child(_fx)
	var bands := _outside_bands()
	var total_area := 0.0
	for band in bands:
		total_area += band.get_area()
	for band in bands:
		var share := band.get_area() / total_area
		if region.ash_fall:
			var colors: Array[Color] = region.ember_colors.duplicate()
			if colors.is_empty():
				colors.append(region.ember_color)
			for c in colors:
				_add_ash(band, maxi(4, roundi(region.ember_amount * share / colors.size())), c)
			_add_mist(band, maxi(1, roundi(region.smoke_amount * share)))
		else:
			_add_embers(band, maxi(4, roundi(region.ember_amount * share)))
			_add_smoke(band, maxi(1, roundi(region.smoke_amount * share)))
	_add_fly_swarms()
	if region.ash_fall:
		return  # kül bölgesinde kenar parıltısı yok
	# Kenar boyunca, uçurumun dibinden kıvılcım: arena kenarında parıltı hissi
	var r := play_rect()
	for edge_band in [Rect2(r.position.x, r.position.y - 10, r.size.x, 8), Rect2(r.position.x, r.end.y + 6, r.size.x, 10),
			Rect2(r.position.x - 10, r.position.y, 8, r.size.y), Rect2(r.end.x + 2, r.position.y, 8, r.size.y)]:
		_add_embers(edge_band, 12, 0.6)

# Arenanın dışındaki dört şerit (üst, alt, sol, sağ)
func _outside_bands() -> Array[Rect2]:
	var p := play_rect()
	var w := world_rect()
	return [
		Rect2(w.position.x, w.position.y, w.size.x, p.position.y - w.position.y),
		Rect2(w.position.x, p.end.y + TILE * 2, w.size.x, w.end.y - p.end.y - TILE * 2),  # uçurum yüzünün altı
		Rect2(w.position.x, p.position.y, p.position.x - w.position.x, p.size.y + TILE * 2),
		Rect2(p.end.x, p.position.y, w.end.x - p.end.x, p.size.y + TILE * 2),
	]

func _add_embers(rect: Rect2, amount: int, life_scale: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 3.2 * life_scale
	p.preprocess = p.lifetime
	p.randomness = 0.6
	p.local_coords = false
	p.position = rect.get_center()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2.0
	p.direction = Vector2.UP
	p.spread = 30.0
	p.gravity = Vector2(0, -10)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	var hot := region.ember_color
	ramp.set_color(0, Color(hot.r, hot.g * 1.2, hot.b, 0.0))
	ramp.set_color(1, Color(hot.r * 0.7, hot.g * 0.25, 0.0, 0.0))
	ramp.add_point(0.15, Color(1.0, minf(1.0, hot.g * 1.4), hot.b * 1.5, 1.0))
	ramp.add_point(0.7, Color(hot.r, hot.g * 0.6, 0.0, 0.8))
	p.color_ramp = ramp
	_fx.add_child(p)

func _add_smoke(rect: Rect2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.texture = _smoke_texture()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = p.lifetime
	p.randomness = 0.5
	p.local_coords = false
	p.position = rect.get_center()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2.0
	p.direction = Vector2.UP
	p.spread = 20.0
	p.gravity = Vector2(2, -3)  # hafif rüzgâr
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	var c := region.smoke_color
	ramp.set_color(0, Color(c.r, c.g, c.b, 0.0))
	ramp.set_color(1, Color(c.r, c.g, c.b, 0.0))
	ramp.add_point(0.3, c)
	p.color_ramp = ramp
	_fx.add_child(p)

# Kül bölgesi: yukarıdan sallanarak yavaşça düşen sönük kül pulları (parlamaz, belirip kaybolur)
func _add_ash(rect: Rect2, amount: int, c: Color) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = p.lifetime
	p.randomness = 0.6
	p.local_coords = false
	p.position = rect.get_center()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2.0
	p.direction = Vector2(0.3, 1.0)
	p.spread = 25.0
	p.gravity = Vector2(1.5, 2.5)  # çok hafif yerçekimi + rüzgâr
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.tangential_accel_min = -3.0  # sağa sola salınım
	p.tangential_accel_max = 3.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(c.r, c.g, c.b, 0.0))
	ramp.set_color(1, Color(c.r, c.g, c.b, 0.0))
	ramp.add_point(0.2, Color(c.r, c.g, c.b, c.a))
	ramp.add_point(0.75, Color(c.r, c.g, c.b, c.a * 0.8))
	p.color_ramp = ramp
	_fx.add_child(p)

# Kül bölgesi: yere yakın, yana doğru yavaşça sürünen iri ve soluk sis lekeleri
func _add_mist(rect: Rect2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.texture = _smoke_texture()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = amount
	p.lifetime = 12.0
	p.preprocess = p.lifetime
	p.randomness = 0.5
	p.local_coords = false
	p.position = rect.get_center()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2.0
	p.direction = Vector2.RIGHT
	p.spread = 15.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 4.5
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.7))
	curve.add_point(Vector2(1.0, 1.3))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	var c := region.smoke_color
	ramp.set_color(0, Color(c.r, c.g, c.b, 0.0))
	ramp.set_color(1, Color(c.r, c.g, c.b, 0.0))
	ramp.add_point(0.35, c)
	ramp.add_point(0.65, c)
	p.color_ramp = ramp
	_fx.add_child(p)

# Dış alanda, kamera kenardayken görünen kuşakta rastgele noktalara küçük sinek bulutları: her biri bir noktanın
# etrafında dönüp duran birkaç koyu piksel (yaratık değil, sadece süs; arenaya girmez)
const FLY_SWARM_RADIUS: float = 14.0

func _add_fly_swarms() -> void:
	if region.fly_swarms <= 0:
		return
	var play := play_rect()
	var area := play.grow(region.scatter_reach).intersection(world_rect())
	var keep_out := play.grow(SCATTER_EDGE_GAP + FLY_SWARM_RADIUS)
	for i in region.fly_swarms:
		var pos := Vector2.ZERO
		for attempt in SCATTER_TRIES:
			pos = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
			if not keep_out.has_point(pos):
				break
		var p := CPUParticles2D.new()
		p.amount = randi_range(6, 10)
		p.lifetime = 1.4
		p.preprocess = p.lifetime
		p.randomness = 0.5
		p.local_coords = true  # bulut yerinde kalır
		p.position = pos
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = FLY_SWARM_RADIUS * 0.5
		p.direction = Vector2.RIGHT
		p.spread = 180.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 22.0
		p.orbit_velocity_min = -0.8  # merkezin etrafında zikzak döner
		p.orbit_velocity_max = 0.8
		p.radial_accel_min = -30.0   # merkeze geri çekilir, bulut dağılmaz
		p.radial_accel_max = -18.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 1.5
		p.color = region.fly_color
		_fx.add_child(p)

static var _smoke_tex: Texture2D

# Küçük, kenarı basamaklı yuvarlak duman lekesi (yakından bakınca piksel piksel)
static func _smoke_texture() -> Texture2D:
	if _smoke_tex:
		return _smoke_tex
	var size := 12
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)
	for x in size:
		for y in size:
			var d := Vector2(x, y).distance_to(center) / (size / 2.0)
			var a := 0.0
			if d < 0.45:
				a = 1.0
			elif d < 0.75:
				a = 0.6
			elif d < 1.0:
				a = 0.25
			image.set_pixel(x, y, Color(1, 1, 1, a))
	_smoke_tex = ImageTexture.create_from_image(image)
	return _smoke_tex
