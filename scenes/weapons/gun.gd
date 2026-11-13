extends Node2D

@export var bullet_scene: PackedScene
@export var retarget_interval: float = 0.15  # hedef ne sıklıkla yeniden aranır (saniye)

var data: WeaponData
var silver: bool = false  # gümüş mermi (GunSlots sahneye eklemeden önce ayarlar): x2 hasar, parlak mermi, beyaz-mavi ağız ateşi

const SILVER_FLASH_COLOR: Color = Color(0.85, 0.95, 1.6)  # ağız ateşi beyaz-mavimsi (sarı-turuncu yerine)

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

# El modu (prototip): silah Walt'ın yumruğuna oturur, GunSlots her karede konumunu verir.
# Kabza noktası dokunun içindeki orana göre (sol-alt bölge); silah bu noktanın etrafında döner.
const GRIP_RATIO: Vector2 = Vector2(0.3, 0.65)
const MUZZLE_Y_RATIO: float = 0.3
var use_hand_grip: bool = false  # GunSlots sahneye eklemeden önce ayarlar
var _hand_mode: bool = false
var _rest_dir: Vector2 = Vector2.RIGHT
var _grip_offset: Vector2 = Vector2.ZERO
var _muzzle_offset: Vector2 = Vector2.ZERO

# Ateş efekti (shoot_sheet yoksa): geri tepme + ağız ateşi
const FLASH_TIME: float = 0.05
var _flash: Sprite2D = null
var _flash_timer: float = 0.0
var _recoil_tween: Tween = null

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
	var tex: Texture2D = data.sprite if data.sprite else data.icon
	var frames := SpriteFrames.new()
	frames.rename_animation("default", "idle")
	frames.add_frame("idle", tex)

	frames.add_animation("shoot")
	frames.set_animation_loop("shoot", false)
	var frame_width: float = tex.get_width()
	if data.shoot_sheet:
		var count := maxi(data.shoot_frame_count, 1)
		frame_width = data.shoot_sheet.get_width() / float(count)
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = data.shoot_sheet
			atlas.region = Rect2(i * frame_width, 0, frame_width, data.shoot_sheet.get_height())
			frames.add_frame("shoot", atlas)
	else:
		frames.add_frame("shoot", tex)

	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * data.sprite_scale
	muzzle.position = Vector2(frame_width * 0.5 * data.sprite_scale, 0.0)  # namlu ucu
	if use_hand_grip:
		# Dönme noktası kabzaya taşınır: sprite kabza origin'e gelecek şekilde kaydırılır
		var size := Vector2(frame_width, tex.get_height())
		var grip := data.grip_point if data.grip_point.x >= 0.0 else size * GRIP_RATIO
		var tip := data.muzzle_point if data.muzzle_point.x >= 0.0 else Vector2(size.x, size.y * MUZZLE_Y_RATIO)
		_grip_offset = size * 0.5 - grip
		_muzzle_offset = (tip - grip) * data.sprite_scale
		sprite.offset = _grip_offset
		muzzle.position = _muzzle_offset

	if data.muzzle_flash:
		_flash = Sprite2D.new()
		_flash.texture = data.muzzle_flash
		_flash.hframes = maxi(data.muzzle_flash_frames, 1)
		_flash.centered = false
		_flash.offset = Vector2(0.0, -data.muzzle_flash.get_height() * 0.5)
		_flash.scale = Vector2.ONE * data.sprite_scale
		_flash.visible = false
		if silver:
			_flash.modulate = SILVER_FLASH_COLOR
		muzzle.add_child(_flash)

# GunSlots el modunda her karede çağırır: konum (oyuncuya göre), öne/arkaya çizim, hedef yokken bakış yönü
func set_hand(pos: Vector2, front: bool, rest_dir: Vector2) -> void:
	_hand_mode = true
	position = pos
	z_index = 1 if front else 0
	_rest_dir = rest_dir

func _physics_process(delta: float) -> void:
	if data == null or (_player and _player.is_dead):
		return

	if _flash and _flash.visible:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash.visible = false

	_cooldown = maxf(_cooldown - delta, 0.0)
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not _is_valid_target(_target):
		_target = _find_target()
		_retarget_timer = retarget_interval

	if not _hand_mode:
		# Çember üzerinde hedefe en yakın noktaya kay; hedef yoksa el konumuna dön
		var desired := _rest_angle
		if _target != null:
			desired = _center_global().direction_to(_target.global_position).angle() + _aim_offset
		_angle = rotate_toward(_angle, desired, _orbit_speed * delta)
		_update_orbit_position()

	if _target == null:
		# hedef yokken namlu çemberin dışına (el modunda Walt'ın baktığı yöne) baksın
		_set_aim(_rest_dir if _hand_mode else Vector2.from_angle(_angle))
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
	if use_hand_grip:
		# Ters çevrilince kabza ve namlu da dikeyde yer değiştirir
		var sign_y := -1.0 if sprite.flip_v else 1.0
		sprite.offset = Vector2(_grip_offset.x, _grip_offset.y * sign_y)
		muzzle.position = Vector2(_muzzle_offset.x, _muzzle_offset.y * sign_y)

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
	bullet.setup(_damage(), data.bullet_speed, data.attack_range * 1.2, dir.angle() + spread, silver)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position

	# ateş animasyonu bir sonraki atıştan önce bitsin
	var anim_time := clampf(_fire_interval() * 0.9, 0.05, 0.35)
	if data.shoot_sheet:
		sprite.sprite_frames.set_animation_speed("shoot", sprite.sprite_frames.get_frame_count("shoot") / anim_time)
		sprite.play("shoot")
		sprite.frame = 0
	else:
		_kick(minf(anim_time, 0.15))
	if _flash:
		_flash.frame = randi() % _flash.hframes
		_flash.visible = true
		_flash_timer = FLASH_TIME
	Audio.play_sfx(data.shoot_sound)

# Geri tepme: silah kabza etrafında namlu yukarı kalkar ve geri kayar, sonra yerine döner
func _kick(duration: float) -> void:
	var sign_y := -1.0 if sprite.flip_v else 1.0  # sola nişanda "yukarı" yerel eksende ters
	if _recoil_tween:
		_recoil_tween.kill()
	sprite.position = Vector2(-data.recoil_distance * data.sprite_scale, 0.0)
	sprite.rotation = deg_to_rad(-data.recoil_degrees) * sign_y
	_recoil_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(sprite, "position", Vector2.ZERO, duration)
	_recoil_tween.tween_property(sprite, "rotation", 0.0, duration)

# GunSlots atışlar arası boşluğu hesaplarken kullanır
func fire_interval() -> float:
	return _fire_interval()

func _fire_interval() -> float:
	return 1.0 / maxf(data.fire_rate * GameState.stats.fire_rate_multiplier, 0.01)

func _damage() -> int:
	var mult := GameState.stats.damage_multiplier * (GameState.SILVER_DAMAGE_MULT if silver else 1.0)
	return maxi(1, roundi(data.damage * mult))
