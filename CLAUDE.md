# Kartopu — Çalışma Notları

Çocuklar için, Godot 4 ile yapılan 3D kar oyunu. Önce Android (Google Play), sonra iOS.
Oyunun kuralları, sayıları ve kararları **[SPEC.md](SPEC.md)** içinde. Oyunla ilgili bir işe başlamadan önce onu oku.

Eski HTML prototipi `../kartopu-savasi` klasöründe. O klasör bu projeden bağımsızdır, oraya dokunma. Kuralları anlamak için okunabilir, ama kodu kopyalanmaz. Kurallar Godot'da yeniden yazılır.

## Kullanıcıyla çalışma

- Kullanıcıyla Türkçe konuş, teknik adımları sade anlat. Kodlamanın tamamı sende. Kullanıcı Godot'da çalıştırıp dener.
- Yeni bir işe başlamadan önce planı ve açık soruları kullanıcıyla netleştir. Kullanıcı "başla" demeden dosya oluşturma ya da kurulum yapma.
- İndirme ve kurulumları (Godot, Android araçları) kullanıcı kendisi yapar. Sen adım adım anlatırsın.

## Klasörler

- `project.godot` — Godot proje ayarları (dikey ekran 720×1280, bilgisayarda pencere 450×800, hafif görüntü ayarı, diller). Kullanıcının Godot düzenleyicisi açıkken bu dosya elle değiştirilirse düzenleyici eski hâliyle üstüne yazabilir. Değiştirdikten sonra kullanıcıdan "Proje → Projeyi Yeniden Yükle" yapmasını iste.
- `scenes/` — Godot sahneleri (`.tscn`).
- `scripts/core/` — **oyun kuralları**. Görüntüden bağımsızdır: hareket, çarpışma, atış, fırtınalar, puan. Bu klasördeki kod 3D düğümlere, kameraya, sese dokunmaz.
- `scripts/data/` — denge tabloları: karakterler, Haylazlar, güçlendirmeler, fiyatlar. Sayılar SPEC.md ile birebir aynı olur.
- `scripts/view/` — 3D görüntü: kardan adamlar, harita, efektler, kamera. Kurallardaki durumu okuyup çizer.
- `scripts/ui/` — menüler ve oyun içi ekran bilgileri.
- `i18n/texts.csv` — tüm ekran metinleri (Türkçe ve İngilizce). Godot bunu çeviri dosyalarına kendisi çevirir.
- `assets/` — ses, müzik, yazı tipi. Her dış dosyanın kaynağı ve lisansı `assets/LISANSLAR.md`'ye yazılır.
- `tests/` — görüntüsüz çalışan kural testleri.

## Kurallar

- **Oyun mantığı görüntüden ayrı.** `scripts/core/` 2D'den 3D'ye ya da online moda geçişte aynen kalabilecek şekilde yazılır. Kurallar yer düzleminde (`Vector2`, x ve z) işler. Görüntü bunu 3D'ye çevirir.
- **Denge sayıları sadece `scripts/data/` içinde.** Kodun başka yerine sayı gömülmez.
- **Ekrandaki her metin `i18n/texts.csv`'den** (`tr("ANAHTAR")`). Koda doğrudan Türkçe ya da İngilizce metin yazılmaz. Yeni metin eklenince iki dil birden yazılır.
- **Çocuk dostu dil:** SPEC.md §1'deki sözlüğe uy. "Savaş", "düşman", "öldürmek", "dalga" yok. Fırtına, Haylaz, dağıtmak, üşümek var.
- **Kod dili:** Değişken, fonksiyon ve dosya adları İngilizce (`storm`, `haylaz` gibi oyuna özel kelimeler hariç), yorumlar Türkçe. GDScript'te tip belirt (`var hiz: float`).
- **Kayıt** tek yerden yapılır (`user://kayit.cfg`). Anahtarlar SPEC.md §17'de.
- **Performans:** Orta ve düşük seviye telefonlar hedef. Görüntü ayarı "Compatibility". Gölge, ışık ve parçacık sayısını düşük tut.
- **Kişisel veri yok, internet izni yok** (SPEC.md §18). Yeni bir izin, eklenti ya da kütüphane eklemeden önce kullanıcıya sor.
- Oyun kuralı, denge sayısı veya kontrol değişirse SPEC.md'yi aynı değişiklikte güncelle. Yeni bir karar varsa "Kararlar" tablosuna tarihiyle ekle. Biten geliştirme adımını SPEC.md §20'de ✅ ile işaretle.

## Çalıştırma ve test

- Kullanıcı Godot düzenleyicisinde projeyi açar, **F5** (ya da sağ üstteki ▶) ile çalıştırır.
- Fare dokunmatik ekranı taklit eder (`emulate_touch_from_mouse`), telefon kontrolleri bilgisayarda denenebilir.
- Godot sürümü **4.7.2** (standart, .NET değil). Yeri: `C:\Godot\`. Konsol çıktısı veren sürüm: `C:\Godot\Godot_v4.7.2-stable_win64_console.exe`.
- Görüntüsüz kontrol (her değişiklikten sonra): `& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --quit-after 120` — ana sahneyi 120 kare çalıştırır, hata varsa yazar. Kural testleri `tests/` içinde, `--script` ile çalıştırılır.
- Türkçe çıktı bozuk görünürse PowerShell'de önce `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`.
- Kural testleri: `& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/test_core.gd`. Sonda "SONUÇ: BAŞARILI" yazmalı.
- Yeni bir `.gd` ya da metin dosyası eklenince önce `--headless --path . --import` çalıştır (Godot dosyaları tanısın).
- Görüntüyü kontrol etmek için: `tools/screenshot.gd` oyunu kısa bir an pencerede açar, duruyor / klavyeyle yürüyor / joystick'le yürüyor olmak üzere 3 ekran görüntüsü kaydeder (kullanım dosyanın başında). Görsel her değişiklikten sonra görüntüye bakarak kontrol et.
- Karakterlerin ve haritanın yakın planı için `tools/showcase.gd`: tüm karakterleri yan yana dizer, yakın / oyun kamerası / harita kenarı olmak üzere 3 görüntü alır ve çizim ile üçgen sayısını yazar. Görsel bir değişiklikten sonra ikisini de çalıştır, görüntülere bak.
- Görsel kurallar (`scripts/view/mesh_kit.gd`):
  - Malzemeler çizgi film tarzı (`DIFFUSE_TOON`). Kontur için parçaları eklemeden önce `Kit.outline = kalınlık`, bitince `Kit.outline = 0.0`.
  - Bir nesnenin parçaları eklendikten sonra `Kit.bake(düğüm, [hareket eden alt düğümler])` ile tek şekle birleştir. Birleştirmeden çok sayıda parça bırakma (telefon yavaşlar).
  - Çok tekrar eden şeyler (çit tahtası, orman ağacı) `Kit.multi` ile.
- Bilinen tuzaklar:
  - Sis (fog) Compatibility ayarında renkleri çok soldurur, kapalı tutuluyor.
  - MultiMesh'te eşit olmayan ölçek (yassı küre gibi) ışığı bozar. Yassı şekilleri tek tek `Kit.part` ile ekle.
  - Beyaz zemin kolayca bembeyaz olur. Güneş + ortam ışığı toplamı 1'in üstünde. Kar zemini gölgelendiricisi (`shaders/snow_ground.gdshader`) rengi `light_comp` ile çarpar. Bu sayı büyürse zemin bembeyaz patlar, mavimsi tonlar camgöbeğine döner. Küçülürse zemin griye kaçar. 0,84 iyi.
  - Zemin maskesi (`scripts/view/ground_mask.gd`) her yeni haritada GDScript ile çizilir (256×256). Büyütmeden önce yükleme süresini ölç.
- Telefon testi son aşamada (SPEC.md §20, adım 9).

## Git

- Bu klasörün kendi git deposu var. Uzak depo (GitHub) henüz bağlanmadı. Kullanıcı GitHub ayarlarını Visual Studio'dan yapar. `gh` kurulu değil.
- Commit'i sadece kullanıcı isteyince yap.
- GitHub'a sadece kullanıcı "gönder" (veya "push et") dediğinde gönder. O zaman ayrıca onay sorma. Kendiliğinden gönderme, göndermeyi teklif edip sorma.
- **İmza anahtarları (`.keystore`, `.jks`) ve şifreler asla depoya girmez.**
