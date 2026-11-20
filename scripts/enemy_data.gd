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
@export var keep_distance: float = 0.0           # >0: oyuncuya bundan fazla yaklaşmaz, yakına gelirse geri çekilir (uzaktan büyücü Lilim); 0 = kovalar
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
@export var attack_knockback: float = 0.0       # vuruş isabet edince oyuncuyu geri itme hızı (px/sn, hızla söner; 0 = itme yok; Ram Brute toslaması)

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

# --- Çağırma (ör. Beelzebub'un sinek sürüsü) ---
# summon_data boşsa ya da sprite'ta summon_<yön> animasyonu yoksa çağırma yok. Akış: kovalarken summon_interval
# dolunca durur, oyuncuya döner, summon_<yön> animasyonu (döngüsüz) oynar; summon_release_frame karesinde etrafına
# summon_count yaratık çıkarır (aynı anda en fazla summon_max_alive). Çağrılanlar altın düşürmez (yaratığı öldürüp
# altın kasılmasın), çağıran ölünce hepsi ölür.
@export var summon_data: EnemyData                # çağrılan yaratık (boşsa çağırma yok)
@export var summon_count: int = 5                # bir çağırmada çıkan sayı
@export var summon_count_max: int = 0            # > summon_count ise her çağırmada sayı summon_count..bu arasında rastgele
@export var summon_max_alive: int = 12           # aynı anda en fazla bu kadar çağrılmış yaratık
@export var summon_interval: float = 6.0         # iki çağırma arası bekleme (sn, çağırma bitince sayılır)
@export var summon_release_frame: int = 6        # yaratıkların çıktığı animasyon karesi (0'dan sayılır)
@export var summon_radius: float = 40.0          # çağıranın etrafında bu uzaklıkta çıkarlar (px)
@export var summon_sound: String = ""            # Audio sfx adı: yaratıklar çıkarken (boşsa ses yok)

# --- Büyü: yere rün çemberleri (ör. Lilith'in kan rünleri) ---
# cast_count 0 ise ya da sprite'ta cast_<yön> animasyonu yoksa büyü yok. Akış: kovalarken cast_interval dolunca ve
# oyuncu cast_max_range içindeyse durur, oyuncuya döner, cast_<yön> animasyonu (döngüsüz) oynar; cast_release_frame
# karesinde yere cast_count rün çizilir: ilki oyuncunun tam altına, diğerleri çevresine (cast_spread içinde rastgele).
# Rünler cast_delay sn yanıp söner (uyarı), sonra patlar; o an çemberin içinde kalan oyuncu cast_damage alır.
@export var cast_count: int = 0                  # bir büyüdeki rün sayısı (0 = büyü yok)
@export var cast_interval: float = 4.0           # iki büyü arası bekleme (sn, büyü bitince sayılır)
@export var cast_max_range: float = 300.0        # oyuncu bundan uzaksa büyü yapmaz, yürür
@export var cast_release_frame: int = 5          # rünlerin çizildiği animasyon karesi (0'dan sayılır)
@export var cast_radius: float = 26.0            # rün çemberinin yarıçapı (px, hasar alanı)
@export var cast_spread: float = 70.0            # ek rünler oyuncunun bu kadar çevresine düşer (px)
@export var cast_delay: float = 1.0              # rün çizildikten patlamaya kadar uyarı süresi (sn)
@export var cast_damage: int = 0                 # patlama hasarı (dalgayla temas hasarı gibi artar)
@export var cast_sound: String = ""              # Audio sfx adı: rünler çizilirken (boşsa ses yok)
@export var cast_blast_sound: String = ""        # Audio sfx adı: rün patlarken (boşsa ses yok)
@export var cast_focus: bool = true               # büyü/patlama sesi play_sfx_focus ile mi (boss: evet; kalabalık yaratık: hayır, yoksa diğer sesler sürekli susar)

# --- Dalış: yerin altından gelip patlayarak çıkma (ör. Leviathan) ---
# dive_interval 0 ise ya da sprite'ta emerge_<yön> animasyonu yoksa dalış yok. Akış: kovalarken dive_interval dolunca
# ve oyuncu dive_max_range içindeyse durur, kıvrılarak zemine batar (kodla: sprite aşağı kayar, zemin çizgisinin altı
# gizlenir). Yerin altında görünmez ve vurulamaz (mermi, kılıç, temas, nişan yok); yerde bir lav dalgacığı burrow_time
# sn boyunca burrow_speed ile oyuncuyu kovalar. Sonra dalgacık durur, emerge_warning sn uyarı verir (kaçma payı), boss
# yerden yükselirken emerge animasyonu (kükreyip dikilme) oynar:
# emerge_release_frame karesinde emerge_radius içindeki oyuncu emerge_damage alır. Ardından emerge_recover sn
# yerinde durur (vurma penceresi).
@export var dive_interval: float = 0.0           # iki dalış arası bekleme (sn, toparlanma bitince sayılır; 0 = dalış yok)
@export var dive_max_range: float = 320.0        # oyuncu bundan uzaksa dalmaz, yürür
@export var burrow_time: float = 2.0             # yerin altında oyuncuyu kovalama süresi (sn)
@export var burrow_speed: float = 80.0           # yer altındaki hız (px/sn; oyuncunun 90'ından biraz yavaş)
@export var emerge_warning: float = 0.6          # dalgacık durduktan sonra fırlamadan önceki uyarı (sn)
@export var emerge_release_frame: int = 3        # patlamanın olduğu emerge karesi (0'dan sayılır)
@export var emerge_radius: float = 50.0          # patlama yarıçapı (px, hasar alanı)
@export var emerge_damage: int = 0               # patlama hasarı (dalgayla temas hasarı gibi artar)
@export var emerge_recover: float = 1.0          # çıktıktan sonra yerinde durma süresi (sn)
@export var dive_sound: String = ""              # Audio sfx adı: lava dalarken (boşsa ses yok)
@export var emerge_sound: String = ""            # Audio sfx adı: fırlarken (boşsa ses yok)
@export var emerge_focus: bool = true            # true: çıkış sesi play_sfx_focus ile (boss); kalabalık yaratıkta (Magma Worm) false

# --- Nefes: etrafında dönen koniler (ör. Asmodeus'un üç başı) ---
# breath_count 0 ise ya da sprite'ta breath_<yön> animasyonu yoksa nefes yok. Akış: kovalarken breath_interval dolunca
# ve oyuncu breath_max_range içindeyse durur, oyuncuya döner, breath_<yön> animasyonu oynar (breath_hold_frame karesinde
# ağızlar açık kalır). Etrafına eşit aralıklı breath_count koni çizilir (ilki oyuncuya bakar): breath_windup sn soluk
# uyarı, sonra breath_duration sn nefes; koniler bu sürede breath_spin_degrees/sn ile (her seferinde rastgele yöne)
# döner. Koninin içinde kalan oyuncu breath_damage alır (oyuncunun dokunulmazlığı vuruş sıklığını sınırlar).
# Bitince animasyon kalanını oynar, breath_recover sn yerinde durur.
@export var breath_count: int = 0                # koni sayısı (0 = nefes yok)
@export var breath_interval: float = 5.0         # iki nefes arası bekleme (sn, toparlanma bitince sayılır)
@export var breath_max_range: float = 170.0      # oyuncu bundan uzaksa nefes yapmaz, yürür
@export var breath_range: float = 110.0          # koninin uzunluğu (px, merkezden)
@export var breath_width_degrees: float = 50.0   # bir koninin açısı
@export var breath_windup: float = 0.8           # uyarı süresi (sn, koniler soluk ve dönmez)
@export var breath_duration: float = 2.0         # nefes süresi (sn, koniler döner)
@export var breath_spin_degrees: float = 60.0    # dönme hızı (derece/sn)
@export var breath_hold_frame: int = 4           # animasyonun ağızların açık kaldığı karesi (0'dan sayılır)
@export var breath_damage: int = 0               # konideki hasar (dalgayla temas hasarı gibi artar)
@export var breath_recover: float = 0.8          # nefesten sonra yerinde durma süresi (sn)
@export var breath_colors: Array[Color] = []     # koni renkleri sırayla (boşsa kızıl, mor, yeşil)
@export var breath_sound: String = ""            # Audio sfx adı: nefes başlarken (uyarı bitince; boşsa ses yok)

# --- Çekirge seli: oyuncunun yolunu kesen geniş çekirge duvarı (ör. Abaddon) ---
# locust_length 0 ise ya da sprite'ta locust_<yön> animasyonu yoksa sel yok. Akış: kovalarken locust_interval dolunca
# ve oyuncu locust_min_range..locust_max_range arasındaysa durur, oyuncuya döner, locust_<yön> animasyonu oynar
# (locust_hold_frame karesinde bekler). Boss'tan oyuncuya doğru, bu yöne dik locust_length boyunda bir duvar
# locust_warning sn uyarı verir (zeminde selin geçeceği alan, güvenli boşluğun şeridi açık), sonra locust_speed ile
# oyuncunun konumunu locust_overshoot geçene kadar akar. Duvarda locust_gap genişliğinde bir boşluk var (ortası
# oyuncunun hizasından locust_gap_min..locust_gap_max kadar yanda, yönü rastgele); duvarın uçları da güvenli.
# Duvara değen oyuncu locust_damage alır. Uyarı bitince animasyon kalanını oynar, locust_recover sn yerinde durur.
@export var locust_length: float = 0.0           # duvar boyu (px; 0 = sel yok)
@export var locust_thickness: float = 36.0       # duvar kalınlığı (px)
@export var locust_interval: float = 6.0         # iki sel arası bekleme (sn, toparlanma bitince sayılır)
@export var locust_min_range: float = 110.0      # oyuncu bundan yakınsa sel yapmaz (kaçacak zaman kalmaz)
@export var locust_max_range: float = 320.0      # oyuncu bundan uzaksa sel yapmaz, yürür
@export var locust_gap: float = 80.0             # güvenli boşluğun genişliği (px; 0 = boşluk yok, sadece uçlardan dolaşılır)
@export var locust_gap_min: float = 30.0         # boşluk ortasının oyuncu hizasına en az uzaklığı
@export var locust_gap_max: float = 140.0        # ... en çok uzaklığı
@export var locust_speed: float = 140.0          # duvarın akış hızı (px/sn)
@export var locust_overshoot: float = 200.0      # duvar oyuncunun (uyarı başındaki) konumunu bu kadar geçince biter
@export var locust_warning: float = 1.0          # uyarı süresi (sn)
@export var locust_hold_frame: int = 4           # animasyonun uyarı boyunca beklediği kare (0'dan sayılır)
@export var locust_damage: int = 0               # duvardaki hasar (dalgayla temas hasarı gibi artar)
@export var locust_recover: float = 1.0          # selden sonra yerinde durma süresi (sn)
@export var locust_sound: String = ""            # Audio sfx adı: sel akmaya başlarken (boşsa ses yok)
@export var locust_focus: bool = true            # true: ses play_sfx_focus ile (boss); kalabalık yaratıkta false

# --- Düello atışı (Azazel) ---
# duel_interval 0 olan ya da shoot_<yön> animasyonu olmayan yaratıklar etkilenmez. Etrafında havada iki silah döner
# (oyuncunun o an taşıdığı silahların kopyası, görünüm ve ses silahtan; hasar ve mermi sayısı buradan, silahtan bağımsız).
# duel_interval dolunca ve oyuncu duel_min..max_range arasındaysa durur, shoot animasyonu duel_hold_frame karesinde
# bekler; her silahtan oyuncuya kızıl nişan çizgisi: duel_track_time sn oyuncuyu izler, duel_lock_time sn kilitlenir
# (parlar), sonra iki silah sırayla o hatlar boyunca duel_shots'ar mermi atar. Bitince silahlar soğur, boss
# duel_recover sn durur (vurma penceresi). Kovalarken keep_distance ile mesafe korur ve duel_strafe oranında yana kayar.
@export var duel_interval: float = 0.0
@export var duel_min_range: float = 0.0
@export var duel_max_range: float = 300.0
@export var duel_track_time: float = 0.6         # nişan çizgilerinin oyuncuyu izlediği süre (sn)
@export var duel_lock_time: float = 0.35         # çizgiler kilitli, ateşten hemen önce (sn)
@export var duel_shots: int = 6                  # silah başına mermi
@export var duel_shot_gap: float = 0.07          # ardışık iki mermi arası (iki silah sırayla; sn)
@export var duel_spread_degrees: float = 2.0     # mermi sapması (+/- derece)
@export var duel_bullet_speed: float = 280.0
@export var duel_bullet_distance: float = 420.0
@export var duel_damage: int = 0                 # mermi hasarı (dalgayla temas hasarı gibi artar)
@export var duel_hold_frame: int = 4             # animasyonun nişan boyunca beklediği kare (0'dan sayılır)
@export var duel_recover: float = 1.0            # seriden sonra yerinde durma süresi (sn)
@export var duel_orbit_radius: float = 34.0      # silahların gövde merkezine uzaklığı (px)
@export var duel_gun_scale: float = 1.0          # silah sprite'ının ölçeği (oyuncudaki sprite_scale yerine)
@export var duel_strafe: float = 0.0             # kovalarken yana kayma oranı (0 = yok, 1 = ileri hız kadar)
@export var duel_sound: String = ""              # Audio sfx adı: nişan başlarken (boşsa ses yok)
@export var duel_fallback_weapon: WeaponData     # oyuncunun silahı yoksa (olmamalı) kullanılan silah
@export var duel_weapon: WeaponData              # doluysa iki silah da bu (Azazel: mızrak); boşsa oyuncunun silahları kopyalanır
@export var duel_follow_fire: bool = false       # true: seri boyunca da oyuncuyu izler (kilit sadece ateşten önce)
@export var duel_rest_upright: bool = false      # true: boştayken silahlar ellerde dik durur (mızrak), nişanda öne süzülüp döner
@export var duel_gun_count: int = 2              # 1 ya da 2 silah (Grigori 1)
@export var duel_show_weapon: bool = true        # false: silah görünmez (yaratık sprite'ında zaten elinde), çizgi ve oklar yine çıkar
@export var duel_shot_db: float = -3.0           # atış sesinin ek seviyesi (kalabalık yaratıkta kısık)
@export var duel_focus: bool = true              # true: nişan sesi play_sfx_focus ile (boss); kalabalık yaratıkta false

# --- Fazlar (Lucifer: önceki boss'ların yeteneklerinin karışımı) ---
# phase_thresholds boşsa faz yok, yaratığın bütün yetenekleri hep açık (eski davranış). Doluysa can oranı her eşiğin
# altına inince bir sonraki faza geçilir (ör. [0.7, 0.35] = 3 faz). Her fazda sadece phase_abilities[faz] içinde
# virgülle yazılan yetenekler kullanılır: charge, throw, summon, cast, dive, breath, locust, duel (yakın saldırı hep açık).
# phase_interval_mult < 1: yetenek bekleme süreleri o oranda kısalır; phase_speed_mult: yürüme hızı çarpanı;
# phase_tints: fazın sprite rengi (boşsa tint). Faz değişince phase_sound çalar (play_sfx_focus).
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array()
@export var phase_abilities: PackedStringArray = PackedStringArray()
@export var phase_interval_mult: PackedFloat32Array = PackedFloat32Array()
@export var phase_speed_mult: PackedFloat32Array = PackedFloat32Array()
@export var phase_tints: Array[Color] = []
@export var phase_sound: String = ""
# Bir yetenek bitince bir sonrakinin başlaması için en az bu kadar beklenir (iki yetenek arka arkaya binmesin; 0 = yok)
@export var special_gap: float = 0.0
# Animasyon eşleme: bir yeteneğin animasyonu yoksa başka animasyon kullanılır, ör. {"breath": "cast", "shoot": "cast"}
# (anahtar ve değer animasyon adının yön öncesi kısmı: cast, breath, locust, shoot, summon, throw, emerge, attack)
@export var anim_aliases: Dictionary = {}
# Efekt rengi: alfa 0 ise her efekt kendi rengini kullanır. Doluysa rün, çekirge duvarı, nişan çizgisi, ok ve hamle
# uyarısı bu renkten türetilir (Lucifer: buz mavisi; nefes konileri breath_colors ile ayrıca verilir)
@export var fx_color: Color = Color(0, 0, 0, 0)

# --- Taht (Lucifer'in ilk fazı) ---
# throne_texture doluysa boss ilk fazda tahtında oturur: throne_position'da (dünya koordinatı, görselin merkezi) bu görsel
# çizilir, boss yürümez, yetenekleri tahttan kullanır; gövdesi (vuruş çemberi) throne_seat_offset'te. İkinci faza
# geçerken ayağa kalkar: tahtta throne_empty_texture kalır (Biscuit), boss rise_time sn içinde throne_stand_offset'e
# iner (bu sürede vurulamaz), sonra savaşa katılır.
@export var throne_texture: Texture2D
@export var throne_empty_texture: Texture2D
@export var throne_position: Vector2 = Vector2.ZERO
@export var throne_seat_offset: Vector2 = Vector2.ZERO
@export var throne_stand_offset: Vector2 = Vector2(0, 60)
@export var rise_time: float = 1.5

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
@export var swarm_size: int = 1                  # bir doğmada aynı noktadan kaç tane çıkar (Hell Fly sürüsü); ağırlık sürü başınadır
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
