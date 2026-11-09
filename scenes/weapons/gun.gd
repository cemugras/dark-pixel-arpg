extends Node2D

@export var bullet_scene: PackedScene
@export var retarget_interval: float = 0.15  # hedef ne sıklıkla yeniden aranır (saniye)

var data: WeaponData

var _cooldown: float = 0.0
var _target: Node2D = null
var _retarget_timer: float = 0.0
var _player: Node = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle

# GunSlots, silahı sahneye eklemeden önce bunu çağırır
func setup(weapon_data: WeaponData) -> void:
	data = weapon_data

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

	if _target == null:
		return

	var dir := global_position.direction_to(_target.global_position)
	rotation = dir.angle()
	sprite.flip_v = dir.x < 0.0  # sola nişan alırken silah ters görünmesin

	if _cooldown <= 0.0:
		_fire(dir)
		_cooldown = _fire_interval()

func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist := data.attack_range * data.attack_range
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d := global_position.distance_squared_to(enemy.global_position)
		if d <= best_dist:
			best_dist = d
			best = enemy
	return best

# Parametre bilerek tipsiz: ölen (silinmiş) düşman tipli parametreye verilince Godot hata verir
func _is_valid_target(t: Variant) -> bool:
	if not is_instance_valid(t) or t.is_queued_for_deletion():
		return false
	return global_position.distance_to(t.global_position) <= data.attack_range

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

func _fire_interval() -> float:
	return 1.0 / maxf(data.fire_rate * GameState.stats.fire_rate_multiplier, 0.01)

func _damage() -> int:
	return maxi(1, roundi(data.damage * GameState.stats.damage_multiplier))
