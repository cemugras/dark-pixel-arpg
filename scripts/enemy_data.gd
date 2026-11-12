class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
# Animasyon adına göre mod: "run_east/south_east/south/north_east/north" = 8 yön (batı flip),
# "run_down/up/left/right" = 4 yön, ikisi de yoksa "run" zorunlu (tek yön + flip)
@export var sprite_frames: SpriteFrames
@export var sprite_faces_right: bool = true      # sadece tek yönlü sprite için: sprite sağa mı bakıyor
@export var body_scale: float = 1.0              # 1.5 yaparsan daha büyük
@export var max_health: int = 30
@export var move_speed: float = 40.0
@export var contact_damage: int = 5
@export var coin_value: int = 1
@export var spawn_weight: float = 1.0            # doğma olasılığı ağırlığı (min_wave'deki değer)
@export var spawn_weight_per_wave: float = 0.0   # min_wave'den sonraki her dalgada ağırlığa eklenir (yeni türler giderek sıklaşır)
@export var min_wave: int = 1
@export var max_wave: int = 100
@export var is_boss: bool = false                # boss'lar normal havuzdan doğmaz
@export var boss_wave: int = 0                   # boss ise hangi dalgada çıkar (10, 20, 30...)
@export var tint: Color = Color.WHITE            # sprite rengi, aynı sprite'tan farklı görünüm için
@export var hit_sound: String = ""             # Audio sfx adı: hasar alınca (boşsa ses yok)
@export var death_sound: String = ""           # Audio sfx adı: ölünce (boşsa ses yok)
@export var spawn_sound: String = ""           # Audio sfx adı: doğunca (boşsa ses yok)

func get_spawn_weight(wave: int) -> float:
	return spawn_weight + spawn_weight_per_wave * maxi(wave - min_wave, 0)

# Boss sesleri: alan boşsa tüm boss'lar ortak sesleri kullanır (boss_hit, boss_death, boss_spawn).
# Özel ses isteyen boss için .tres içinde alanı doldurmak yeterli.
func get_hit_sound() -> String:
	return _sound_or_boss_default(hit_sound, "boss_hit")

func get_death_sound() -> String:
	return _sound_or_boss_default(death_sound, "boss_death")

func get_spawn_sound() -> String:
	return _sound_or_boss_default(spawn_sound, "boss_spawn")

func _sound_or_boss_default(sound: String, boss_default: String) -> String:
	if sound == "" and is_boss:
		return boss_default
	return sound
