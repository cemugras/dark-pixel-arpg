class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var is_melee: bool = false            # true = dönen kılıç, false = menzilli silah (silah yuvası kullanır)
@export var cost: int = 30                    # mağaza fiyatı
@export var sort_order: int = 0               # mağazadaki sıra
@export var icon: Texture2D                   # mağaza / seçim ekranı görüntüsü (sağa bakan); sprite boşsa oyunda da bu kullanılır
@export var shoot_sound: String = ""            # Audio sfx adı (assets/audio/sfx/ içindeki dosya adı, uzantısız). Boşsa ses yok

@export_group("Ranged")
@export var sprite: Texture2D                 # oyun içi (Walt'ın elindeki) görüntü, elsiz, sağa bakan; boşsa icon
@export var grip_point: Vector2 = Vector2(-1, -1)    # sprite pikselinde kabza (yumruğun oturduğu nokta); negatifse oranla tahmin edilir
@export var muzzle_point: Vector2 = Vector2(-1, -1)  # sprite pikselinde namlu ucu; negatifse oranla tahmin edilir
@export var muzzle_flash: Texture2D           # ağız ateşi kareleri yan yana (sağa bakan, dikey ortası namlu hizası); boşsa yok
@export var muzzle_flash_frames: int = 2      # her atışta rastgele biri gösterilir
@export var recoil_distance: float = 2.0      # atışta silah kaç sprite pikseli geri teper (shoot_sheet yoksa)
@export var recoil_degrees: float = 12.0      # atışta namlu kaç derece yukarı kalkar (shoot_sheet yoksa)
@export var shoot_sheet: Texture2D            # yatay ateş animasyonu şeridi (sağa bakan); varsa geri tepme yerine bu oynar
@export var shoot_frame_count: int = 1
@export var sprite_scale: float = 0.35        # silah sprite'ı oyuncuya göre büyük, küçültüyoruz
@export var damage: int = 8
@export var fire_rate: float = 1.5            # saniyedeki atış
@export var attack_range: float = 160.0       # bu mesafedeki en yakın düşmana nişan alır
@export var bullet_speed: float = 320.0
@export var spread_degrees: float = 0.0       # isabetsizlik (+/- derece)
