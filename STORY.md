# Hellstake — Hikâye

> **"Hell took his cat. Bad idea."**

Bu dosya oyunun hikâyesi, karakterleri ve hikâyenin oyun mekaniklerine nasıl bağlandığı için tek kaynaktır. Oyun içi metinler İngilizce yazılır (Türkçe çeviri ileride).

## Özet

Yorgun bir gece bekçisi olan **Walt Ember**, kedisi **Biscuit** Lucifer tarafından kaçırılınca peşinden cehenneme iner. 100 dalga boyunca cehennemin iblis lordlarını tek tek yener; her biri Biscuit'i bir sonrakine "devretmiştir". Sonunda Lucifer'in tahtına ulaşır.

Steam kısa açıklaması (taslak):
> A tired night guard descends into Hell to bring back his cat. 100 waves. 10 demon lords. One very angry man.

## Karakterler

### Walt Ember (oyuncu)

- 40'larının başında, bir depoda **gece bekçisi**. Yalnız yaşar, hayattan pek beklentisi yoktur; tek bağı kedisi Biscuit.
- Huysuz ama iyi kalpli, az konuşur. Konuştuğunda kuru, tek cümlelik iğneleyici şeyler söyler.
- Sigarayı bırakmaya çalışıyor ama bırakamıyor (oyundaki sigara mekaniği buradan gelir).
- **Görünüm (sprite için):** solgun gri kapüşonlu, üstünde açık lacivert eski bir iş ceketi (göğsünde "NIGHT SHIFT" arması), bol kot pantolon, yıpranmış botlar, dağınık koyu saç, birkaç günlük sakal, yorgun göz altları, kulağının arkasında bir sigara, belinde boş bir kedi tasması.
- Özgün bir karakterdir: Constantine/DC'ye ait ad, trençkot ya da birebir görünüm kullanılmaz.

### Biscuit (kedi)

- Turuncu tekir, bir kulağı hafif kesik; gözleri bazen belli belirsiz kızıl parlar. İlk bakışta tamamen sıradan bir kedi.
- **Sır:** Biscuit aslında Lucifer'in bir zamanlar en sevdiği evcil hayvanı, cehennemin "kapı bekçisi" kedisidir. Sıkılıp insan dünyasına kaçmış, sokakta Walt tarafından bulunmuş ve yıllardır dünyanın en sıradan, en mutlu hayatını sürmektedir. Lucifer onu geri ister, çünkü o yokken cehennemin kapıları "açık kalır".

### Lucifer (final boss, 100. dalga)

- Tahtında, kucağında Biscuit ile oturur. Kediyi gerçekten sever; kaçırma bir intikam değil, sahiplenmedir.

### Brimm, gezgin tüccar (mağaza)

- Kanatlı bir iblis tüccar; adı "brimstone"dan (kükürt). Ruhların düşürdüğü kükürt sikkeleriyle silah satar ve Walt'a hep "kedin hakkında bir şeyler duydum" diye ipucu verir. Kurnaz ama sevimli bir esnaf; düşman değil.
- **Görünüm:** ufak tefek, goblin benzeri bir iblis. Mor-gri ten, yeşil kukuleta, yuvarlak gözlükler ardında kehribar gözler, sivri kulaklar, küçük boynuzlar, mor yarasa kanatları, biblolarla dolu bir yelek, belinde sikke kesesi, sırtında rengârenk mallarla dolu tahta bir sandık. Mor-yeşil tonları onu kırmızı cehennem yaratıklarından ayırır.
- **Konuşması:** mağaza her açıldığında kısa, iğneleyici bir replik söyler (ör. *"Silver bullets. Demons hate 'em. Business loves 'em."*, *"Brimstone only. No refunds. Well... half."*). Replikler arada Biscuit'in izine dair dedikodu da içerir.
- **Akış:** dalga bitince havadan kanatlarıyla Walt'ın yanına iner, mağaza penceresi açılır (pencerede tüccarın görüntüsü), alışveriş bitince pencere kapanır, tüccar kanatlanıp havalanır ve gider; yeni dalga ondan sonra başlar.

### Mavi ve Kırmızı Melek (satın alınabilir yardımcılar)

- Biscuit'in eski koruyucuları. Kedi kaçırılınca Walt'a yardıma gelirler; mağazadan "çağrılırlar".
- Mavi Melek sağ omzun üstünde uçar, koruyucudur (her dalga yenilenen ek can). Kırmızı Melek sol omzun üstünde uçar, saldırgandır (yakına gelen yaratıklara hasar).

## Mekaniklerin hikâyedeki karşılığı

| Mekanik | Hikâyedeki karşılığı |
|---|---|
| Altın | Cehennemin para birimi: lanetli ruhların düşürdüğü kükürt sikkeleri. Kükürt sarısı, kenarı pürüzlü, ortasında boynuzlu iblis damgası olan sikke. Ekranda "Gold" yazısı yok, sadece sikke ikonu ve sayı görünür (kodda adı hâlâ gold) |
| Mağaza | Kanatlı gezgin iblis tüccar Brimm: her dalga sonunda havadan iner, alışveriş bitince havalanıp gider |
| Sigara | Walt dalga içinde bir kez sigara yakar, kısa bir rahatlama (küçük buff) |
| Mavi / Kırmızı Melek | Biscuit'in eski koruyucuları |
| Glock | Walt'ın gece bekçisi tabancası |
| Diğer silahlar, kılıç | Cehennemden toplanan ya da tüccardan alınan silahlar: Revolver (ağır tek atış), AK47 (seri atış), dönen kılıç |
| Gümüş mermi | Tüccardan silah başına alınan, iblislere karşı gümüş mermiler: daha güçlü, parlak görünür |
| Normal yaratıklar | Damned Soul (lanetli ruhlar), Hell Harpy, Hellhound: cehennemin sıradan sakinleri |

## Açılış (intro)

> Gece vardiyasından dönen Walt kapıyı açtığında evin içi kükürt kokuyor. Biscuit'in mama kabı devrilmiş, yerde yanık pençe izleri var. Duvarda kömürle yazılmış tek bir cümle:
>
> **"HE'S MINE. — L."**
>
> Walt ceketini giyiyor, bir sigara yakıyor ve bodrumdaki çatlaktan aşağı iniyor.

Hem yazıyla hem animasyonla anlatılacak (bkz. "Ara sahneler").

## Boss'lar ve hikâye akışı

Her boss Biscuit'i bir sonrakine teslim etmiştir. Walt her birinden kediye ait bir iz alır (başarım / ödül olarak kullanılabilir).

Boss'lar zayıftan güçlüye sıralanır; her biri oyuna bir yeni mekanik getirir ve bu mekanik karakterinden gelir.

| Dalga | Boss | Ne oldu | Mekanik | Bulunan iz |
|---|---|---|---|---|
| 10 | Moloch | Cehennemin kapı bekçisi. Kediyi kafeste görmüş ama "çok ateşliydi" diye Belphegor'a yollamış. | Yavaş tank, yeni mekanik yok (iki yumrukla yere vurur) | Yanmış tasma kopçası |
| 20 | Belphegor | Kediyi kucağında uyutmaya çalışmış, kedi tırmalamış. | Uyuşuk yürür, aniden uyanıp hamle yapar, sonra yorulup esner | Yanağındaki pençe izi |
| 30 | Mammon | Kediyi satmaya kalkmış. | Vurdukça altın saçar | "PRICELESS" fiyat etiketi |
| 40 | Beelzebub | Kedi sineklerini avlamış, kızmış. | Sinek sürüsü çağırır | Oyuncak fare |
| 50 | Lilith | Oyunun ortası, dönüm noktası: Walt'a Biscuit'in sırrını anlatır. | Hızlı, yaratık çağırır, büyü yapar | Biscuit'in eski cehennem fotoğrafı |
| 60 | Leviathan | Kediyi lav denizinin karşısına taşımış. | Yere dalıp çıkar, alan saldırısı | Islak tüy yumağı |
| 70 | Asmodeus | Üç başı kedinin kime ait olduğu konusunda kavga eder. | Her başın ayrı saldırısı (üç saldırı) | Kırık mama kabı |
| 80 | Abaddon | Yıkım meleği; Walt'ı "geri dön" diye uyarır. | Çekirge sürüleri, geniş alan | Kedinin çan sesi |
| 90 | Azazel | Walt'a benzer silahlar kullanan düşmüş melek; Lucifer'in son kapısı. | Oyuncu gibi silah kullanır | Kapı anahtarı |
| 100 | Lucifer | Tahtında, kucağında Biscuit. | Önceki mekaniklerin karışımı | — |

Yedek boss: Baal.

### Oyunda olan boss'lar

- **Moloch (10):** Boğa başlı, kızıl tenli dev; göğsünde içi yanan bir fırın, kollarında zincirler. Ağır adımlarla yürür, yakına gelince iki yumruğunu yere indirir.
- **Belphegor (20):** Tembelliğin iblis lordu. İri, kambur, kül grisi; yarı kapalı uykulu kehribar gözler, kısa kıvrık boynuzlar, kürk yakalı yıpranmış mor bir saray sabahlığı. Yanağında Biscuit'in bıraktığı üç taze pençe izi görünür (Walt'ın bulduğu iz bu). Ayak sürüyerek yürür, yakındakine tembel bir ters tokat atar. Arada durur, gözleri kızarıp titrer ve oyuncuya doğru düz bir çizgide ani bir hamle yapar; hamleden sonra yorulup bir süre soluk renkte durur (oyuncunun vurma fırsatı).

## Final (komik twist)

> Walt Lucifer'i yener. Biscuit Lucifer'in kucağından iner... ve Walt'a değil, **Lucifer'e** koşar. Walt'ın yüzü düşer.
>
> Biscuit bir an durur, geri döner, Walt'ın bacağına sürtünür; sonra dönüp Lucifer'e **tıslar**.
>
> Walt Biscuit'i kucağına alır. Son sahne: Walt evde koltukta, Biscuit kucağında uyuyor, televizyonda "şehirde açıklanamayan kükürt kokusu" haberi.

Hem yazıyla hem animasyonla anlatılacak (bkz. "Ara sahneler").

## Ara sahneler (planlı)

- **Giriş:** yukarıdaki açılış; oyun başında (ilk Play'de) oynar, geçilebilir.
- **Bitiş:** yukarıdaki final; Lucifer yenilince oynar.
- Anlatım hem yazı (kısa metin kutuları) hem animasyonla olur. Karakter görselleri (Walt, Biscuit, Lucifer) PixelLab ile hazır olacağı için ara sahne animasyonları bu görsellerden bir yapay zekâ aracıyla üretilecek.

## Bölgeler (harita)

Walt her boss'tan sonra cehennemin daha derinine iner; her boss bölümünün kendi bölgesi vardır (oynanış alanı aynı, görsel farklı).

| Dalgalar | Bölge |
|---|---|
| 1-10 | Moloch'un Kapısı: kızgın demir kapılar, fırınlar, kömür zemin |
| 11-20 | Belphegor'un Uyku Salonları: kül tepeleri, devrik tahtlar |
| 21-30 | Mammon'un Hazinesi: sikke yığınları, kasa kapıları |
| 31-40 | Beelzebub'un Bataklığı: çürük yeşil bataklık, sinek bulutları |
| 41-50 | Lilith'in Sarayı: kan kırmızısı mermer, dikenli güller |
| 51-60 | Leviathan'ın Lav Denizi: lav nehirleri, taş adalar |
| 61-70 | Asmodeus'un Bahçeleri: üç renkli saray bahçesi |
| 71-80 | Abaddon'un Uçurumu: yıkık köprüler, kırık zemin |
| 81-90 | Azazel'in Silah Dökümhanesi: kırık kılıçlar, örsler, düşmüş melek kanatları |
| 91-100 | Lucifer'in Tahtı: donmuş göl (en dipte ateş değil buz) |

## Ton ve yazım

- Karanlık atmosfer, kuru mizah.
- Walt az konuşur; boss sonrası tek cümle. Örnek: *"Two down. Still no cat."*
- Oyun içi metinler İngilizce.
