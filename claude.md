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
Silah sistemi: GameState.guns (en fazla MAX_GUNS = 2 menzilli silah) + stats.sword_count (0 = kılıç yok). Silah verme/alma GameState.give_weapon() / buy_weapon() üzerinden yapılır. UpgradeData.requires ("sword" / "gun") ilgili silah yoksa geliştirmeyi mağazada kilitler.
Oyuncu istatistikleri tek yerde toplanır; mağaza buradan beslenir.
Dalga yöneticisi iki modu destekler: süreli dalga ve "hepsini öldür" dalgası (ikisi de denenecek, seçim kullanıcıda).

Dosya yapısı
Bilinen yollar:
assets/audio/ (buraya sesler eklenecek, klasör şimdilik boş)
assets/fonts/ (buraya fontlar eklenecek, klasör şimdilik boş)
assets/sprites/gold/ (GoldCollect.png; altının toplanma sprite'ı, GoldSpin.png; altının dönme sprite'ı)
assets/sprites/gun/ (Ak47.png, Ak47Shoot.png, Glock.png, GlockShoot.png, Bullet.png; hepsi sağa bakıyor)
assets/sprites/monster/ (Monster1IdleSheet.png, Monster1RunSheet.png; yaratıkların sprite'larının bulunduğu yer. Sayfalar 64x64 kare, 4 satır: aşağı, yukarı, sol, sağ; kodda şimdilik sadece 1. satır (aşağı) kullanılıyor)
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
data/enemies/ (monster1.tres = Imp, bat.tres = Hell Bat, boss1.tres), data/upgrades/, data/weapons/ (sword, glock, ak47)
Duraklatma menüsü: CanvasLayer > Dim, Center > VBox > Title, ResumeButton, MainMenuButton; pause_menu.gd, Esc ile açılır/kapanır
Test arenası en uzak gidilebilir tile koordinatları: sol üst (-10,-10), sol alt (-10,9), sağ üst (9,-10), sağ alt (9,9). Düşman spawn alanı bu koordinatlara göre ayarlıdır.

Alınmış oyun kararları
Her yeni dalgada oyuncunun canı tamamen dolar.
Dalga bitince canavarlar silinmez; kalanlar öldürülünce mağaza/sonraki dalga gelir.
Dalga sonu mağaza öncesi bekleme (break_time) sabit 1 saniye.
Coin magnet (pickup range) geliştirmesi yok; dalga sonunda altın otomatik toplanır.
Boss can çubuğu kırmızı ve içinde "BOSS" yazar (oyuncu canından ayırt edilsin diye).
Menzilli silahlar en yakın canavara otomatik ateş eder.
Silah yuvası 2 tane (çift elle tutma hissi).
Oyun başında oyuncuya Kılıç mı Glock mu diye sorulur; seçilen silahla başlanır.
Toplamda en fazla 2 menzilli silah (Glock/AK47) + 1 kılıç olabilir. Kılıç mağazadan bir kez alınır. 2 silah yuvası doluyken silahlar mağazada yine görünür ama pasiftir.
Glock tek tek ateş eder; AK47 otomatik silahtır. Şu anki değerler: Glock 10 hasar / 1.5 atış/sn / 30 altın, AK47 6 hasar / 3 atış/sn / 60 altın, Kılıç 40 altın (.tres içinden ayarlanır).
Damage geliştirmesi kılıca ve menzilli silahlara birlikte uygulanır; Fire Rate sadece menzilli silahlara.
Extra Sword ve Spin Speed geliştirmeleri kılıç yoksa kilitlidir; Fire Rate menzilli silah yoksa kilitlidir.
Her dalgada Imp ve daha zayıf/hızlı Hell Bat birlikte çıkar (spawn_weight eşit). Hell Bat şimdilik Imp sprite'ının küçültülmüş, mor tonlu hâlidir; özgün sprite gelince bat.tres güncellenecek.
İleride: karakter silahı tuttuğu yöne bakacak.
Mağaza ekranı görsel olarak şimdilik amatör, ileride güzelleştirilecek.
Mevcut durum
Adım 1-17 tamamlandı: hareket, 8 yönlü animasyon, dönen kılıç, kovalayan düşman, hasar sistemi, altın, GameState, dalga yöneticisi, HUD, mağaza, veri odaklı yapı (.tres), boss sistemi (BossBar dahil), Game Over, duraklatma menüsü, ana menü. Ses/müzik altyapısı henüz yok (Audio autoload yapılmadı).
Adım 18 tamamlandı: silah sistemi (Glock/AK47, 2 yuva, en yakın düşmana otomatik nişan, mermi), oyun başı Kılıç/Glock seçimi, mağazada silah bölümü ve Fire Rate geliştirmesi. 10. dalgaya kadar oynanıp boss'la test edildi.
Adım 19: ikinci normal düşman Hell Bat eklendi (geçici sprite).
Not: Şu an oyun açılınca direkt oyun sahnesi açılıyor. Ana menü kısmı şimdilik tamam sayılıyor ama asıl ana menü (aşağıdaki maddeler) her şey bittikten sonra yapılacak.
Sonrasında:
	yaratıklar gittikleri yöne baksın (sprite sayfalarındaki 4 yön satırı kullanılacak: aşağı, yukarı, sol, sağ),
	silah satma ve yuvaları farklı silahlarla değiştirme,
	Hell Bat için özgün sprite,
	sadece esc tuşu ile değil, ekranda da bir pause duşu gösterelim ki esc bilmeyenler onu kullansın,
	yeni hikayeye uygun boss çeşitliliği,
	sigara mekaniği,
	silah/alet çeşitliliği,
	final boss (şeytan),
	ses altyapısı (Audio autoload) ve müzikler: lisans sorunu olmayan, oyunun atmosferine uygun müzik/ses efektleri eklenecek ve ayarlanacak,
	oyun açıldığında ilk olarak ana menü gibi bir menü ayarlanacak, burada play game, options, quit butonları olacak.

Çalışma kuralları (Claude için)
İş numaralı adımlarla ilerler. Her adımın sonunda neyin değiştiğini ve nasıl test edeceğimi kısaca söyle.
Büyük değişiklik yapmadan önce planı kısaca yaz ve onay iste. Küçük, net işleri doğrudan yap.
Mevcut yapıya uy: yeni düşman/geliştirme için .tres, ortak durum için GameState, UI için mevcut sahne yapısı.
Sahne (.tscn) dosyalarını elle düzenlemek gerekiyorsa dikkatli ol; düğüm yolları ve anchor ayarları daha önce sorun çıkardı. Değiştirdiğin düğüm yollarını açıkça belirt.
Görsel (sprite) üretemezsin; yeni görsel gerekiyorsa hangi dosya adı, boyut ve yönde istediğini söyle, ben getiririm.
Gereksiz refactor yapma, çalışan sistemi bozma. Emin değilsen sor.
Kod yorumları ve açıklamalar Türkçe olabilir; değişken, fonksiyon ve dosya adları İngilizce kalsın.

Görsel (art) kuralları
Şimdilik örnek/geçici varlıklar kullanılıyor; ileride Pixellab ile özgün varlıklar üretilecek.
Yeni sprite'lar 16x16, aynı yön düzeniyle (5 yön + flip) ve tutarlı dosya adlarıyla eklenmeli.
Silah sprite'ları sağa bakacak şekilde hazırlanır.

Önemli notlar
Ana karakter Constantine'den esinlenen özgün bir karakter olmalı. Warner/DC'ye ait ad ve birebir görünüm (isim, sarı trençkot vb.) Steam satışı için risklidir. Karakter adını ve tasarımı satıştan önce netleştir.
Oyun adı Hellstake. (Hellscape ve Escape From Hell adlı oyunlar Steam'de zaten var; Hellstake yok.)
Hedef: özgün müzik, mimari, yaratıklar ve senaryo; satın almaya değer, zevkli bir oynanış.
