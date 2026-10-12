class_name PlayerStats
extends RefCounted

const BASE_SWORD_DAMAGE: int = 10

var max_health: int = 100
var health_regen: float = 0.0     # saniyede yenilenen can
var armor: float = 0.0
var move_speed: float = 90.0
var sword_count: int = 1
var rotation_speed: float = 3.0
var damage_multiplier: float = 1.0

func sword_damage() -> int:
	return roundi(BASE_SWORD_DAMAGE * damage_multiplier)

# Zırh yüzde azaltma sağlar: 5 zırh yaklaşık %25 azaltma
func reduce_damage(raw_damage: int) -> int:
	var reduction := armor / (armor + 15.0)
	return maxi(1, roundi(raw_damage * (1.0 - reduction)))
