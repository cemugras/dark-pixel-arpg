class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var sprite_frames: SpriteFrames          # "run" animasyonu zorunlu
@export var sprite_faces_right: bool = true      # sprite sağa mı bakıyor
@export var body_scale: float = 1.0              # 1.5 yaparsan daha büyük
@export var max_health: int = 30
@export var move_speed: float = 40.0
@export var contact_damage: int = 5
@export var coin_value: int = 1
@export var spawn_weight: float = 1.0            # doğma olasılığı ağırlığı
@export var min_wave: int = 1
@export var max_wave: int = 100
@export var is_boss: bool = false                # boss'lar normal havuzdan doğmaz
