class_name UpgradePool
extends RefCounted

const FOLDER: String = "res://data/upgrades/"

static var _cache: Array[UpgradeData] = []

static func load_all() -> Array[UpgradeData]:
	if not _cache.is_empty():
		return _cache

	for file_name in DirAccess.get_files_at(FOLDER):
		# Dışa aktarılmış oyunda dosya adının sonuna .remap eklenebilir
		var clean_name := file_name.trim_suffix(".remap")
		if clean_name.ends_with(".tres"):
			var upgrade := load(FOLDER + clean_name) as UpgradeData
			if upgrade:
				_cache.append(upgrade)

	_cache.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.sort_order < b.sort_order)
	return _cache
