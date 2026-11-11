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
	"wave_start": -3.0,
	"wave_complete": -4.0,
	"player_hurt": 0.0,
	"player_death": 0.0,
	"boss_spawn": 0.0,
	"boss_death": 0.0,
	"boss_hit": 0.0,
}

# Aynı anda en fazla kaç kopya çalabileceği sese özel ayar (listede yoksa MAX_PER_SOUND).
# 1 = ses bitmeden aynı ses tekrar çalmaz.
const SFX_MAX_INSTANCES: Dictionary = {
	"boss_hit": 1,
}

# --- Müzik ---
# Kullanım: Audio.play_music("menu") -> res://assets/audio/music/menu.ogg döngüde çalar.
# Dosyası olmayan müzik sessizce atlanır (çalan müzik kısılarak durur).
const MUSIC_FOLDER: String = "res://assets/audio/music/"
const MUSIC_EXTENSIONS: Array[String] = ["ogg", "mp3"]  # döngü için OGG önerilir
const MUSIC_FADE_TIME: float = 1.0    # parçalar arası geçiş süresi (sn)
const SILENT_DB: float = -60.0

# Müzikler arası seviye dengesi (dB). Listede olmayan 0 dB çalar.
const MUSIC_VOLUME_DB: Dictionary = {
	"menu": -8.0,
}

var _sounds: Dictionary = {}          # ses adı -> Array[AudioStream] (varyasyonlar)
var _players: Array[AudioStreamPlayer] = []
var _player_sound: Dictionary = {}    # AudioStreamPlayer -> çaldığı ses adı

# İki müzik çalar: biri kısılırken diğeri açılır (crossfade)
var _music_players: Array[AudioStreamPlayer] = []
var _music_index: int = 0
var _music_tweens: Dictionary = {}    # AudioStreamPlayer -> Tween
var _current_music: String = ""

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
	for i in 2:
		var music_player := AudioStreamPlayer.new()
		music_player.bus = MUSIC_BUS
		add_child(music_player)
		_music_players.append(music_player)

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

# Çalan AudioStreamPlayer'ı döndürür (ses bitince bir şey yapmak için finished sinyaline bağlanılabilir).
# Ses çalmadıysa null döner.
func play_sfx(sound_name: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if sound_name == "" or not _sounds.has(sound_name):
		return null
	if _playing_count(sound_name) >= SFX_MAX_INSTANCES.get(sound_name, MAX_PER_SOUND):
		return null
	var player := _free_player()
	if player == null:
		return null
	var variants: Array = _sounds[sound_name]
	player.stream = variants.pick_random()
	player.volume_db = SFX_VOLUME_DB.get(sound_name, 0.0) + volume_db
	player.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	_player_sound[player] = sound_name
	player.play()
	return player

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

# --- Müzik ---

# Aynı müzik zaten çalıyorsa baştan başlatmaz.
func play_music(music_name: String, fade_time: float = MUSIC_FADE_TIME) -> void:
	if music_name == _current_music:
		return
	var stream := _load_music(music_name)
	stop_music(fade_time)  # çalan parça kısılarak durur
	if stream == null:
		return
	_current_music = music_name
	_music_index = 1 - _music_index
	var player := _music_players[_music_index]
	var target_db: float = MUSIC_VOLUME_DB.get(music_name, 0.0)
	player.stream = stream
	player.volume_db = SILENT_DB if fade_time > 0.0 else target_db
	player.play()
	_fade_music(player, target_db, fade_time, false)

func stop_music(fade_time: float = MUSIC_FADE_TIME) -> void:
	_current_music = ""
	var player := _music_players[_music_index]
	if player.playing:
		_fade_music(player, SILENT_DB, fade_time, true)

func current_music() -> String:
	return _current_music

func _load_music(music_name: String) -> AudioStream:
	for ext in MUSIC_EXTENSIONS:
		var path := MUSIC_FOLDER + music_name + "." + ext
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			elif stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			return stream
	return null

func _fade_music(player: AudioStreamPlayer, to_db: float, fade_time: float, stop_after: bool) -> void:
	if _music_tweens.has(player):
		(_music_tweens[player] as Tween).kill()
		_music_tweens.erase(player)
	if fade_time <= 0.0:
		player.volume_db = to_db
		if stop_after:
			player.stop()
		return
	var tween := create_tween()  # Audio PROCESS_MODE_ALWAYS olduğu için oyun dururken de ilerler
	tween.tween_property(player, "volume_db", to_db, fade_time)
	if stop_after:
		tween.tween_callback(player.stop)
	_music_tweens[player] = tween
