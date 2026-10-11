@tool
extends EditorScript

# Bu dosya script editöründe açıkken: File → Run (Ctrl+Shift+X)
func _run() -> void:
	# id, ad, açıklama, ilk fiyat, fiyat artışı, stat, miktar, sıra
	var items: Array = [
		["sword_count", "Extra Sword", "+1 sword", 40, 40, "sword_count", 1.0, 0],
		["rotation_speed", "Spin Speed", "+0.4 rotation speed", 15, 10, "rotation_speed", 0.4, 1],
		["damage", "Damage", "+15% damage", 20, 15, "damage_multiplier", 0.15, 2],
		["max_health", "Max Health", "+10 max HP", 15, 10, "max_health", 10.0, 3],
		["regen", "Regeneration", "+0.5 HP/sec", 20, 15, "health_regen", 0.5, 4],
		["armor", "Armor", "+1 armor", 20, 15, "armor", 1.0, 5],
		["move_speed", "Speed", "+6 move speed", 15, 10, "move_speed", 6.0, 6],
		["pickup_range", "Magnet", "+10 pickup range", 10, 8, "pickup_range", 10.0, 7],
	]

	DirAccess.make_dir_recursive_absolute("res://data/upgrades")

	for item in items:
		var u := UpgradeData.new()
		u.id = item[0]
		u.display_name = item[1]
		u.description = item[2]
		u.base_cost = item[3]
		u.cost_step = item[4]
		u.stat = item[5]
		u.amount = item[6]
		u.sort_order = item[7]
		ResourceSaver.save(u, "res://data/upgrades/%s.tres" % u.id)

	EditorInterface.get_resource_filesystem().scan()
	print("Geliştirme dosyaları oluşturuldu.")
