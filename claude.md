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
Veri odaklı yapı: düşmanlar ve geliştirmeler .tres kaynaklarıyla tanımlanır (EnemyData, UpgradeData). Yeni düşman/geliştirme eklerken koda gömmek yerine yeni .tres oluştur.
Oyuncu istatistikleri tek yerde toplanır; mağaza buradan beslenir.
Dalga yöneticisi iki modu destekler: süreli dalga ve "hepsini öldür" dalgası (ikisi de denenecek, seçim kullanıcıda).

Dosya yapısı
Bilinen yollar:
assets/audio/ (buraya sesler eklenecek, klasör şimdilik boş)
assets/fonts/ (buraya fontlar eklenecek, klasör şimdilik boş)
assets/sprites/gold/ (GoldCollect.png; altının toplanma sprite'ı, GoldSpin.png; altının dönme sprite'ı)
assets/sprites/gun/ (Ak47.png, Ak47Shoot.png, Glock.png, GlockShoot.png, Bullet.png; hepsi sağa bakıyor)
assets/sprites/monster/ (Monster1IdleSheet.png, Monster1RunSheet.png; yaratıkların sprite'larının bulunduğu yer)
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
Glock tek tek ateş eder; AK47 otomatik silahtır (başlangıç fikri saniyede 1 atış, değerler ayarlanabilir).
İleride: karakter silahı tuttuğu yöne bakacak.
Mağaza ekranı görsel olarak şimdilik amatör, ileride güzelleştirilecek.
Mevcut durum
Adım 1-17 tamamlandı: hareket, 8 yönlü animasyon, dönen kılıç, kovalayan düşman, hasar sistemi, altın, GameState, dalga yöneticisi, HUD, mağaza, veri odaklı yapı (.tres), boss sistemi (BossBar dahil), Game Over, duraklatma menüsü, ana menü, ses altyapısı (Audio autoload).
Sıradaki: Adım 18, silah sistemi (menzilli silahlar, 2 yuva, otomatik nişan).
Sonrasında:
	sadece esc tuşu ile değil, ekranda da bir pause duşu gösterelim ki esc bilmeyenler onu kullansın,
	yeni hikayeye uygun boss çeşitliliği,
	sigara mekaniği,
	silah/alet çeşitliliği,
	final boss (şeytan),
	müzikler eklenecek ve ayarlanacak,
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
