extends Node2D

@export var bullet_scene: PackedScene
@export var retarget_interval: float = 0.15  # hedef ne sıklıkla yeniden aranır (saniye)

var data: WeaponData

var _cooldown: float = 0.0
var _target: Node2D = null
var _retarget_timer: float = 0.0
var _player: Node = null

# Görünmez çember üzerinde hareket (GunSlots setup_orbit ile ayarlar)
var _orbit_center: Vector2 = Vector2.ZERO
var _orbit_radius: float = 10.0
var _orbit_speed: float = 9.0
var _rest_angle: float = 0.0     # hedef yokken çemberdeki açı (el konumu)
var _aim_offset: float = 0.0     # iki silah aynı hedefe bakarken aradaki açı farkı
var _angle: float = 0.0          # şu anki çember açısı

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle

# GunSlots, silahı sahneye eklemeden önce bunu çağırır
func setup(weapon_data: WeaponData) -> void:
	data = weapon_data

func setup_orbit(center: Vector2, radius: float, speed: float, rest_angle: float, aim_offset: float) -> void:
	_orbit_center = center
	_orbit_radius = radius
	_orbit_speed = speed
	_rest_angle = rest_angle
	_aim_offset = aim_offset
	_angle = rest_angle
	_update_orbit_position()

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_build_frames()
	sprite.animation_finished.connect(func() -> void: sprite.play("idle"))
	sprite.play("idle")
	# iki silah tam aynı anda ateş etmesin
	_cooldown = randf() * _fire_interval()

func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.rename_animation("default", "idle")
	frames.add_frame("idle", data.icon)

	frames.add_animation("shoot")
	frames.set_animation_loop("shoot", false)
	var frame_width: float = data.icon.get_width()
	if data.shoot_sheet:
		var count := maxi(data.shoot_frame_count, 1)
		frame_width = data.shoot_sheet.get_width() / float(count)
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = data.shoot_sheet
			atlas.region = Rect2(i * frame_width, 0, frame_width, data.shoot_sheet.get_height())
			frames.add_frame("shoot", atlas)
	else:
		frames.add_frame("shoot", data.icon)

	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * data.sprite_scale
	muzzle.position = Vector2(frame_width * 0.5 * data.sprite_scale, 0.0)  # namlu ucu

func _physics_process(delta: float) -> void:
	if data == null or (_player and _player.is_dead):
		return

	_cooldown = maxf(_cooldown - delta, 0.0)
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not _is_valid_target(_target):
		_target = _find_target()
		_retarget_timer = retarget_interval

	# Çember üzerinde hedefe en yakın noktaya kay; hedef yoksa el konumuna dön
	var desired := _rest_angle
	if _target != null:
		desired = _center_global().direction_to(_target.global_position).angle() + _aim_offset
	_angle = rotate_toward(_angle, desired, _orbit_speed * delta)
	_update_orbit_position()

	if _target == null:
		# hedef yokken namlu çemberin dışına baksın
		_set_aim(Vector2.from_angle(_angle))
		return

	var dir := global_position.direction_to(_target.global_position)
	_set_aim(dir)

	if _cooldown <= 0.0:
		# İki silah aynı anda ateş etmesin: GunSlots sıra verene kadar bekle (atışlar arka arkaya, sesler üst üste binmez)
		var slots := get_parent()
		if slots and slots.has_method("request_shot") and not slots.request_shot():
			return
		_fire(dir)
		_cooldown = _fire_interval()

func _set_aim(dir: Vector2) -> void:
	rotation = dir.angle()
	sprite.flip_v = dir.x < 0.0  # sola nişan alırken silah ters görünmesin

# Çemberin merkezi (dünya koordinatı); menzil ve hedef seçimi buradan yapılır, silah kayarken titremesin
func _center_global() -> Vector2:
	var parent := get_parent() as Node2D
	if parent == null:
		return global_position
	return parent.to_global(_orbit_center)

func _update_orbit_position() -> void:
	position = _orbit_center + Vector2.from_angle(_angle) * _orbit_radius

func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist := data.attack_range * data.attack_range
	var center := _center_global()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d := center.distance_squared_to(enemy.global_position)
		if d <= best_dist:
			best_dist = d
			best = enemy
	return best

# Parametre bilerek tipsiz: ölen (silinmiş) düşman tipli parametreye verilince Godot hata verir
func _is_valid_target(t: Variant) -> bool:
	if not is_instance_valid(t) or t.is_queued_for_deletion():
		return false
	return _center_global().distance_to(t.global_position) <= data.attack_range

func _fire(dir: Vector2) -> void:
	var spread := deg_to_rad(randf_range(-data.spread_degrees, data.spread_degrees))
	var bullet := bullet_scene.instantiate()
	# menzilin biraz ötesine gitsin, hareket eden hedefi kaçırmasın
	bullet.setup(_damage(), data.bullet_speed, data.attack_range * 1.2, dir.angle() + spread)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position

	# ateş animasyonu bir sonraki atıştan önce bitsin
	var anim_time := clampf(_fire_interval() * 0.9, 0.05, 0.35)
	sprite.sprite_frames.set_animation_speed("shoot", sprite.sprite_frames.get_frame_count("shoot") / anim_time)
	sprite.play("shoot")
	sprite.frame = 0
	Audio.play_sfx(data.shoot_sound)

# GunSlots atışlar arası boşluğu hesaplarken kullanır
func fire_interval() -> float:
	return _fire_interval()

func _fire_interval() -> float:
	return 1.0 / maxf(data.fire_rate * GameState.stats.fire_rate_multiplier, 0.01)

func _damage() -> int:
	return maxi(1, roundi(data.damage * GameState.stats.damage_multiplier))
