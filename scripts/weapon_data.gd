class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var is_melee: bool = false            # true = dönen kılıç, false = menzilli silah (silah yuvası kullanır)
@export var cost: int = 30                    # mağaza fiyatı
@export var sort_order: int = 0               # mağazadaki sıra
@export var icon: Texture2D                   # seçim ekranı ve silahın duruş görüntüsü (sağa bakan)
@export var shoot_sound: String = ""            # Audio sfx adı (assets/audio/sfx/ içindeki dosya adı, uzantısız). Boşsa ses yok

@export_group("Ranged")
@export var shoot_sheet: Texture2D            # yatay ateş animasyonu şeridi (sağa bakan)
@export var shoot_frame_count: int = 1
@export var sprite_scale: float = 0.35        # silah sprite'ı oyuncuya göre büyük, küçültüyoruz
@export var damage: int = 8
@export var fire_rate: float = 1.5            # saniyedeki atış
@export var attack_range: float = 160.0       # bu mesafedeki en yakın düşmana nişan alır
@export var bullet_speed: float = 320.0
@export var spread_degrees: float = 0.0       # isabetsizlik (+/- derece)
