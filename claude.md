Hellstake

Godot 4.7.2 ile geliştirilen 2D top-down, Brotato tarzı, cehennem temalı hayatta kalma oyunu. Steam'de satılacak. Geliştirici Cem; Claude ile birlikte, adım adım ilerliyoruz.

Oyun özeti
Hikaye: Oyuncu, şeytandan intikam almak için cehenneme inen bir karakteri oynar (Constantine'den esinlenen; bkz. "Önemli notlar").
Oynanış: 1-100 arası dalgalar (tur). Her dalgada yaratıklar can/zırh/saldırı olarak güçlenir. Yaratıklar altın düşürür; her dalga sonrası mağazada silah, silah sayısı, ateş/dönme hızı, zırh, can, can yenileme, koşu hızı vb. geliştirmeler alınır.
Boss: Her 10. dalgada (10, 20, 30...) şeytani figürlerden biri boss olur ve bol altın düşürür. 100. dalgada şeytanın kendisi final boss'tur.
Sigara mekaniği (planlı): Karakter her dalga içinde rastgele bir ihtimalle bir kez sigara içer. Küçük bir etkisi olabilir (kısa süreli buff gibi), henüz karar verilmedi.
Silahlar: Dönen kılıç, menzilli silahlar (Glock, AK47) ve ileride farklı aletler.
Harita: 100x100 sabit harita, mimarisi cehennemi andırır.
Teknik temel
Motor: Godot 4.7.2, GDScript, 2D top-down
Viewport: 1024x768 (480x270 denendi, oynanış için küçük kaldı)
Sprite'lar: 16x16 pixel art
Oyuncu animasyonları: 5 yön (down, down_right, right, up_right, up). Sol yönler yatay çevirme (flip) ile yapılır, toplam 8 yön.
GameState autoload: altın ve oyun durumu burada tutulur; Main Menu'ye dönerken GameState.reset() çağrılır.
Veri odaklı yapı: düşmanlar, geliştirmeler ve silahlar .tres kaynaklarıyla tanımlanır (EnemyData, UpgradeData, WeaponData). Yeni düşman/geliştirme/silah eklerken koda gömmek yerine yeni .tres oluştur. data/upgrades/ ve data/weapons/ klasörleri otomatik okunur (UpgradePool, WeaponPool); yeni düşman ise main.tscn > WaveManager > enemy_pool listesine eklenmeli.
Silah sistemi: GameState.guns (en fazla MAX_GUNS = 2 menzilli silah) + stats.sword_count (0 = kılıç yok). Silah verme/alma GameState.give_weapon() / buy_weapon() üzerinden yapılır. UpgradeData.requires ("sword" / "gun") ilgili silah yoksa geliştirmeyi mağazada kilitler. Satma/değiştirme: sell_gun(slot), sell_sword(), swap_gun(slot, weapon); harcama takibi gun_spent / sword_spent / gun_upgrade_spent.
Oyuncu istatistikleri tek yerde toplanır; mağaza buradan beslenir.
Dalga yöneticisi iki modu destekler: süreli dalga ve "hepsini öldür" dalgası (ikisi de denenecek, seçim kullanıcıda).

Dosya yapısı
Bilinen yollar:
assets/audio/ (sfx/: oyunda kullanılan kesilmiş efektler, 16 bit mono WAV; music/: müzikler, stereo OGG; raw/: ham indirmeler, .gdignore ile Godot'dan gizli ve oyuna girmez, Dosya Gezgini'nden kullanılır; CREDITS.md: her sesin kaynağı/yazarı/lisansı)
assets/fonts/ (buraya fontlar eklenecek, klasör şimdilik boş)
assets/sprites/gold/ (GoldCollect.png; altının toplanma sprite'ı, GoldSpin.png; altının dönme sprite'ı)
assets/sprites/gun/ (Ak47.png, Ak47Shoot.png, Glock.png, GlockShoot.png, Bullet.png; hepsi sağa bakıyor)
assets/sprites/monster/ (Monster1IdleSheet.png, Monster1RunSheet.png; yaratıkların sprite'larının bulunduğu yer. Sayfalar 64x64 kare, 4 satır: aşağı, yukarı, sol, sağ; monster1_frames.tres içinde run_down/up/left/right olarak kullanılıyor)
assets/sprites/monster/hell_harpy/ (Hell Harpy, kanatlı iblis; eski adı Hell Bat. Adlandırma: dosyalarda hell_harpy, kodda HellHarpy, oyunda "Hell Harpy". PixelLab ile üretildi. run/animations/<uzun klasör adı>/<yön>/frame_000-008.png: 5 yön (south, south-east, east, north-east, north) x 9 kare, kare boyutu yöne göre 84-92 px. run/rotations/ içindeki duruş pozları kullanılmıyor)
assets/sprites/monster/damned_soul/ ve assets/sprites/monster/hellhound/ (PixelLab Pro Flash, Hell Harpy stil referansıyla 64x64 üretildi; paket olduğu gibi: Idle/rotations/ (kullanılmıyor), Idle/animations/walk (Damned Soul) veya run (Hellhound)/<yön>/frame_000-008.png, 5 yön x 9 kare, kare 84-88 px. SpriteFrames .tres dosyaları bu klasörlerden üretildi, animasyon adları run_south/south_east/east/north_east/north)
assets/sprites/player/ (IdleSheet 16x16.png, RunSheet 16x16.png karakterin idle ve run sprite'ları, sword.png sağa dönük kılıç sprite'ı)
scenes/enemies/enemy.tscn (düşman yaratık sahnesi)
scenes/levels/main.tscn (projenin ana sahnesi)
scenes/pickups/coin.tscn (coin sahnesi)
scenes/player/player.tscn (oyuncunun sahnesi)
scenes/ui/game_over.tscn (game over sahnesi)
scenes/ui/hud.tscn (boss canı gösterme sahnesi)
scenes/ui/pause_menu.tscn (pause sahnesi) 
scenes/ui/shop.tscn (shop sahnesi)
scenes/weapons/sword.tscn (kılıç sahnesi)
scenes/weapons/gun.tscn (menzilli silah sahnesi; görünümü WeaponData'dan koddan kurulur), scenes/weapons/bullet.tscn (mermi), scenes/weapons/gun_slots.gd (Player/GunSlots düğümünün scripti, silahları yuvalara yerleştirir)
scenes/ui/start_choice.gd (oyun başı silah seçim ekranı, Main/StartChoice düğümü; arayüzü koddan kurar)
scenes/ui/main_menu.tscn + main_menu.gd (oyunun açılış sahnesi; tscn sadece kök Control, arayüz koddan kurulur. Play: müziği durdurur, GameState.reset(), main.tscn açar. Options: OptionsMenu açar. Quit: çıkış. Pause menüsündeki Main Menu buraya döner)
scenes/ui/options_menu.gd (class_name OptionsMenu, CanvasLayer layer 30; arayüz koddan kurulur. Ana menü ve duraklatma menüsü OptionsMenu.new() ile kendine ekler, open() ile açar, closed sinyaliyle geri döner. Müzik ve Sound Effects için -/kaydırıcı/+ ve yüzde; Esc ve Back kapatır. Audio.set_bus_volume/get_bus_volume (0-1, değerin karesi dB'ye çevrilir) Music/SFX bus seviyesini değiştirir. Ayar bilerek kaydedilmez: sadece oturum boyunca Audio autoload belleğinde, oyun yeniden açılınca %100 = bizim varsayılan karışım)
data/enemies/ (damned_soul.tres, hell_harpy.tres, hellhound.tres, boss1.tres ve her birinin *_frames.tres animasyonu; monster1.tres = eski Imp, artık havuzda değil, monster1_frames.tres boss1 ve enemy.tscn tarafından hâlâ kullanılıyor), data/upgrades/, data/weapons/ (sword, glock, ak47)
Düşman yön sistemi (enemy.gd): SpriteFrames'teki animasyon adlarına göre otomatik seçilir. run_east/south_east/south/north_east/north varsa 8 yön (batı tarafı flip), run_down/up/left/right varsa 4 yön, ikisi de yoksa tek "run" + yatay flip. Yeni yaratık için 8 yönlü sprite'ta sadece bu 5 yön üretilir.
Duraklatma menüsü: CanvasLayer > Dim, Center > VBox > Title, ResumeButton, MainMenuButton; Resume ile Main Menu arasına koddan "Options" butonu eklenir (Options açıkken Center gizlenir); pause_menu.gd, Esc ile açılır/kapanır. Ayrıca HUD'da sol üstte (MarginContainer/VBoxContainer sonunda, Timer yazısının altında) koddan kurulan "II" PauseButton var; Esc ve buton pause_menu.try_pause() kullanır (mağaza açıkken / oyuncu ölüyken açılmaz).
Ses sistemi: Audio autoload (autoload/audio.gd). Audio.play_sfx("ad") ile çalınır; assets/audio/sfx/ otomatik okunur, dosya adı = ses adı (uzantısız). Varyasyonlar ad_01, ad_02 ... şeklinde, rastgele seçilir + hafif perde oynaması. Dosyası olmayan ses sessizce atlanır. Sesler arası seviye dengesi SFX_VOLUME_DB içinde. SFX ve Music bus'ları koddan oluşturulur. Silah ateş sesi WeaponData.shoot_sound alanından seçilir. Müzik: Audio.play_music("ad") assets/audio/music/ad.ogg dosyasını döngüde çalar (loop koddan açılır, import ayarına gerek yok), parça değişince 1 sn crossfade; Audio.stop_music() kısarak durdurur. Müzik seviyeleri MUSIC_VOLUME_DB içinde; önce dosya adına (gameplay_02), yoksa grup adına (gameplay) bakılır (menu -8 dB, gameplay_01 ve gameplay_02 -16.5 dB, shop 0 dB, boss_music -14 dB). Varyasyonlar: play_music("gameplay") gameplay_01, gameplay_02 ... arasından rastgele seçer; variant parametresiyle sırayla seçilir. Dalga müziği sırayla çalar: tek dalgalar gameplay_01, çift dalgalar gameplay_02 (3. parça gelirse 1-2-3 döner); boss_music.ogg yoksa boss dalgasında sıradaki gameplay parçası çalar. Dosyası olmayan müzikte çalan parça değişmez. Müzik akışı: dalga başı gameplay (boss dalgası: önceki müzik kısılır, boss_spawn sesi bitince boss_music başlar; boss ölünce boss_music 0.1 sn içinde kesilir, sonra boss_death çalar), dalga sonu müzik 0.8 sn kısılır -> shop (wave_start/wave_complete sesleri müzikle çakıştığı için tamamen kaldırıldı, geri eklenmeyecek); ölünce müzik susar, game over ekranı bilerek sessiz (game_over müziği yok, eklenmeyecek); ana menü menu. Müzik dosyaları sfx/ değil music/ altına konur; ham WAV raw/ altında saklanır, oyuna OGG girer.
Ses kaynağı: sesler freesound.org'dan alınıyor (arama sonuçlarında License filtresiyle sadece CC0 / Attribution). Kesme işlemi audiomass.co ile yapılıyor.
Düşman sesleri EnemyData.hit_sound / death_sound / spawn_sound alanlarından seçilir (boşsa ses yok; boss ise ortak boss_hit/boss_death/boss_spawn). Hell Harpy sesli (hell_harpy_hit, hell_harpy_death). Damned Soul sesli (damned_soul_hit 3 varyasyon -8 dB, damned_soul_death -6 dB). Hellhound sesli (hellhound_hit 3 varyasyon, hellhound_death; ikisi de -6 dB).
Ses kuralları: sesler lisansı uygun kaynaklardan (CC0, CC-BY; NC yasak) alınır, her ses CREDITS.md'ye eklenir (kullanıcı freesound attribution metnini verir, Claude ekler). Efektler başındaki sessizlik kırpılmış 16 bit mono WAV; ham dosya raw/ altında _raw ekiyle saklanır.
Test arenası en uzak gidilebilir tile koordinatları: sol üst (-10,-10), sol alt (-10,9), sağ üst (9,-10), sağ alt (9,9). Düşman spawn alanı bu koordinatlara göre ayarlıdır.

Alınmış oyun kararları
Her yeni dalgada oyuncunun canı tamamen dolar.
Dalga bitince canavarlar silinmez; kalanlar öldürülünce mağaza/sonraki dalga gelir.
Dalga sonu mağaza öncesi bekleme (break_time) sabit 1 saniye.
Coin magnet (pickup range) geliştirmesi yok; dalga sonunda altın otomatik toplanır.
Boss can çubuğu kırmızı ve içinde "BOSS" yazar (oyuncu canından ayırt edilsin diye). Çubuk sadece boss dalgasında görünür (boss ölünce ve her dalga sonunda gizlenir).
Menzilli silahlar en yakın canavara otomatik ateş eder. Silahlar oyuncunun etrafındaki görünmez bir çemberde (GunSlots: orbit_radius 10, orbit_speed 9) hedefe en yakın noktaya kayar ve düşmana döner; hedef yokken el konumuna (slot_offsets) döner. İki silah aynı hedefe bakarken pair_spread_degrees (25°) ile yan yana durur. Menzil/hedef seçimi çember merkezinden yapılır.
Silah yuvası 2 tane (çift elle tutma hissi).
İki menzilli silah aynı anda ateş etmez: GunSlots.request_shot() sıra verir, atışlar arası boşluk = en hızlı silahın atış aralığı / silah sayısı (shot_gap_ratio ile ayarlanır). Atışlar seri halinde arka arkaya gelir, sesler üst üste binmez.
Test için GameState.START_GOLD geçici olarak artırılabilir; commit'te 0 olmalı.
Oyun başında oyuncuya Kılıç mı Glock mu diye sorulur; seçilen silahla başlanır.
Toplamda en fazla 2 menzilli silah (Glock/AK47) + 1 kılıç olabilir. Kılıç mağazadan bir kez alınır. 2 silah yuvası doluyken mağazadaki menzilli silahlar "replace" (yuvadaki silahla değiştir) butonu olarak görünür.
Silah satışı: o silah için harcanan toplam paranın %50'si iade edilir (SELL_RATIO). Kılıç satılınca kılıç fiyatı + Extra Sword/Spin Speed harcamasının yarısı iade edilir, bu geliştirmeler sıfırlanır. Fire Rate ortak olduğu için son menzilli silah satılınca iade edilip sıfırlanır. Damage satışta iade edilmez. Başlangıç silahı bedava olduğu için satış fiyatı 0 (sadece ona alınan geliştirmeler). Son silah satılamaz. Değiştirmede net fiyat = yeni fiyat - eski silahın iadesi.
Glock tek tek ateş eder; AK47 otomatik silahtır. Şu anki değerler: Glock 10 hasar / 1.5 atış/sn / 30 altın, AK47 6 hasar / 3 atış/sn / 60 altın, Kılıç 40 altın (.tres içinden ayarlanır).
Damage geliştirmesi kılıca ve menzilli silahlara birlikte uygulanır; Fire Rate sadece menzilli silahlara.
Extra Sword ve Spin Speed geliştirmeleri kılıç yoksa kilitlidir; Fire Rate menzilli silah yoksa kilitlidir.
Normal düşmanlar (hepsi PixelLab, 8 yön, body_scale 0.5): Damned Soul (yavaş kalabalık; 20 can, 35 hız, 5 hasar, ağırlık 1.5, 1. dalgadan), Hell Harpy (hızlı zayıf; 10 can, 60 hız, 3 hasar, ağırlık 1 + dalga başına 0.05, 3. dalgadan), Hellhound (hızlı dayanıklı; 30 can, 70 hız, 7 hasar, 2 altın, ağırlık 0.5 + dalga başına 0.08, 5. dalgadan). Yaratıklar kademeli tanıtılır (1-2. dalga sadece Soul). Imp havuzdan çıkarıldı.
Zorluk eğrisi Brotato tarzı: kalabalık hızlı artar, can yavaş. Doğma aralığı 1.0 sn - dalga başına 0.04 (en az 0.25), dalga süresi 20 sn + dalga başına 2 (en fazla 60), can dalga başına +%12 (enemy.gd HEALTH_PER_WAVE), hasar +%10, hız +%1. EnemyData.spawn_weight_per_wave ile yeni türler dalgalar ilerledikçe sıklaşır. boss1 tabanı 540 can (10. dalgada ~1120).
Yaratıklar gittikleri yöne bakar (hepsi 8 yön; boss1 hâlâ eski 4 yönlü Imp sprite.ını kullanıyor).
Yaratıklar birbirinin içine girmez: enemy.gd içinde yumuşak itme (separation). Fiziksel çarpışma yok; her yaratığın kişisel alanı SEPARATION_RADIUS (20) x body_scale, iç içe girenler birbirini iter (küçük yaratık boss'tan daha çok itilir). Komşu arama her fizik karesinde bir kez kurulan ızgarayla (GRID_CELL 40 px) yapılır. Ayar: SEPARATION_RADIUS (ne kadar seyrek), SEPARATION_STRENGTH (ne kadar hızlı ayrılırlar).
Çizim sırası (Y-sort): Main/WaveManager düğümü Node2D ve y_sort_enabled (script extends Node kalır). Yaratıklar onun çocuğu olarak doğar, ekranda aşağıda olan öne çizilir. Sıralama yaratığın merkezine göre. Oyuncu bu sıralamaya dahil değil (yaratıklar oyuncunun hep önünde çizilir).
İleride: karakter silahı tuttuğu yöne bakacak.
Mağazada "Your weapons" bölümündeki yuva/kılıç butonlarında silahın görseli gösterilir.
Mağaza ekranı görsel olarak şimdilik amatör, ileride güzelleştirilecek.
Mevcut durum
Adım 1-17 tamamlandı: hareket, 8 yönlü animasyon, dönen kılıç, kovalayan düşman, hasar sistemi, altın, GameState, dalga yöneticisi, HUD, mağaza, veri odaklı yapı (.tres), boss sistemi (BossBar dahil), Game Over, duraklatma menüsü, ana menü.
Adım 18 tamamlandı: silah sistemi (Glock/AK47, 2 yuva, en yakın düşmana otomatik nişan, mermi), oyun başı Kılıç/Glock seçimi, mağazada silah bölümü ve Fire Rate geliştirmesi. 10. dalgaya kadar oynanıp boss'la test edildi.
Adım 19 tamamlandı: ikinci normal düşman Hell Harpy (PixelLab sprite'ı, 8 yön) ve yaratıkların gittikleri yöne bakması. Oyunda test edildi.
Adım 20 tamamlandı: mağazada silah satma ("Your weapons" bölümü) ve dolu yuvadaki silahı başka silahla değiştirme. Oyunda test edildi.
Ara adım (20b) tamamlandı: menzilli silahlar oyuncu etrafındaki çemberde hedefe doğru kayıyor; mağazada sahip olunan silahların görseli gösteriliyor. Oyunda test edildi.
Adım 21 tamamlandı: ekranda pause butonu (HUD sol üst, Esc bilmeyenler için). Oyunda test edildi.
Adım 22 (devam ediyor): ses altyapısı (Audio autoload, SFX/Music bus, CREDITS.md, raw/ klasörü). Eklenen sesler: glock_shoot, ak47_shoot (-12 dB), coin_pickup (-7 dB), hell_harpy_hit (3 varyasyon, -6 dB), hell_harpy_death (-6 dB), player_hurt (3 varyasyon, hasar alıp hayatta kalınca), player_death (ölünce, hurt yerine çalar), boss_spawn / boss_hit / boss_death (tüm boss'lar ortak; EnemyData get_*_sound() alan boşsa ve is_boss ise bunları döndürür, özel ses için .tres alanı doldurulur; boss_spawn boss dalgası başlarken çalar; boss_hit üst üste çalmaz, Audio.SFX_MAX_INSTANCES). ui_click (tüm butonlar; mağazada alım/satım sadece başarılı olunca çalar, ayrı buy/sell sesi yok). Audio.play_sfx() çalan AudioStreamPlayer'ı döndürür. İki silahın sırayla ateş etmesi eklendi. Oyunda test edildi.
Not: "gun logic" commit'inde main.tscn yanlışlıkla hud.tscn içeriğiyle kaydedilmişti (siyah ekran); 2da1c97'den geri alınıp düzeltildi. Claude dosya değiştirdiğinde Godot'nun sorusuna "Reload from disk" seçilmeli ve editörde kaydedilmemiş değişiklik bırakılmamalı.
Adım 23 (devam ediyor): Imp yerine Damned Soul, üçüncü düşman Hellhound (PixelLab). Sprite + .tres + havuz hazır, zorluk eğrisi yeniden ayarlandı (Brotato tarzı); Damned Soul ve Hellhound sesleri eklendi (freesound, CREDITS.md). Oyunda test edildi: 17. dalgaya kadar.
Ana menü (Adım 22 içinde) tamamlandı: oyun ana menüden açılır, menu müziği çalar. Oyunda test edildi. İleride menü arka planına sessiz bir "demo savaş" döngüsü eklenecek: elinde 2 AK47 olan karakter sağa sola yürür, yaratıklar doğar ve kesilir; bu arka plan savaşının hiçbir sesi çalmaz (sadece menü müziği), sadece aksiyon görünür.
Adım 24 tamamlandı: Options ekranı (ana menü + duraklatma menüsü), müzik ve efekt sesi ayrı ayarlanır, kaydedilmez. Oyunda test edildi.
Adım 25 tamamlandı: yaratıklar birbirinin içine girmiyor (separation) ve aşağıdaki yaratık öne çiziliyor (Y-sort). Oyunda test edildi.
Sonrasında:
	düşman saldırı animasyonu/mekaniği (şu an sadece temas hasarı var; PixelLab'de attack animasyonu 5 yön üretilecek),
	yeni hikayeye uygun boss çeşitliliği,
	boss çubuğunda "BOSS" yerine o dalganın boss adı yazacak (ör. "Lilith"); ad EnemyData.display_name alanından gelir (HUD BossBar/BossLabel),
	sigara mekaniği,
	silah/alet çeşitliliği,
	final boss (şeytan),
	ses efektleri ve müzikler (altyapı hazır, Adım 22): müzik sistemi hazır, oyuna bağlı; menu, gameplay_01 (Neural Malfunction) ve gameplay_02 (Shadows Awaken Within; ikisi de vitalezzz, OpenGameArt) ve shop (tichec, freesound) eklendi, boss_music (Boss Battle Music, SubspaceAudio, OpenGameArt) eklendi, kalan parça bulunacak: final_boss (şimdilik 100. dalga da boss dalgası olduğu için boss_music çalıyor),
	ana menü arka planında sessiz demo savaş döngüsü,

Çalışma kuralları (Claude için)
İş numaralı adımlarla ilerler. Her adımın sonunda neyin değiştiğini ve nasıl test edeceğimi kısaca söyle.
Büyük değişiklik yapmadan önce planı kısaca yaz ve onay iste. Küçük, net işleri doğrudan yap.
Mevcut yapıya uy: yeni düşman/geliştirme için .tres, ortak durum için GameState, UI için mevcut sahne yapısı.
Sahne (.tscn) dosyalarını elle düzenlemek gerekiyorsa dikkatli ol; düğüm yolları ve anchor ayarları daha önce sorun çıkardı. Değiştirdiğin düğüm yollarını açıkça belirt.
Görsel (sprite) üretemezsin; yeni görsel gerekiyorsa hangi dosya adı, boyut ve yönde istediğini söyle, ben getiririm.
Gereksiz refactor yapma, çalışan sistemi bozma. Emin değilsen sor.
Kod yorumları ve açıklamalar Türkçe olabilir; değişken, fonksiyon ve dosya adları İngilizce kalsın.

Görsel (art) kuralları
Şimdilik örnek/geçici varlıklar kullanılıyor; ileride Pixellab ile özgün varlıklar üretilecek (ilki Hell Harpy).
PixelLab ipuçları: karakter önce sadece duruş (rotations) olarak üretilir, animasyon ayrı ekranda eklenir. Hak tasarrufu için sadece 5 yön (south, south-east, east, north-east, north) üretilir, batı tarafı kodda çevrilir. Animasyon prompt'una yön yazılmaz. İndirilen paket olduğu gibi assets/sprites/monster/<yaratık>/ altına konur. PixelLab ticari kullanım: kontrol edildi (2026-11-12, Tier 1): üretilen görseller oyunlarda ticari olarak kullanılabilir, hakları kullanıcıya aittir; tek yasak bunlarla model eğitmek. PixelLab Claude Code'a MCP ile bağlanır (claude mcp add pixellab https://api.pixellab.ai/mcp -t http -H "Authorization: Bearer <token>"; token repoya girmez).
Yeni sprite'lar 16x16, aynı yön düzeniyle (5 yön + flip) ve tutarlı dosya adlarıyla eklenmeli.
Silah sprite'ları sağa bakacak şekilde hazırlanır.
Yeni yaratık paket halinde eklenir: sprite (PixelLab) + sesler (<yaratık>_hit, <yaratık>_death; freesound.org) + CREDITS.md satırları + .tres (hit_sound/death_sound dahil) aynı adımda hazırlanır.

Önemli notlar
Ana karakter Constantine'den esinlenen özgün bir karakter olmalı. Warner/DC'ye ait ad ve birebir görünüm (isim, sarı trençkot vb.) Steam satışı için risklidir. Karakter adını ve tasarımı satıştan önce netleştir.
Oyun adı Hellstake. (Hellscape ve Escape From Hell adlı oyunlar Steam'de zaten var; Hellstake yok.)
Hedef: özgün müzik, mimari, yaratıklar ve senaryo; satın almaya değer, zevkli bir oynanış.
