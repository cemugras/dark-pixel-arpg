extends Area2D

@export var hit_interval: float = 0.4  # aynı düşmana iki vuruş arası minimum süre (saniye)

var damage: int = 10
var _next_hit_time: Dictionary = {}  # düşman instance id -> tekrar vurulabileceği zaman (ms)

func _physics_process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	for body in get_overlapping_bodies():
		if not body.has_method("take_damage"):
			continue
		var id := body.get_instance_id()
		if now >= _next_hit_time.get(id, 0):
			body.take_damage(damage)
			_next_hit_time[id] = now + int(hit_interval * 1000.0)

	# süresi dolan kayıtları temizle (ölen düşmanlar birikmesin)
	for id in _next_hit_time.keys():
		if _next_hit_time[id] < now:
			_next_hit_time.erase(id)
