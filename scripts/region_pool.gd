class_name RegionPool
extends RefCounted

const FOLDER: String = "res://data/regions/"

static var _cache: Array[RegionData] = []

static func load_all() -> Array[RegionData]:
	if not _cache.is_empty():
		return _cache
	for file_name in DirAccess.get_files_at(FOLDER):
		# Dışa aktarılmış oyunda dosya adının sonuna .remap eklenebilir
		var clean_name := file_name.trim_suffix(".remap")
		if clean_name.ends_with(".tres"):
			var region := load(FOLDER + clean_name) as RegionData
			if region:
				_cache.append(region)
	_cache.sort_custom(func(a: RegionData, b: RegionData) -> bool: return a.first_wave < b.first_wave)
	return _cache

# Dalganın bölgesi. Henüz yapılmamış bölgelerin dalgalarında en son hazır bölge kullanılır.
static func for_wave(wave: int) -> RegionData:
	var regions := load_all()
	if regions.is_empty():
		return null
	var result: RegionData = regions[0]
	for region in regions:  # first_wave'e göre sıralı
		if region.first_wave <= wave:
			result = region
	return result
