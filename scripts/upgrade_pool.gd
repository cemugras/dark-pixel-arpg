class_name UpgradePool
extends RefCounted

# cost: ilk fiyat | step: her alımda fiyat artışı | stat: PlayerStats'taki değişken | amount: eklenen miktar
# Ondalıklı değişkenlerde amount'u mutlaka 1.0 gibi ondalıklı yaz.
const UPGRADES: Array[Dictionary] = [
	{"id": "sword_count", "name": "Extra Sword", "desc": "+1 sword", "cost": 40, "step": 40, "stat": "sword_count", "amount": 1},
	{"id": "rotation_speed", "name": "Spin Speed", "desc": "+0.4 rotation speed", "cost": 15, "step": 10, "stat": "rotation_speed", "amount": 0.4},
	{"id": "damage", "name": "Damage", "desc": "+15% damage", "cost": 20, "step": 15, "stat": "damage_multiplier", "amount": 0.15},
	{"id": "max_health", "name": "Max Health", "desc": "+10 max HP", "cost": 15, "step": 10, "stat": "max_health", "amount": 10},
	{"id": "regen", "name": "Regeneration", "desc": "+0.5 HP/sec", "cost": 20, "step": 15, "stat": "health_regen", "amount": 0.5},
	{"id": "armor", "name": "Armor", "desc": "+1 armor", "cost": 20, "step": 15, "stat": "armor", "amount": 1.0},
	{"id": "move_speed", "name": "Speed", "desc": "+6 move speed", "cost": 15, "step": 10, "stat": "move_speed", "amount": 6.0},
	{"id": "pickup_range", "name": "Magnet", "desc": "+10 pickup range", "cost": 10, "step": 8, "stat": "pickup_range", "amount": 10.0},
]
