extends Node

# Ses altyapısı (autoload: Audio)
# Kullanım: Audio.play_sfx("glock_shoot")
# - assets/audio/sfx/ klasörü otomatik okunur. Yeni ses = dosyayı klasöre koymak.
# - Varyasyonlar: glock_shoot_01.wav, glock_shoot_02.wav ... -> "glock_shoot" adıyla rastgele biri çalar.
# - Dosyası olmayan ses sessizce atlanır (oyun bozulmaz).

const SFX_FOLDER: String = "res://assets/audio/sfx/"
const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"
const PLAYER_COUNT: int = 24          # aynı anda çalabilecek toplam efekt sayısı
const MAX_PER_SOUND: int = 4          # aynı sesten aynı anda en fazla kaç tane (50 düşman aynı anda ölünce patlamasın)
const PITCH_JITTER: float = 0.06      # her çalışta perde +/- bu kadar oynar, tekrar hissi azalır

# Sesler arası seviye dengesi (dB). Listede olmayan 0 dB çalar. Sesi kısmak için eksi değer ver.
const SFX_VOLUME_DB: Dictionary = {
	"glock_shoot": -4.0,
	"ak47_shoot": -12.0,
	"coin_pickup": -7.0,
	"hell_bat_hit": -6.0,
	"hell_bat_death": -6.0,
}

var _sounds: Dictionary = {}          # ses adı -> Array[AudioStream] (varyasyonlar)
var _players: Array[AudioStreamPlayer] = []
var _player_sound: Dictionary = {}    # AudioStreamPlayer -> çaldığı ses adı

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # mağaza/duraklatma sırasında da UI sesleri çalsın
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	_load_sfx()
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)

# Master'a bağlı ses kanalı yoksa oluştur (Options menüsündeki ses ayarları bunları kullanacak)
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")

func _load_sfx() -> void:
	if not DirAccess.dir_exists_absolute(SFX_FOLDER):
		return
	# list_directory dışa aktarılmış oyunda da (.import/.remap) doğru dosya adlarını verir
	for file_name in ResourceLoader.list_directory(SFX_FOLDER):
		var ext := file_name.get_extension().to_lower()
		if ext not in ["wav", "ogg", "mp3"]:
			continue
		var stream := load(SFX_FOLDER + file_name) as AudioStream
		if stream == null:
			continue
		var sound_name := _base_name(file_name.get_basename())
		if not _sounds.has(sound_name):
			_sounds[sound_name] = []
		_sounds[sound_name].append(stream)

# "glock_shoot_02" -> "glock_shoot" (sondaki _sayı varyasyon numarasıdır)
func _base_name(file_base: String) -> String:
	var underscore := file_base.rfind("_")
	if underscore != -1 and file_base.substr(underscore + 1).is_valid_int():
		return file_base.substr(0, underscore)
	return file_base

func has_sfx(sound_name: String) -> bool:
	return _sounds.has(sound_name)

func play_sfx(sound_name: String, volume_db: float = 0.0) -> void:
	if sound_name == "" or not _sounds.has(sound_name):
		return
	if _playing_count(sound_name) >= MAX_PER_SOUND:
		return
	var player := _free_player()
	if player == null:
		return
	var variants: Array = _sounds[sound_name]
	player.stream = variants.pick_random()
	player.volume_db = SFX_VOLUME_DB.get(sound_name, 0.0) + volume_db
	player.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	_player_sound[player] = sound_name
	player.play()

func _playing_count(sound_name: String) -> int:
	var count := 0
	for player in _players:
		if player.playing and _player_sound.get(player, "") == sound_name:
			count += 1
	return count

func _free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return null
