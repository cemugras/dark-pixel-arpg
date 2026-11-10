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
@export var spawn_weight: float = 1.0            # doğma olasılığı ağırlığı
@export var min_wave: int = 1
@export var max_wave: int = 100
@export var is_boss: bool = false                # boss'lar normal havuzdan doğmaz
@export var boss_wave: int = 0                   # boss ise hangi dalgada çıkar (10, 20, 30...)
@export var tint: Color = Color.WHITE            # sprite rengi, aynı sprite'tan farklı görünüm için
@export var hit_sound: String = ""             # Audio sfx adı: hasar alınca (boşsa ses yok)
@export var death_sound: String = ""           # Audio sfx adı: ölünce (boşsa ses yok)
