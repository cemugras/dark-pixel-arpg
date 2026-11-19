class_name FloorVeins
extends Node2D

# Zemindeki kızgın damarlar (Lucifer'in Tahtı: buzun altında hâlâ yanan cehennem ateşi). Sadece görüntü: çarpışma yok.
# Damarlar zemin karelerinin birleştiği çizgilerde (TILE ızgarası) gider, hep 90 derece döner: ana yönde 2-5 kare,
# sonra sağa ya da sola 1-2 kare kayar, yine ana yöne döner (geri dönmez, kendi üstüne kıvrılmaz); ara sıra kısa kol ayrılır.
# Canlı görünsün diye: damarlar yavaşça nabız atar (parlaklık), üstlerinde akış yönünde parlak kıvılcımlar kayar.
# Arena.build() bölgenin floor_veins sayısı > 0 ise Ground'un hemen üstüne ekler. Yerleşim bölge kimliğinden tohumlanır:
# aynı bölge her açılışta aynı damarları çizer.

const TILE: int = 16
const RUN_MAIN: Vector2i = Vector2i(2, 5)     # ana yönde kaç kare (en az, en çok)
const RUN_SIDE: Vector2i = Vector2i(1, 2)     # yana kayma
const STEPS: Vector2i = Vector2i(8, 14)       # bir damarın adım sayısı (ana + yan)
const BRANCH_CHANCE: float = 0.2
const BRANCH_STEPS: int = 3
const EDGE_INSET: int = 1                     # arena kenarına bu kadar kare yaklaşmaz
const PULSE_TIME: float = 3.2                 # nabız süresi (sn)
const PULSE_MIN: float = 0.6                  # nabzın en sönük anı (parlaklık çarpanı)
const SPARK_SPACING: float = 90.0             # damar boyunca kaç pikselde bir kıvılcım
const SPARK_SPEED: float = 28.0               # px/sn
const SPARK_LENGTH: float = 6.0

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var color: Color = Color(0.77, 0.14, 0.16)
var _paths: Array[PackedVector2Array] = []    # köşe noktaları (dünya pikseli)
var _lengths: PackedFloat32Array = []
var _base: Node2D                             # sabit damarlar (bir kez çizilir, nabız modulate ile)
var _time: float = 0.0

func setup(count: int, vein_color: Color, area: Rect2, seed_text: String) -> void:
	color = vein_color
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	# Izgara noktaları (kare köşeleri), kenardan EDGE_INSET içeride
	var lo := Vector2i((area.position / TILE).round()) + Vector2i.ONE * EDGE_INSET
	var hi := Vector2i((area.end / TILE).round()) - Vector2i.ONE * EDGE_INSET
	for i in count:
		# Her damar arenanın rastgele bir yarısından içeri doğru akar: ana yön merkeze bakar
		var start := Vector2i(rng.randi_range(lo.x, hi.x), rng.randi_range(lo.y, hi.y))
		var main := _main_dir_toward_center(start, rng)
		_walk(start, main, rng.randi_range(STEPS.x, STEPS.y), lo, hi, rng, true)
	for p in _paths:
		var total := 0.0
		for k in range(1, p.size()):
			total += p[k - 1].distance_to(p[k])
		_lengths.append(total)

	_base = Node2D.new()
	_base.name = "Base"
	_base.show_behind_parent = true  # taban damarlar altta, kıvılcımlar (bu düğümün _draw'u) üstte
	_base.draw.connect(_draw_base)
	add_child(_base)
	var spark_material := CanvasItemMaterial.new()
	spark_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = spark_material  # kıvılcımlar toplamalı; taban çocuğu malzemeyi almaz, normal karışımda

func _main_dir_toward_center(p: Vector2i, rng: RandomNumberGenerator) -> int:
	# Merkezden uzak eksende merkeze doğru (biraz rastgelelikle) akar
	if absi(p.x) * 0.75 > absi(p.y) or (absi(p.x) > absi(p.y) * 0.5 and rng.randf() < 0.5):
		return 2 if p.x > 0 else 0
	return 3 if p.y > 0 else 1

func _walk(start: Vector2i, main: int, steps: int, lo: Vector2i, hi: Vector2i, rng: RandomNumberGenerator, can_branch: bool) -> void:
	var points := PackedVector2Array([Vector2(start * TILE)])
	var p := start
	var d := main
	for s in steps:
		var run := rng.randi_range(RUN_MAIN.x, RUN_MAIN.y) if d == main else rng.randi_range(RUN_SIDE.x, RUN_SIDE.y)
		var next := p + DIRS[d] * run
		next = next.clamp(lo, hi)
		if next == p:
			break  # kenara dayandı
		p = next
		points.append(Vector2(p * TILE))
		if can_branch and rng.randf() < BRANCH_CHANCE:
			_walk(p, (main + 1 + 2 * rng.randi_range(0, 1)) % 4, BRANCH_STEPS, lo, hi, rng, false)
		d = (main + 1 + 2 * rng.randi_range(0, 1)) % 4 if d == main else main
	if points.size() >= 2:
		_paths.append(points)

func _process(delta: float) -> void:
	_time += delta
	var pulse := PULSE_MIN + (1.0 - PULSE_MIN) * (0.5 + 0.5 * sin(_time * TAU / PULSE_TIME))
	_base.modulate = Color(pulse, pulse, pulse, 1.0)
	queue_redraw()

# Piksel keskin: segment başına 4 px sönük kenar + 2 px parlak çekirdek, dönüş noktalarında parlak 2x2
func _draw_base() -> void:
	var edge := Color(color, 0.3)
	var core := Color(color, 0.9)
	var hot := Color(color.lightened(0.35), 0.95)
	for p in _paths:
		for k in range(1, p.size()):
			_base_segment(p[k - 1], p[k], edge, 2.0)
		for k in range(1, p.size()):
			_base_segment(p[k - 1], p[k], core, 1.0)
		for k in range(1, p.size()):
			_base.draw_rect(Rect2(p[k] - Vector2.ONE, Vector2(2, 2)), hot)

func _base_segment(a: Vector2, b: Vector2, c: Color, half: float) -> void:
	var r := Rect2(a, Vector2.ZERO).expand(b).grow(half)
	_base.draw_rect(r, c)

# Akan kıvılcımlar: her damar boyunca SPARK_SPACING aralıkla, SPARK_SPEED ile ilerler; uçlarda söner
func _draw() -> void:
	var spark := Color(color.lightened(0.5), 0.8)
	for i in _paths.size():
		var p := _paths[i]
		var total := _lengths[i]
		var count := maxi(1, int(total / SPARK_SPACING))
		for s in count:
			var t := fmod(_time * SPARK_SPEED + s * total / count + i * 37.0, total)
			var fade := clampf(minf(t, total - t) / 24.0, 0.0, 1.0)
			if fade <= 0.0:
				continue
			_draw_spark(p, t, Color(spark, spark.a * fade))

func _draw_spark(p: PackedVector2Array, t: float, c: Color) -> void:
	# t konumundan geriye SPARK_LENGTH kadar, köşeleri dönerek
	var remaining := SPARK_LENGTH
	var acc := 0.0
	for k in range(1, p.size()):
		var seg := p[k - 1].distance_to(p[k])
		if acc + seg >= t:
			var head := p[k - 1].move_toward(p[k], t - acc)
			var tail_dist := minf(remaining, t - acc)
			var tail := head.move_toward(p[k - 1], tail_dist)
			draw_rect(Rect2(tail, Vector2.ZERO).expand(head).grow(1.0), c)
			remaining -= tail_dist
			# kalan kısım önceki segmentlerde
			var j := k - 1
			while remaining > 0.0 and j >= 1:
				var len_j := p[j - 1].distance_to(p[j])
				var d := minf(remaining, len_j)
				draw_rect(Rect2(p[j], Vector2.ZERO).expand(p[j].move_toward(p[j - 1], d)).grow(1.0), c)
				remaining -= d
				j -= 1
			return
		acc += seg
