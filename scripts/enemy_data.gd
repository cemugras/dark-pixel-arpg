class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
# Animasyon adına göre mod: "run_east/south_east/south/north_east/north" = 8 yön (batı flip),
# "run_down/up/left/right" = 4 yön, ikisi de yoksa "run" zorunlu (tek yön + flip)
@export var sprite_frames: SpriteFrames
@export var sprite_faces_right: bool = true      # sadece tek yönlü sprite için: sprite sağa mı bakıyor
@export var body_scale: float = 1.0              # 1.5 yaparsan daha büyük
@export var hitbox_scale: float = 1.0            # çarpışma çemberi ve kişisel alan, body_scale'e ek olarak bu kadar büyür (iri gövdeli boss'lar için)
@export var max_health: int = 30
@export var move_speed: float = 40.0
@export var contact_damage: int = 5             # içine girince verilen hasar (saldırısı olan yaratıkta düşük tutulur)

# --- Saldırı (yakın dövüş) ---
# attack_range 0 ise ya da sprite'ta attack_<yön> animasyonu yoksa yaratık sadece temasla hasar verir.
# Akış: menzile girince durur, oyuncuya döner, animasyon oynar; attack_hit_frame karesinde oyuncu
# hâlâ vuruş menzilindeyse hasar alır (kaçarsa ıska). Vuruştan hemen önce attack_lunge kadar ileri atılır.
@export var attack_range: float = 0.0            # saldırıyı başlatma mesafesi (merkezden merkeze, px)
@export var attack_hit_range: float = 0.0        # vuruş karesinde hasar mesafesi (0 = attack_range x 1.4)
@export var attack_damage: int = 0               # saldırı hasarı (dalgayla temas hasarı gibi artar)
@export var attack_hit_frame: int = 5            # hasarın verildiği animasyon karesi (0'dan sayılır)
@export var attack_lunge: float = 0.0            # vuruştan önceki 2 karede ileri atılma mesafesi (px)
@export var attack_cooldown: float = 1.2         # saldırı bitince tekrar saldırmadan önce bekleme (sn)

# --- Hamle (charge) ---
# charge_interval 0 ise hamle yok. Akış: kovalarken süre dolunca ve oyuncu charge_min_range..charge_max_range
# arasındaysa durur, titrer ve kızarır (uyarı, charge_windup sn; yön uyarı başında kilitlenir), sonra o yöne
# charge_speed ile charge_distance kadar düz atılır (yolda oyuncuya çarparsa charge_damage), ardından
# charge_tired sn yorgun durur (oyuncunun vurma penceresi). Animasyon: charge_<yön> varsa o, yoksa run hızlı oynar;
# tired_<yön> varsa yorgunlukta o, yoksa kare donar.
@export var charge_interval: float = 0.0         # iki hamle arası bekleme (sn, yorgunluk bitince sayılır)
@export var charge_min_range: float = 70.0       # oyuncu bundan yakınsa hamle yerine normal saldırı
@export var charge_max_range: float = 280.0      # oyuncu bundan uzaksa hamle yapmaz, yürür
@export var charge_windup: float = 0.7           # uyarı süresi (sn)
@export var charge_speed: float = 330.0          # hamle hızı (px/sn)
@export var charge_overshoot: float = 60.0       # hamle, kilitlenen oyuncu konumunun bu kadar ötesine gider
@export var charge_max_distance: float = 320.0   # hamle en fazla bu kadar gider
@export var charge_damage: int = 0               # hamle çarpma hasarı (dalgayla artar)
@export var charge_hit_radius: float = 0.0       # çarpma mesafesi (0 = kişisel alan x 1.2)
@export var charge_tired: float = 1.5            # hamle sonrası yorgunluk (sn)
@export var charge_sound: String = ""            # Audio sfx adı: hamle başlarken (boşsa ses yok)

# --- Fırlatma (menzilli saldırı, ör. Mammon'un sikke yağmuru) ---
# throw_count 0 ise ya da sprite'ta throw_<yön> animasyonu yoksa fırlatma yok. Akış: kovalarken throw_interval
# dolunca ve oyuncu throw_min_range..throw_max_range arasındaysa durur, oyuncuya döner, throw_<yön> animasyonu
# (döngüsüz) oynar; throw_release_frame karesinde oyuncuya doğru yelpaze şeklinde throw_count mermi atar.
# throw_alternate açıksa her ikinci atışta bir mermi fazla atılır: tek sayıda ortadaki mermi oyuncuya gider,
# çift sayıda ortada boşluk kalır (oyuncu yerini değiştirmeyi öğrenir).
@export var throw_count: int = 0                 # bir atıştaki mermi sayısı (0 = fırlatma yok)
@export var throw_alternate: bool = false        # her ikinci atışta +1 mermi
@export var throw_spread_degrees: float = 15.0   # yan yana iki mermi arasındaki açı
@export var throw_interval: float = 3.0          # iki atış arası bekleme (sn, atış bitince sayılır)
@export var throw_min_range: float = 0.0         # oyuncu bundan yakınsa atmaz
@export var throw_max_range: float = 260.0       # oyuncu bundan uzaksa atmaz, yürür
@export var throw_release_frame: int = 5         # mermilerin çıktığı animasyon karesi (0'dan sayılır)
@export var throw_damage: int = 0                # mermi hasarı (dalgayla temas hasarı gibi artar)
@export var throw_speed: float = 150.0           # mermi hızı (px/sn)
@export var throw_distance: float = 320.0        # mermi en fazla bu kadar gider
@export var throw_sound: String = ""             # Audio sfx adı: mermiler çıkarken (boşsa ses yok)

# --- Vurdukça sikke saçma (Mammon) ---
# spill_health_step 0 ise yok. Canın her spill_health_step kadarı (ör. 0.1 = %10) gidince yere spill_value
# değerinde sikke saçılır (oyuncu yaklaşınca toplanır, kalanlar dalga sonunda otomatik toplanır).
@export var spill_health_step: float = 0.0
@export var spill_value: int = 0
@export var spill_sound: String = ""             # Audio sfx adı: sikke saçılınca (boşsa ses yok)

@export var coin_value: int = 1
@export var spawn_weight: float = 1.0           # doğma olasılığı ağırlığı (min_wave'deki değer)
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

# Sesler: her yaratık ve boss kendi seslerini .tres alanlarından alır (ör. moloch_hit).
# Ortak boss sesi yok; alan boşsa o ses çalmaz (boss_spawn yoksa boss müziği hemen başlar).
func get_hit_sound() -> String:
	return hit_sound

func get_death_sound() -> String:
	return death_sound

func get_spawn_sound() -> String:
	return spawn_sound
