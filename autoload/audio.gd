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
	"smg_shoot": -7.0,          # Glock sesi; Glock (-4) ile aynı ama 3 kat sık ateş ettiği için biraz kısık
	"revolver_shoot": -5.0,
	"grenade_explode": -6.0,    # el bombası (Adım 52b); 2 sn'de bir ve daha sık patlar, silahlardan biraz kısık
	"katana_slash": -6.0,       # katana kesiği (Adım 52c), 3 varyasyon; saniyede 1-2 kez çalar, hafif
	"coin_pickup": -7.0,
	"hell_harpy_hit": -6.0,
	"hell_harpy_death": -6.0,
	"damned_soul_hit": -8.0,     # en kalabalık düşman, çok sık çalar
	"damned_soul_death": -6.0,
	"hellhound_hit": -6.0,
	"hellhound_death": -6.0,
	"player_hurt": 0.0,
	"player_death": 0.0,
	"moloch_spawn": 0.0,
	"moloch_death": 0.0,
	"moloch_hit": 0.0,
	"belphegor_spawn": 0.0,
	"belphegor_death": 0.0,
	"belphegor_hit": 0.0,
	"mammon_spawn": 0.0,
	"mammon_death": 0.0,
	"mammon_hit": 0.0,
	"mammon_spill": 0.0,
	"beelzebub_spawn": 0.0,
	"beelzebub_death": 0.0,
	"beelzebub_hit": -6.0,      # yarı ses: 1.1 sn uzun, sık çalıyor ve sinek sesini bastırıyordu
	"beelzebub_summon": 3.0,   # dosyadaki tek tık bastırılıp vızıltı +12 dB yapıldı; üstüne +3
	"lilith_spawn": 0.0,
	"lilith_hit": 0.0,
	"lilith_death": 0.0,
	"lilith_cast": 0.0,
	"lilith_rune_blast": 0.0,
	"leviathan_spawn": 0.0,
	"leviathan_hit": 0.0,
	"leviathan_death": 0.0,
	"leviathan_dive": 0.0,
	"leviathan_emerge": 0.0,
	"asmodeus_spawn": 0.0,
	"asmodeus_hit": 0.0,       # 3 varyasyon (_01, _02, _03)
	"asmodeus_death": 0.0,
	"asmodeus_breath": 0.0,
	"abaddon_spawn": 0.0,
	"abaddon_hit": 0.0,
	"abaddon_death": 0.0,
	"abaddon_swarm": 0.0,
	"azazel_spawn": 0.0,
	"azazel_hit": 0.0,
	"azazel_death": 0.0,
	"azazel_aim": 0.0,
	"belphegor_charge": 0.0,
	"lilim_hit": -10.0,         # Lilith seslerinin ince ve kısık kopyası (SFX_ALIASES)
	"lilim_death": -8.0,
	"lilim_cast": -8.0,
	"lilim_rune_blast": -8.0,
	"abyss_locust_hit": -8.0,  # kalabalık yaratık, kısık
	"abyss_locust_death": -6.0,
	"abyss_locust_swarm": -10.0,  # Abaddon sel sesinin ince ve kısık kopyası (SFX_ALIASES)
	"grigori_hit": -8.0,  # Azazel sesinin ince ve kısık kopyası (SFX_ALIASES)
	"grigori_death": -6.0,
	"grigori_aim": -10.0,
	"sloth_fiend_hit": -8.0,   # Belphegor sesinin ince ve kısık kopyası (SFX_ALIASES)
	"sloth_fiend_death": -6.0,
	"sloth_fiend_charge": -8.0,
	"ram_brute_hit": -8.0,     # Moloch sesinin ince ve kısık kopyası (SFX_ALIASES)
	"ram_brute_death": -6.0,
}

# Aynı anda en fazla kaç kopya çalabileceği sese özel ayar (listede yoksa MAX_PER_SOUND).
# 1 = ses bitmeden aynı ses tekrar çalmaz.
const SFX_MAX_INSTANCES: Dictionary = {
	"grenade_explode": 2,  # sık atılan bomba patlamaları üst üste binip müziği boğmasın
	"katana_slash": 2,
	"moloch_hit": 1,  # boss hit sesleri üst üste binmesin (her yeni boss için eklenir)
	"belphegor_hit": 1,
	"mammon_hit": 1,
	"beelzebub_hit": 1,
	"lilith_hit": 1,
	"lilith_rune_blast": 1,  # 3 rün aynı anda patlar: tek ses yeter, üst üste binip patlamasın
	"leviathan_hit": 1,
	"asmodeus_hit": 1,
	"abaddon_hit": 1,
	"azazel_hit": 1,
	"lilim_hit": 1,        # kalabalık yaratık: Lilith sesi üst üste binmesin
	"lilim_death": 2,
	"lilim_cast": 1,
	"lilim_rune_blast": 1,
	"abyss_locust_hit": 1,
	"abyss_locust_death": 2,
	"abyss_locust_swarm": 1,
	"grigori_hit": 1,
	"grigori_death": 2,
	"grigori_aim": 2,
	"sloth_fiend_hit": 1,
	"sloth_fiend_death": 2,
	"sloth_fiend_charge": 2,
	"ram_brute_hit": 1,
	"ram_brute_death": 2,
	"lucifer_hit": 1,
	"lucifer_rune_blast": 1,
	"lucifer_frost": 1,
}

# Başka sesin dosyasını kullanan sesler (ayrı dosya yok): ad -> kaynak ses. Seviye (SFX_VOLUME_DB), üst üste çalma
# (SFX_MAX_INSTANCES) ve perde (SFX_PITCH) yine bu adla ayarlanır. Lilim, Lilith'in seslerini ince ve kısık kullanır.
# SMG, Glock sesini kullanır.
const SFX_ALIASES: Dictionary = {
	"lilim_hit": "lilith_hit",
	"lilim_death": "lilith_death",
	"lilim_cast": "lilith_cast",
	"lilim_rune_blast": "lilith_rune_blast",
	"abyss_locust_swarm": "abaddon_swarm",  # Abyss Locust, Abaddon sel sesini ince ve kısık kullanır
	"grigori_hit": "azazel_hit",  # Grigori (Azazel'in çırağı), Azazel'in seslerini ince ve kısık kullanır
	"grigori_death": "azazel_death",
	"grigori_aim": "azazel_aim",
	# Lucifer (100. dalga) önceki boss'ların yeteneklerini kullanır: o yeteneklerin seslerini kalın perdeyle çalar.
	# Kendi dosyası eklenirse (ör. lucifer_breath.wav) o çalar.
	"lucifer_cast": "lilith_cast",
	"lucifer_rune_blast": "lilith_rune_blast",
	"lucifer_aim": "azazel_aim",
	"lucifer_breath": "asmodeus_breath",
	"lucifer_frost": "abaddon_swarm",
	"lucifer_charge": "belphegor_charge",
	"lucifer_summon": "beelzebub_summon",
	"smg_shoot": "glock_shoot",  # SMG Glock ile aynı mermiyi atar, sadece daha hızlı ve otomatik: aynı ses
	"sloth_fiend_hit": "belphegor_hit",  # Sloth Fiend (Belphegor'un evcil hayvanı), Belphegor'un seslerini ince ve kısık kullanır
	"sloth_fiend_death": "belphegor_death",
	"sloth_fiend_charge": "belphegor_charge",
	"ram_brute_hit": "moloch_hit",  # Ram Brute (Moloch bölgesinin tankı), Moloch'un seslerini biraz ince ve kısık kullanır
	"ram_brute_death": "moloch_death",
}

# Sese özel perde çarpanı (listede yoksa 1.0; PITCH_JITTER bunun üstüne uygulanır). >1 = daha ince/küçük.
const SFX_PITCH: Dictionary = {
	"lilim_hit": 1.3,
	"lilim_death": 1.3,
	"lilim_cast": 1.25,
	"lilim_rune_blast": 1.25,
	"abyss_locust_swarm": 1.3,
	"grigori_hit": 1.3,
	"grigori_death": 1.3,
	"grigori_aim": 1.25,
	"lucifer_cast": 0.8,
	"lucifer_rune_blast": 0.8,
	"lucifer_aim": 0.8,
	"lucifer_breath": 0.8,
	"lucifer_frost": 0.7,
	"lucifer_charge": 0.8,
	"lucifer_summon": 0.8,
	"sloth_fiend_hit": 1.3,
	"sloth_fiend_death": 1.3,
	"sloth_fiend_charge": 1.3,
	"ram_brute_hit": 1.2,
	"ram_brute_death": 1.2,
}

# --- Müzik ---
# Kullanım: Audio.play_music("menu") -> res://assets/audio/music/menu.ogg döngüde çalar.
# Dosyası olmayan müzik sessizce atlanır (çalan müzik kısılarak durur).
const MUSIC_FOLDER: String = "res://assets/audio/music/"
const MUSIC_EXTENSIONS: Array[String] = ["ogg", "mp3"]  # döngü için OGG önerilir
const MUSIC_FADE_TIME: float = 1.0    # parçalar arası geçiş süresi (sn)
const SILENT_DB: float = -60.0

# Müzikler arası seviye dengesi (dB). Önce dosya adına (gameplay_02), yoksa grup adına (gameplay) bakılır; ikisi de yoksa 0 dB.
# %85 kısmak = -16.5 dB, %80 = -14 dB, %60 = -8 dB, %50 = -6 dB, %25 = -2.5 dB
const MUSIC_VOLUME_DB: Dictionary = {
	"menu": -8.0,
	"gameplay_01": -16.5,  # %85 kısık
	"gameplay_02": -16.5,  # %85 kısık
	"shop": 0.0,  # henüz ayarlanmadı
	"boss_music": -14.0,  # %80 kısık
}

var _sounds: Dictionary = {}          # ses adı -> Array[AudioStream] (varyasyonlar)
var _players: Array[AudioStreamPlayer] = []
var _player_sound: Dictionary = {}    # AudioStreamPlayer -> çaldığı ses adı
var _exclusive_player: AudioStreamPlayer = null  # çalarken başka efekt çalmaz (boss giriş sesi)
var _focus_player: AudioStreamPlayer = null      # çalarken yaratık vuruş/ölüm sesleri çalmaz (play_sfx_focus)
const FOCUS_SHOT_DB: float = -6.0                # play_sfx_focus sesi çalarken silah ateş sesleri bu kadar kısılır (-6 dB = yarı)

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

# --- Oyuncu ses ayarı (Options ekranı) ---
# 0.0 - 1.0 arası; 1.0 = bizim varsayılan karışımımız (SFX_VOLUME_DB / MUSIC_VOLUME_DB olduğu gibi).
# Bilerek KAYDEDİLMEZ: sadece bu oyun oturumu boyunca bellekte tutulur, oyun yeniden açılınca 1.0'a döner.
const DEFAULT_BUS_VOLUME: float = 1.0
var _bus_volume: Dictionary = {}  # bus adı -> 0.0-1.0

func get_bus_volume(bus_name: String) -> float:
	return _bus_volume.get(bus_name, DEFAULT_BUS_VOLUME)

func set_bus_volume(bus_name: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	_bus_volume[bus_name] = value
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, value <= 0.0)
	# Kulak sesi logaritmik duyar: değerin karesi kullanılır, %50 belirgin şekilde yarı ses gibi gelir (-12 dB)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value * value, 0.0001)))

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
	# Takma adlar kaynak sesin dosyalarını paylaşır (bkz. SFX_ALIASES)
	for alias in SFX_ALIASES:
		if _sounds.has(SFX_ALIASES[alias]) and not _sounds.has(alias):  # kendi dosyası varsa (ör. smg_shoot.wav) o çalar
			_sounds[alias] = _sounds[SFX_ALIASES[alias]]

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
# exclusive = true: bu ses bitene kadar diğer efektler çalmaz (boss giriş kahkahası vuruş seslerine bastırılmasın diye).
# Müzik bundan etkilenmez.
func play_sfx(sound_name: String, volume_db: float = 0.0, exclusive: bool = false) -> AudioStreamPlayer:
	if sound_name == "" or not _sounds.has(sound_name):
		return null
	if is_instance_valid(_exclusive_player) and _exclusive_player.playing:
		return null
	if _playing_count(sound_name) >= SFX_MAX_INSTANCES.get(sound_name, MAX_PER_SOUND):
		return null
	if is_instance_valid(_focus_player) and _focus_player.playing and _is_creature_sound(sound_name):
		return null
	var player := _free_player()
	if player == null:
		return null
	var variants: Array = _sounds[sound_name]
	player.stream = variants.pick_random()
	player.volume_db = SFX_VOLUME_DB.get(sound_name, 0.0) + volume_db
	if is_instance_valid(_focus_player) and _focus_player.playing and sound_name.ends_with("_shoot"):
		player.volume_db += FOCUS_SHOT_DB  # büyü/patlama sesi çalarken ateş sesleri yarıya iner
	player.pitch_scale = SFX_PITCH.get(sound_name, 1.0) * randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	_player_sound[player] = sound_name
	# Havuzdaki oynatıcı tekrar kullanılıyor: tek başına çalan ses bitmiş demektir, artık başka sesleri susturmasın
	# (eskiden kahkaha biten oynatıcı ateş sesi çalarken tüm efektler susuyordu)
	if player == _exclusive_player:
		_exclusive_player = null
	if player == _focus_player:
		_focus_player = null
	if exclusive:
		_exclusive_player = player
	player.play()
	return player

# Önemli boss sesi (ör. Lilith'in büyüsü ve rün patlaması): çalan yaratık vuruş/ölüm sesleri kesilir ve bu ses
# bitene kadar yenileri çalmaz, böylece kalabalıkta duyulur. Silah ateş sesleri (*_shoot) bu sürede yarı seste
# çalar (FOCUS_SHOT_DB). Müzik ve oyuncu sesleri etkilenmez (rün oyuncuya çarparsa player_hurt yine çalar).
func play_sfx_focus(sound_name: String) -> AudioStreamPlayer:
	if sound_name == "" or not _sounds.has(sound_name):
		return null
	for p in _players:
		if p.playing and _is_creature_sound(_player_sound.get(p, "")):
			p.stop()
	var player := play_sfx(sound_name)
	if player:
		_focus_player = player
	return player

# Yaratık ve boss vuruş/ölüm sesleri (oyuncunun kendi sesleri hariç)
func _is_creature_sound(sound_name: String) -> bool:
	if sound_name.begins_with("player_"):
		return false
	return sound_name.ends_with("_hit") or sound_name.ends_with("_death")

# Çalan tüm kopyalarını hemen susturur (ör. Beelzebub sinek çağırırken uzun hit sesi vızıltıyı bastırmasın)
func stop_sfx(sound_name: String) -> void:
	for player in _players:
		if player.playing and _player_sound.get(player, "") == sound_name:
			player.stop()

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
# Varyasyonlar: "gameplay" -> gameplay.ogg ya da gameplay_01.ogg, gameplay_02.ogg ... arasından rastgele biri.
# Dosyası olmayan müzikte çalan parça değişmez (ör. boss.ogg yoksa gameplay müziği sürer).
# loop = false: tek sefer çalar (game_over gibi).
# variant >= 0: rastgele yerine sırayla seçer (0 -> _01, 1 -> _02, varyasyon sayısını aşınca başa döner).
func play_music(music_name: String, fade_time: float = MUSIC_FADE_TIME, loop: bool = true, variant: int = -1) -> void:
	if music_name == _current_music:
		return
	var paths := _music_paths(music_name)
	if paths.is_empty():
		return
	var path: String = paths[variant % paths.size()] if variant >= 0 else paths.pick_random()
	var stream := _load_music(path, loop)
	if stream == null:
		return
	stop_music(fade_time)  # çalan parça kısılarak durur
	_current_music = music_name
	_music_index = 1 - _music_index
	var player := _music_players[_music_index]
	var target_db := _music_volume(music_name, path)
	player.stream = stream
	player.volume_db = SILENT_DB if fade_time > 0.0 else target_db
	player.play()
	_fade_music(player, target_db, fade_time, false)

func stop_music(fade_time: float = MUSIC_FADE_TIME) -> void:
	_current_music = ""
	var player := _music_players[_music_index]
	if player.playing:
		_fade_music(player, SILENT_DB, fade_time, true)

func has_music(music_name: String) -> bool:
	return not _music_paths(music_name).is_empty()

func current_music() -> String:
	return _current_music

# Önce dosyaya özel seviye (ör. "gameplay_02"), yoksa grup seviyesi (ör. "gameplay"), o da yoksa 0 dB
func _music_volume(music_name: String, path: String) -> float:
	var file_base := path.get_file().get_basename()
	if MUSIC_VOLUME_DB.has(file_base):
		return MUSIC_VOLUME_DB[file_base]
	return MUSIC_VOLUME_DB.get(music_name, 0.0)

func _load_music(path: String, loop: bool) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	return stream

# "gameplay" -> [gameplay.ogg] varsa o, yoksa [gameplay_01.ogg, gameplay_02.ogg ...]
func _music_paths(music_name: String) -> Array[String]:
	var paths: Array[String] = []
	var exact := _find_music_file(music_name)
	if exact != "":
		paths.append(exact)
		return paths
	for i in range(1, 100):
		var variant := _find_music_file("%s_%02d" % [music_name, i])
		if variant == "":
			break
		paths.append(variant)
	return paths

func _find_music_file(file_base: String) -> String:
	for ext in MUSIC_EXTENSIONS:
		var path := MUSIC_FOLDER + file_base + "." + ext
		if ResourceLoader.exists(path):
			return path
	return ""

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
