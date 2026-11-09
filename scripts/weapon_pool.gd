class_name WeaponPool
extends RefCounted

const FOLDER: String = "res://data/weapons/"

static var _cache: Array[WeaponData] = []

static func load_all() -> Array[WeaponData]:
	if not _cache.is_empty():
		return _cache

	for file_name in DirAccess.get_files_at(FOLDER):
		# Dışa aktarılmış oyunda dosya adının sonuna .remap eklenebilir
		var clean_name := file_name.trim_suffix(".remap")
		if clean_name.ends_with(".tres"):
			var weapon := load(FOLDER + clean_name) as WeaponData
			if weapon:
				_cache.append(weapon)

	_cache.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.sort_order < b.sort_order)
	return _cache
