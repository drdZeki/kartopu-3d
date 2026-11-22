# Kartopu — Oyun Tarifi (Spec)

Çocuklar için, telefonda oynanan, 3D ve eğik üstten bakışlı bir kar oyunu.
Oyuncu bir kardan adam seçer, gelen **Haylazlar**'ı kartopuyla dağıtır, kartopu bitince haritadaki kar yığınlarından toplar. Haylazlar **fırtınalar** hâlinde gelir.

Bu dosya oyunun **ne olduğunu** anlatır. Bir kural, sayı ya da karar değiştiğinde bu dosya da aynı değişiklikte güncellenir.
Kurallar eski HTML prototipinden (`../kartopu-savasi`) alınıp yeni kararlara göre düzenlendi. Eski kod kopyalanmaz, kurallar yeniden yazılır.

---

## 0. Kimlik

| | |
|---|---|
| Oyunun adı | **Kartopu** |
| Mağaza başlığı | **Kartopu: Kar Macerası** |
| Geliştirici | **ZeSA Digital** |
| Paket adı | `com.zesadigital.kartopu` (mağazaya çıktıktan sonra değişmez) |
| Hedef yaş | 6 yaş ve üstü, ailelere uygun |
| Platform | Önce Android (Google Play, herkese açık). Mac bulunursa iOS |
| Motor | Godot 4.7 (ücretsiz, açık kaynak), GDScript |
| Ekran | Dikey |
| Diller | Türkçe ve İngilizce |

## 1. Ton ve dil (çocuk dostu)

Oyun sevimli ve neşelidir. Kimse ölmez, kimse yaralanmaz. Oyundaki tüm metinler bu sözlüğe uyar:

| Kullanılmaz | Yerine |
|---|---|
| savaş, düşman | oyun, **Haylaz** / Haylazlar |
| dalga | **Fırtına** (ekranda "FIRTINA 3", "FIRTINA DİNDİ!") |
| öldürmek, erimek, ölmek | **dağıtmak** (Haylaz vurulunca kar tanelerine dönüşüp dağılır) |
| hasar almak, can kaybetmek | **üşümek** (bir ❤️ gider) |
| boss | **Kar Kralı** |
| oyun bitti / öldün | **"Dondun!"** başlığı, alt yazı "Macera bitti" |

- Haylazların yüzü **yaramaz ve sevimli**: kömür gözler, sırıtan ağız. Kırmızı parlayan göz ya da kızgın kaş yok.
- Haylaz dağılınca: kar taneleri, şapka zıplayıp düşer, havuç yere düşer. Hiçbir zaman korkutucu değil.

## 2. Ölçüler

- Oyun 3D ama **oyun kuralları yer düzleminde (x, z) işler**. Kartopları yerden sabit bir yükseklikte uçar, yerçekimiyle düşmez. Görselde hafif yay çizebilirler. Kural aynı kalır.
- Birim **metre**. Eski prototipten çevirme: **1 m = 40 eski birim**.

## 3. Temel döngü

1. Ana menüde karakter seç → **BAŞLA**.
2. Fırtına başlar, Haylazlar haritada belirir. Belirme animasyonu 0,6 sn sürer, bu sürede vurulamazlar.
3. Kartopu at, Haylazları dağıt. Kartopu sınırlıdır: kar yığınlarının üstünden geçerek toplanır.
4. Fırtınadaki herkes dağılınca: "FIRTINA DİNDİ!", bonus puan, +1 ❤️, 3,5 sn mola, sonraki fırtına.
5. Her 5. fırtınada **Kar Kralı** gelir.
6. ❤️'ler bitince oyun biter. "Dondun!" ekranında skor, fırtına, isabet sayısı, rekor ve kazanılan para gösterilir.

## 4. Kamera ve ekran

- **Eğik üstten bakış.** Kamera oyuncunun arkasında ve yukarısındadır, 55° aşağı bakar, 20 m uzaktadır ve oyuncuyu yumuşakça takip eder. Kamera dönmez: "yukarı" her zaman haritanın kuzeyidir.
- Oyun **dikey ekranda** oynanır. Görüş açısı ekranın kısa kenarına (genişliğe) göre 36°: oyuncunun hizasında yanlarda yaklaşık **13 m** görünür. Telefon ne kadar uzun olursa olsun genişlik aynı kalır, uzun telefonlarda ileri (kuzey) daha çok görünür.
- Eğik bakış yüzünden oyuncunun önü (kuzey, ~20 m) arkasından (güney, ~10 m) daha çok görünür.
- Ekran dışındaki Haylazlar ekran kenarında okla gösterilir.
- Çentikli ekranlarda arayüz güvenli alanın içinde kalır.

## 5. Karakterler

| Ad | Hız (m/sn) | ❤️ | Kartopu kapasitesi | Güç | Kartopu hızı (m/sn) | Atış arası (sn) | Boyut | Şapka | Fiyat |
|---|---|---|---|---|---|---|---|---|---|
| Pamuk | 5,1 | 5 | 10 | 1 | 13,5 | 0,26 | 1,0 | Silindir (kırmızı atkı) | ücretsiz |
| Rüzgar | 6,9 | 3 | 9 | 1 | 14,5 | 0,18 | 0,9 | Bere (yeşil) | ücretsiz |
| Koca Buz | 4,0 | 8 | 14 | 2 | 11,25 | 0,42 | 1,2 | Kova (mor) | ücretsiz |
| Keskin | 5,25 | 4 | 6 | 2 | 20,5 | 0,32 | 1,0 | Kasket (turuncu) | ücretsiz |
| Kar Ninjası | 6,25 | 4 | 12 | 1 | 17 | 0,14 | 0,95 | Ninja bandı (mavi) | 1500 🪙 |
| Buz Şövalyesi | 4,9 | 7 | 12 | 2 | 15 | 0,30 | 1,1 | Tüylü miğfer (altın) | 2500 🪙 |

- Eski prototipte ilk karakterin adı "Kartopu" idi. Oyunun adıyla karışmasın diye adı **Pamuk** oldu.
- İngilizce adlar: Pamuk = Puff, Rüzgar = Breeze, Koca Buz = Big Chill, Keskin = Ace, Kar Ninjası = Snow Ninja, Buz Şövalyesi = Ice Knight.
- Oyuncunun gövde yarıçapı: 0,5 m × boyut. Kartopu yarıçapı: 0,16 m × boyut.
- Kartopu menzili: 14 m (her karakterde aynı).
- Üşüyünce (vurulunca) 1,1 sn dokunulmazlık.
- Kilitli karakterler menüde kilit ve fiyatla görünür. Dokununca dükkan açılır.
- Karakterlerin kimliği sabit bir kelimedir (`pamuk`, `ruzgar`…). Kayıtta sıra numarası değil bu kimlik saklanır, sıra değişse de kayıt bozulmaz.

## 6. Haylazlar

| Tür | Dayanıklılık | Yarıçap (m) | Hız (m/sn) | Puan | Davranış |
|---|---|---|---|---|---|
| Atıcı Haylaz (kırmızı bere) | 2 | 0,45 | 2,4 | 100 | Oyuncudan 5,25–8,25 m uzakta durur, yan yan kayar. 14 m içindeyse ~1,6–2,6 sn'de bir kartopu atar |
| Koşucu Haylaz (turuncu bandana) | 1 | 0,38 | 4,45 | 75 | Zikzak çizerek oyuncuya koşar. Değerse oyuncu üşür, Haylaz 1 sn sersemler |
| Koca Haylaz (koyu kova) | 6 | 0,75 | 1,55 | 250 | Yavaş yaklaşır. 15 m içindeyse 2,6–3,4 sn'de bir 3'lü yelpaze atar (±0,25 radyan, 7 m/sn, iri kartopu) |
| Kar Kralı (taç) | 30 + fırtına×4 | 1,15 | 1,8 | 1500 | Sırayla: 14'lü halka atış (6,25 m/sn) → oyuncuya 5'li atış (9,5 m/sn, 0,15 radyan aralık) → 2 Koşucu Haylaz çağırır. Saldırı arası 2,2 sn, dayanıklılığı yarının altına inince 1,5 sn. Değerse oyuncu üşür ve geri itilir |

- Haylaz kartoplarının menzili 16 m.
- Atıcı Haylazın kartopu hızı: `8 + fırtına × 0,2` m/sn, en fazla 11,5. Atış arası her fırtınada 0,05 sn kısalır, en az 0,9 sn.

Zorluk artışı:
- Haylaz hızı: fırtına başına +%3, en fazla +%40.
- Haylaz dayanıklılığı (Kar Kralı hariç): her 6 fırtınada bir ×1,5 artar (yuvarlanır).

## 7. Fırtınalar

- Normal fırtınadaki Haylaz sayısı: `3 + floor(fırtına × 1,6)`. Her biri için:
  - 3. fırtınadan itibaren `0,12 + fırtına × 0,012` ihtimalle Koca Haylaz,
  - 2. fırtınadan itibaren (kalan ihtimalle, toplam %50'ye kadar) Koşucu Haylaz,
  - geri kalanı Atıcı Haylaz.
- Kar Kralı fırtınası (5, 10, 15…): 1 Kar Kralı + `fırtına / 5 × 2` Atıcı Haylaz.
- Aynı anda sahada en fazla `6 + fırtına` Haylaz olur. Fazlası sırayla gelir.
- Haylazlar oyuncudan en az 10,75 m uzakta ve engellerin dışında belirir.
- Fırtına dinince: `fırtına × 50` bonus puan ve +1 ❤️ (en fazla başlangıç ❤️ sayısı kadar).
- Fırtına başında ekranda yazı çıkar: "FIRTINA 3" ve alt yazı olarak Haylaz sayısı. Kar Kralı fırtınasında "KAR KRALI GELİYOR! 👑".

## 8. Kartopu ekonomisi

- Haritada en fazla 7 kar yığını olur. Her yığında 3–5 kartopu vardır.
- Oyun başında oyuncunun 3,25–5,75 m çevresinde 3 yığın olur.
- Yeni yığın gelme aralığı: fırtına sırasında 2,4 sn, molada 1,2 sn. Yeni yığın oyuncudan en az 3,5 m, diğer yığınlardan en az 2,25 m uzakta ve engel dışında belirir.
- Yığının üstünden geçince kapasite dolana kadar kartopu alınır. Yığın küçülür, biterse kaybolur.
- Dağılan Haylaz, güçlendirme düşürmediyse %30 ihtimalle 2'lik küçük yığın bırakır.
- Kar Kralı dağılınca 6'lık yığın düşer.
- Kartopu 2 veya daha aza inince en yakın yığını gösteren ok çıkar. 0 olunca ekranda uyarı görünür.

## 9. Güçlendirmeler

Dağılan Haylaz %16 ihtimalle güçlendirme düşürür (Kar Kralı 2 tane). Güçlendirme yerde 12 sn kalır, son 3 sn yanıp söner.
Tek ❤️'i kalan oyuncuya düşen güçlendirme %50 ihtimalle Buz Küresi olur.

| Güçlendirme | Süre | Etki |
|---|---|---|
| 🔱 Üçlü Atış | 10 sn | Her atışta 3 kartopu (yelpaze) |
| 🧊 Buz Topu | 9 sn | Vurulan Haylaz 2,2 sn donar (Kar Kralı 0,6 sn) |
| 🔮 Buz Küresi | anında | +1 ❤️. ❤️'ler doluysa +200 puan |
| 🛡️ Kalkan | 10 sn | Üşümez, gelen kartoplarını engeller |
| 🧲 Kar Mıknatısı | 12 sn | 7 m içindeki kar yığınları oyuncuya kayar (8,5 m/sn) |
| 🌨️ Kartopu Yağmuru | 7 sn | Sınırsız kartopu, atış %40 daha seri, süre bitince kartopu dolu |

## 10. Puanlama

- Haylaz puanı × kombo çarpanı.
- Kombo: 2,6 sn içinde art arda dağıtmalar. Çarpan = `min(5, 1 + floor(kombo / 3))`. Oyuncu üşüyünce kombo sıfırlanır.
- Haylaz kartopunu havada vurmak: +10 puan.
- Fırtına bonusu: `fırtına × 50`.

## 11. Para ve dükkan

- Oyun bitince (ya da duraklatıp ana menüye dönünce) skor paraya çevrilir: **10 puan = 1 🪙** (aşağı yuvarlanır). Her oyunda bir kez eklenir.
- Para cihazda saklanır. Ana menüde bakiye ve **🛒 Dükkan** düğmesi var.
- Satın almak için fiyata **iki kez** dokunulur (ilk dokunuş "Emin misin?" sorar). Para yetmezse "Paran yetmiyor" yazar.
- Dükkanda sadece oyun içi para kullanılır. Gerçek parayla satın alma yok.
- İlk sürümde dükkanda: Kar Ninjası (1500 🪙), Buz Şövalyesi (2500 🪙).

## 12. Saklanma (karlı çalılık)

- Haritada 4 **karlı çalılık** var (yarıçap 1,1 m). Engel değildir, içinden geçilir. Birbirinden en az 9,5 m, haritanın ortasından en az 5,5 m, harita kenarından en az 3,5 m uzakta olur. Kenarları engellere en az 1 m uzaktadır.
- Çalılığın içinde duran oyuncu **gizlenir**: yarı saydam görünür, köşede "🌿 Gizlisin 7 sn" yazar.
- Gizliyken **hiçbir Haylaz (Kar Kralı dahil)** oyuncuyu göremez:
  - Hedefli atış yapmazlar.
  - Oyuncuyu kaybederler: çalıdan kendi taraflarına doğru uzaklaşıp çalıdan 12–18,75 m ötede rastgele noktalarda ararlar. Arama noktası oyuncuya en az 10,75 m uzaktadır.
  - Saklanılan çalıya giremezler, yolları oradan geçerse kenarından dolaşırlar.
  - Oyuncuya değseler bile üşütmezler.
- Kar Kralı'nın 14'lü halka atışı ve Koşucu çağırması hedefsiz olduğu için devam eder.
- Gizliyken Haylaz kartopları oyuncuyu vurmaz, içinden etkisiz geçer.
- Gizliyken kartopu atınca **1,5 sn görünür** olunur ("👀 Görüldün!"). Bu sırada oyuncu tam renkli görünür, başının üstünde 👀 rozeti ve ayağının altında yanıp sönen halka olur.
- Bir çalılıkta en fazla **10 sn** gizlenilir. Süre dolunca o çalı **10 sn** kullanılamaz (soluk görünür, üstünde ⏳ geri sayım). Çalıdan çıkınca harcanan süre yarı hızda geri dolar.

## 13. Kontroller

**Telefon (asıl hedef)**
- Sol yarı: joystick ile yürüme.
  - **Sabit mod (varsayılan):** Joystick sol altta durur. Sol yarıda neresine dokunulursa dokunulsun yön bu merkeze göre hesaplanır.
  - **Serbest mod:** Joystick parmağın değdiği yerde açılır, parmak dışarı çıkınca peşinden gelir.
  - Yarıçap ekranın kısa kenarının (dikey ekranda genişliğin) %15'i. Sabit modda merkez sol alt köşeden 1,7 yarıçap içeride.
  - Merkezde %15 ölü bölge. Joystick yarıya kadar itilince kardan adam yarı hızla yürür.
  - Mod ana menüden ve duraklatma ekranından değiştirilir.
- Sağ yarı: dokun = en yakın Haylaza otomatik nişan (hareketini hesaba katarak). 22 noktadan fazla sürükleyip bırak = o yöne atış.
- Android geri tuşu: oyundayken duraklatır, menüdeyken bir önceki ekrana döner.
- Uygulama arka plana geçince oyun kendiliğinden duraklar.

**Bilgisayar (test için)**
- WASD / ok tuşları: yürü. Fare tıkla veya basılı tut: imlece at. Boşluk: otomatik nişanlı atış. Esc / P: duraklat.
- Fare dokunmatik ekranı taklit edebilir. Böylece telefon kontrolleri de bilgisayarda denenir.
- Geliştirme tuşları (yayında kaldırılacak): 1–4 karakter değiştir, R yeni harita, J joystick modu, L dil.

## 14. Harita

- 37,5 × 37,5 m kare alan, ortası (0, 0). Kamera oyuncuyu takip eder. Oyuncu ortada başlar.
- Engeller ve çalılıklar her oyunda rastgele yerleşir.
- 20 engel. Seçim ağırlığı: 3 çam, 1 kaya, 2 kar duvarı.
  - Çam ağacı: daire, yarıçap 0,55–0,75 m.
  - Kaya: daire, yarıçap 0,45–0,65 m.
  - Kar duvarı: rastgele yönde uzanan kısa duvar. Kural tarafında "kapsül" biçimindedir: yarı uzunluk 0,65–0,85 m, kalınlık yarıçapı 0,35 m, uçları yuvarlak. Üstünde sıra sıra kartopları durur.
  - Engel merkezleri haritanın ortasından en az 4,5 m, harita kenarından en az 2,25 m uzaktadır. İki engelin kenarları arasında en az 1,75 m boşluk vardır, kardan adamlar aradan geçebilir.
- Engeller kartoplarını durdurur, arkalarına saklanılır. Engele çapraz çarpan kardan adam kenarından kayarak geçer.
- Kenarda ahşap çit, dışında süs amaçlı çam ormanı.
- **Kar zemini** (görünüş, oyunu etkilemez):
  - Yumuşak ton farkları ve rüzgârın karda bıraktığı ince dalga çizgileri.
  - Güneşte yanıp sönen küçük kar parıltıları.
  - Engellerin ve çalılıkların dibinde mavimsi gölge çukurları (nesneler yere otursun).
  - Haritanın ortasından çite doğru kıvrılarak giden 3 ezilmiş kar patikası.
  - Çit boyunca ve rüzgâr yönünde parlak kar birikintileri.
  - Gölge çukurları, patikalar ve birikintiler her harita için engellerin yerine göre yeniden çizilir.
- **Ayak izi:** Kardan adam her zıplayışında karda yuvarlak bir iz bırakır (boyut 1,0'da 0,55 m'de bir). İz 7 sn'de kaybolur, aynı anda en fazla 90 iz olur.
- Süs olarak donmuş gölcükler (kaygan değil), kuru otlar, kış çiçekleri, çakıllar, dallar.
- Ekran kenarlarında hafif mavi gölge (vinyet).
- Kar yağışı yok (telefonu yormasın diye kaldırıldı).

## 15. Görsel ve ses

- Sevimli, yumuşak, low-poly kış teması. Kardan adamlar, ağaçlar, kayalar **kodla basit 3D şekillerden** (küre, silindir, koni) yapılır. İleride hazır modellerle değiştirilebilir.
- **Çizgi film görünümü:** Işık iki tonlu (aydınlık / mavimsi gölge), karakterlerin ve engellerin çevresinde koyu lacivert kontur.
- **Kardan adamlar:** İri kafa, parıltılı iri kömür gözler, pembe yanaklar, gülümseyen ağız, havuç burun, eldivenli dal kollar, çizgili ve püsküllü atkı, karakterin şapkası (silindir şapka + çobanpüskülü, ponponlu bere, kova, kasket, ninja bandı, tüylü miğfer). Ayağının altında küçük kar birikintisi.
- **Canlı hareketler:** Dururken nefes alır, ara ara göz kırpar, kafasını hafifçe sallar, el sallar. Yürürken zıplar, yalpalar, kollarını sallar.
- **Harita:** Kar zemini (§14); katlı, karlı çamlar; yanında küçük taşı olan karlı kayalar; tuğla gibi kar bloklarından mazgallı kar kalesi duvarları; kırmızı meyveli karlı çobanpüskülü çalıları; karlı kenarlı donmuş gölcükler; kardan çıkan kuru otlar, kış çiçekleri, çakıllar, dallar.
- **Harita dışı:** Uçları sivri ahşap çit (kalın direkli, üstünde kar), çitin dibinde kar yığıntıları, dışarıda sıcak ışıklı fenerler, kuzeyde pencereleri yanan karlı kütük kulübe, odun yığınları, kırmızı kızak, çam ormanı.
- Telefon performansı: orta ve düşük seviye Android telefonlarda akıcı çalışmalı. Godot'nun en hafif görüntü ayarı (Uyumluluk / Compatibility) kullanılır. Gölgeler basit tutulur.
  - Her kardan adamın ve her engelin parçaları tek şekilde birleştirilir. Bir kardan adam ~15 çizim yapar.
  - Hedef: oyun ekranında 200'den az çizim. Şu an ~140 çizim, ~290 bin üçgen. Üçgen sayısı telefonda denenince gerekirse azaltılacak.
- Efektler: kartopu izi, yere kar lekesi, Haylaz dağılınca kar taneleri ve zıplayan şapka, üşüyünce ekran kenarında mavi buz çerçevesi, tek ❤️ kalınca nabız.
- Sesler ve müzik: ücretsiz ve serbest lisanslı (CC0) paketlerden. Hangi sesin nereden geldiği `assets/LISANSLAR.md` dosyasına yazılır.
- Titreşim destekleyen telefonlarda kısa titreşim. Ayarlardan kapatılabilir.

## 16. Diller

- Türkçe ve İngilizce. İlk açılışta telefonun diline göre seçilir: Türkçe ise Türkçe, değilse İngilizce.
- Ayarlardan değiştirilebilir.
- Ekrandaki her metin çeviri tablosundan (`i18n/texts.csv`) gelir. Koda doğrudan metin yazılmaz.

## 17. Kayıtlı veriler (cihazda)

Tek kayıt dosyası: `user://kayit.cfg`.

| Anahtar | İçerik |
|---|---|
| `best` | En iyi skor |
| `coins` | Para (🪙) |
| `char` | Son seçilen karakterin kimliği (`pamuk` gibi) |
| `owned` | Satın alınanlar (`ch_ninja`, `ch_sovalye` gibi) |
| `joy` | Joystick modu (`sabit` / `serbest`) |
| `lang` | Dil (`tr` / `en`), boşsa telefonun dili |
| `music`, `sfx`, `vibrate` | Ses, müzik ve titreşim açık mı |

## 18. Gizlilik ve aile politikası

- Kişisel veri toplanmaz. Hesap, giriş, konum, kamera, mikrofon yok.
- İnternet izni istenmez (reklam ya da online mod gelene kadar).
- Google Play "Aileler" kurallarına uyulur. Mağaza için bir gizlilik politikası sayfası yayınlanır.
- Reklam ileride konuşulacak. Konulursa sadece Google'ın aileler için onayladığı reklam sistemleri kullanılır.
- Online mod gelirse serbest sohbet olmaz, sadece hazır emojiler olur.

## 19. Sürüm planı

**İlk sürüm (1.0)**
- 4 ücretsiz karakter + dükkanda 2 karakter
- 3 tür Haylaz, fırtınalar, Kar Kralı
- Kar yığınları, 6 güçlendirme, karlı çalılıkta saklanma
- Puan, kombo, para, dükkan, rekor
- Türkçe ve İngilizce, ayarlar (ses, müzik, titreşim, joystick modu, dil)

**Sonraki güncellemeler (sıra belli değil)**
- Yardımcı **Minik** (eski prototipteki gibi)
- **Kurabiye Adam** karakteri
- Şapkalar (Noel Şapkası, Parti Külahı, Viking Miğferi, Altın Taç)
- Yeni Haylazlar (kale kuran, kartopu yuvarlayan)
- Farklı haritalar / bölümler
- Online çok oyunculu mod
- Reklam

## 20. Geliştirme adımları

Her adımın sonunda bilgisayarda denenebilir bir şey olur.

1. **Kurulum:** Godot projesi, ayarlar, iki dil altyapısı. ✅
2. **Yürüme:** Harita, kamera, kardan adam, joystick ve klavye. ✅
3. **Atış:** Kartopu atma, kar yığınları, kartopu ekonomisi, engeller.
4. **Haylazlar:** Atıcı, Koşucu, Koca Haylaz ve fırtınalar.
5. **Oyun sistemleri:** ❤️, puan, kombo, güçlendirmeler, ekran bilgileri.
6. **Ek mekanikler:** Kar Kralı, karlı çalılıkta saklanma.
7. **Menüler:** Ana menü, karakter seçimi, dükkan, ayarlar, kayıt, "Dondun!" ekranı.
8. **Efektler ve ses:** Görsel efektler, sesler, müzik, titreşim.
9. **Telefon:** Android araçları, telefonda deneme, simge, açılış ekranı.
10. **Yayın:** Gizlilik sayfası, mağaza görselleri, kapalı test, herkese açık yayın.

## 21. Kararlar

| Tarih | Karar | Neden |
|---|---|---|
| 2026-11-21 | Oyun Godot 4 ile 3D olarak sıfırdan yazılır. HTML prototipi kural laboratuvarı olarak kalır | İleride 3D ve online mod istenebilir. Ücretsiz motor |
| 2026-11-21 | Adı "Kartopu", mağazada "Kartopu: Kar Macerası" | Çocuklara hitap ediyor, "savaş" kelimesi geçmesin |
| 2026-11-21 | Geliştirici ZeSA Digital, paket `com.zesadigital.kartopu` | Kullanıcı seçimi |
| 2026-11-21 | "Dalga" yerine her yerde "Fırtına". Eski "Kar Fırtınası" güçlendirmesinin adı "Kartopu Yağmuru" | Kullanıcı seçimi. İki isim artık karışmıyor |
| 2026-11-21 | Rakiplerin adı "Haylazlar". Sevimli ve yaramaz görünürler, vurulunca dağılırlar | Çocuk dostu dil |
| 2026-11-21 | Hedef 6 yaş ve üstü, aile uyumlu. Kişisel veri yok | Google Play Aileler kuralları |
| 2026-11-21 | Eğik üstten kamera, yatay ekran (sonra dikey oldu, aşağıya bkz.) | Prototipteki kurallar (otomatik nişan, saklanma) aynen çalışsın. Telefonda iki başparmakla oynansın |
| 2026-11-21 | Görseller kodla basit 3D şekillerden. Sesler CC0 paketlerden | Ücretsiz. Kardan adam zaten kürelerden oluşuyor |
| 2026-11-21 | Türkçe ve İngilizce baştan | Herkese açık yayında daha çok oyuncuya ulaşmak |
| 2026-11-21 | İlk sürüm küçük kapsamlı (bkz. §19) | Daha erken yayına çıkmak |
| 2026-11-21 | İlk karakterin adı "Kartopu" yerine "Pamuk" | Oyunun adıyla karışmasın |
| 2026-11-21 | Test önce bilgisayarda. Telefona son aşamada geçilir | Kullanıcı seçimi |
| 2026-11-21 | Kamera açısı 55° yerine 50°, uzaklık 13 m | 55°'de kardan adamların yüzü görünmüyordu |
| 2026-11-21 | Kar duvarları kural tarafında daire değil kapsül | Uzun duvarın çevresinde görünmez bir daire olmasın, çarpışma göründüğü gibi olsun |
| 2026-11-21 | Joystick yarım itilince yarım hız | Küçük çocuklar için daha rahat kontrol |
| 2026-11-21 | Sis kapalı | Compatibility görüntü ayarında renkleri çok soldurdu |
| 2026-11-21 | Çizgi film görünümü (iki tonlu ışık + kontur), kardan adamlar ve harita baştan tasarlandı | Kullanıcı görselleri çok basit buldu |
| 2026-11-21 | Haritanın kuzeyinde kulübe, çevresinde fenerler | Kamera kuzeye baktığı için en çok orası görünüyor |
| 2026-11-21 | Farklı haritalar sonraki sürümlerde | Kullanıcı kararı |
| 2026-11-21 | Zemin özel gölgelendiriciyle baştan yapıldı: dalga izleri, parıltılar, gölge çukurları, patikalar, birikintiler; ayak izleri eklendi | Kullanıcı zemini hem görünüş hem özellik olarak beğenmedi |
| 2026-11-21 | Kamera uzaklığı 13 m → 16,5 m (görünen alan ~14,5 m → ~18 m) | Kullanıcı kamerayı çok yakın buldu |
| 2026-11-21 | Ekran yatay yerine **dikey**. Kamera 20 m uzakta, 55° eğik, görüş açısı genişliğe göre (yanlarda ~13 m) | Kullanıcı kararı |
| 2026-11-21 | Kar yağışı kaldırıldı | Kullanıcı telefonu yormasından çekindi |
| 2026-11-21 | Kar tepecikleri ve engel altındaki beyaz kar halkaları kaldırıldı | Zemine yapıştırılmış etiket gibi görünüyorlardı; gölge çukurları nesneleri zaten yere oturtuyor |

## 22. Yapılacaklar / açık sorular

- [ ] Telefonda ilk deneme: yürüme ve atış hazır olunca bir kez telefonda denemek önerildi (kontrol hissi bilgisayarda tam anlaşılmaz).
- [ ] Müzik tarzı seçilecek.
- [ ] Gizlilik politikası sayfası (GitHub Pages) hazırlanacak.
- [ ] Google Play geliştirici hesabı açılacak (bir kerelik 25 $). Yeni kişisel hesaplarda herkese açık yayından önce kapalı test şartı var (bildiğimiz kadarıyla 12 kişi, 14 gün). Hesap açılınca güncel kural kontrol edilecek.
