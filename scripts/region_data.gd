class_name RegionData
extends Resource

# Bir bölgenin (10 dalgalık harita) görünümü. data/regions/ klasörü otomatik okunur (RegionPool).
# Oynanış alanı ve kurallar her bölgede aynı; sadece görsel değişir (bkz. scenes/levels/arena.gd).
# Tile'lar PixelLab Wang tileset'i (16 px, köşe tabanlı). Köşe tabloları PixelLab metadata'sından üretilir:
# anahtar "NW NE SW SE" sırasıyla 4 rakam (0 = lower, 1 = upper, 2 = transition), değer atlas koordinatı.

@export var id: String = ""
@export var display_name: String = ""
@export var first_wave: int = 1
@export var last_wave: int = 10

@export_group("Floor")
@export var floor_texture: Texture2D           # arena zemini: lower = düz zemin, upper = sönük leke (kül, is)
@export var floor_tiles: Dictionary = {}
@export var floor_patches: int = 10            # arenaya serpiştirilen leke sayısı

@export_group("Edge")
@export var edge_texture: Texture2D            # arena kenarı ve ötesi: lower = dış (ör. lav), upper = arena zemini
@export var edge_tiles: Dictionary = {}
@export var edge_tall: bool = true             # true: güney kenarda uçurum yüzü satırı var (transition köşeleri)

@export_group("Decor")
# Arena dışındaki sabit süsler (yürünemez alanda, çarpışmasız): {"texture": Texture2D, "position": Vector2 (dünya, sprite merkezi), "flip": bool}
@export var decor: Array[Dictionary] = []
# Dış alana rastgele serpiştirilen küçük süsler (ör. lav kayaları); sabit süslerle ve birbirleriyle çakışmaz
@export var scatter_textures: Array[Texture2D] = []
@export var scatter_count: int = 0
@export var scatter_reach: float = 230.0       # arena kenarından en fazla bu kadar uzağa (kamera kenarda bunu görür)

@export_group("Effects")
@export var animate_outside: bool = true       # dıştaki doygun (kızgın) piksellere dalgalanan parlaklık shader'ı
@export var ember_color: Color = Color(1.0, 0.55, 0.15)
@export var ember_amount: int = 220            # dış alandan yükselen kor sayısı (toplam)
@export var smoke_color: Color = Color(0.22, 0.16, 0.16, 0.35)
@export var smoke_amount: int = 40
# true: kül bölgesi (ör. Belphegor'un Uyku Salonları): korlar yerine yukarıdan yavaşça düşen kül pulları (ember_color,
# parlamaz), duman yerine yatay sürünen sis (smoke_color), kenar boyunca kıvılcım yok
@export var ash_fall: bool = false
# ash_fall bölgesinde düşen pulların renkleri (ör. Asmodeus'un Bahçeleri: kızıl, mor, zehir yeşili yapraklar);
# doluysa pul sayısı renklere eşit bölünür ve ember_color yerine bunlar kullanılır, boşsa sadece ember_color
@export var ember_colors: Array[Color] = []
# Dış alanda yer yer vızıldayan küçük sinek bulutları (ör. Beelzebub'un Bataklığı); 0 = yok
@export var fly_swarms: int = 0
@export var fly_color: Color = Color(0.06, 0.07, 0.05, 1.0)
