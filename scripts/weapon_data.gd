class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 30                    # mağaza fiyatı
@export var sort_order: int = 0               # mağazadaki sıra
@export var unlock_wave: int = 0              # mağazada bu dalga bitince alınabilir (0 = baştan); öncesinde buton pasif, "(after wave X)" yazar
@export var icon: Texture2D                   # mağaza / seçim ekranı görüntüsü (sağa bakan); sprite boşsa oyunda da bu kullanılır
@export var shoot_sound: String = ""            # Audio sfx adı (assets/audio/sfx/ içindeki dosya adı, uzantısız). Boşsa ses yok
# Adım 52a: el sistemi. "gun" = ateşli silah (Damage/Fire Rate/gümüş mermi alır), "secondary" = ikincil silah
# (el bombası, katana; aynı anda en fazla bir tane). hands 2 = iki elli (AK47): diğer yuvaya ateşli silah girmez.
@export_enum("gun", "secondary") var category: String = "gun"
@export_range(1, 2) var hands: int = 1
# Silah başına geliştirmelerin hangileri bu silahın sütununda çıkar (UpgradeData.scope ile eşleşir): "gun" = Damage/Fire Rate,
# "grenade" = bombanın Damage/Fire Rate. Seviye ve harcama yuvaya aittir (GameState.gun_upgrades).
@export var upgrade_scope: String = "gun"
# Doluysa GunSlots bu silah için gun.tscn yerine bu scripti kurar (ikincil silahlar: GrenadeHand ...)
@export var hand_script: Script

@export_group("Grenade")
@export var blast_radius: float = 40.0        # patlamanın hasar yarıçapı (px)
@export var fuse_time: float = 0.4            # yere düştükten sonra patlamaya kadar (fitil yanıp söner)

@export_group("Katana")
@export var swing_degrees: float = 140.0      # kesiğin yayı (nişan yönünün iki yanına yarısı); bu yaydaki ve menzildeki herkes vurulur
@export var knockback: float = 140.0          # vurulan yaratığın geri itilme hızı (px/sn, hızla söner; boss'lar itilmez)

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
