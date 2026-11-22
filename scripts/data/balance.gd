extends RefCounted
## Denge tabloları. Buradaki sayılar SPEC.md ile birebir aynıdır.
## Bir sayı değişirse SPEC.md de aynı değişiklikte güncellenir.
## Ölçüler metre ve saniye.

# ---------- Harita (SPEC §14) ----------
# Haritanın ortası (0, 0). Kurallar yer düzleminde işler: Vector2(x, y) = 3D'de (x, 0, z).
const MAP_SIZE: float = 37.5
const OBSTACLE_COUNT: int = 20
const OBSTACLE_TRIES: int = 600
const OBSTACLE_EDGE_MARGIN: float = 2.25   # engel merkezinin harita kenarına en yakın mesafesi
const OBSTACLE_CENTER_CLEAR: float = 4.5   # haritanın ortasında engelsiz kalan yarıçap
const OBSTACLE_GAP: float = 1.75           # iki engelin kenarları arasındaki en az boşluk
const OBSTACLE_KINDS := ["tree", "tree", "tree", "rock", "wall", "wall"]  # ağırlıklı seçim
const TREE_RADIUS := Vector2(0.55, 0.75)   # (en az, en çok)
const ROCK_RADIUS := Vector2(0.45, 0.65)
const WALL_HALF_LENGTH := Vector2(0.65, 0.85)
const WALL_THICKNESS: float = 0.35         # kar duvarının yarı kalınlığı

# ---------- Karlı çalılık (SPEC §12) ----------
const BUSH_COUNT: int = 4
const BUSH_TRIES: int = 800
const BUSH_RADIUS: float = 1.1
const BUSH_EDGE_MARGIN: float = 3.5
const BUSH_GAP: float = 9.5                # iki çalılık merkezi arası en az
const BUSH_CENTER_CLEAR: float = 5.5
const BUSH_OBSTACLE_GAP: float = 1.0       # çalılık kenarı ile engel kenarı arası en az

# ---------- Oyuncu (SPEC §5) ----------
const PLAYER_BASE_RADIUS: float = 0.5      # boyut 1,0 olan kardan adamın gövde yarıçapı

# ---------- Kartopu ve atış (SPEC §5, §13) ----------
const BALL_RANGE: float = 14.0             # her karakterde aynı
const BALL_BASE_RADIUS: float = 0.16       # boyut 1,0 olan karakterin kartopu yarıçapı
const THROW_FACE_TIME: float = 0.35        # atıştan sonra kardan adam bu kadar sn atış yönüne bakar
const AUTO_AIM_RANGE: float = 11.0         # otomatik nişanın hedef arayacağı uzaklık (dikey ekranda görünenlere yakın)
const THROW_DRAG_RATIO: float = 0.05       # bu kadar (ekranın kısa kenarı × oran) sürükleme = yönlü atış
const THROW_HOLD_TIME: float = 0.25        # bu kadar sn basılı tutunca seri atış başlar
const THROW_BUFFER: float = 0.3            # bekleme süresi dolmadan yapılan atış isteği bu kadar sn bekletilir

# ---------- Kar yığınları (SPEC §8) ----------
const PILE_MAX: int = 7
const PILE_AMOUNT := Vector2i(3, 5)        # yeni yığındaki kartopu (en az, en çok)
const PILE_INTERVAL: float = 2.4           # yeni yığın gelme aralığı, fırtına sırasında (sn)
const PILE_BREAK_INTERVAL: float = 1.2     # molada daha sık gelir
const PILE_INITIAL: int = 3
const PILE_INITIAL_DIST := Vector2(3.25, 5.75)
const PILE_MIN_DIST_PLAYER: float = 3.5
const PILE_MIN_GAP: float = 2.25
const PILE_EDGE_MARGIN: float = 1.25
const PILE_TRIES: int = 30
const PILE_PICKUP_FACTOR: float = 0.8      # oyuncu yığının yarıçapının bu kadarına değince toplar
const LOW_AMMO: int = 2                    # bu kadar ya da azsa en yakın yığını gösteren ok çıkar

# ---------- Oyuncunun canı (SPEC §3, §5) ----------
const INVULNERABLE_TIME: float = 1.1       # üşüdükten sonra dokunulmazlık (sn)
const PLAYER_HIT_FACTOR: float = 1.05      # Haylaz kartopu oyuncu yarıçapı × bu + kartopu yarıçapında çarpar

# ---------- Haylazlar (SPEC §6) ----------
# hp: dayanıklılık, radius: gövde yarıçapı (m), speed: m/sn, points: puan (5. adımda kullanılacak)
# color: bere / bandana / kova rengi, hat: şapka türü (görüntü için)
const HAYLAZ := {
	"atici": { "name": "HAYLAZ_ATICI", "hp": 2, "radius": 0.45, "speed": 2.4, "points": 100,
		"color": Color(0.86, 0.20, 0.24), "hat": "beanie" },
	"kosucu": { "name": "HAYLAZ_KOSUCU", "hp": 1, "radius": 0.38, "speed": 4.45, "points": 75,
		"color": Color(1.0, 0.48, 0.10), "hat": "bandana" },
	"koca": { "name": "HAYLAZ_KOCA", "hp": 6, "radius": 0.75, "speed": 1.55, "points": 250,
		"color": Color(0.28, 0.31, 0.42), "hat": "bucket" },   # koyu kova (Koca Buz'un mor kovasıyla karışmasın)
	"kral": { "name": "HAYLAZ_KRAL", "hp": 30, "radius": 1.15, "speed": 1.8, "points": 1500,
		"color": Color(0.52, 0.22, 0.72), "hat": "crown" },   # Kar Kralı: taç, mor pelerin
}
const HAYLAZ_SPAWN_TIME: float = 0.6       # kardan çıkma; bu sürede vurulamaz, hareket etmez
const HAYLAZ_SPAWN_MIN_DIST: float = 10.75 # oyuncuya en az bu kadar uzakta belirir
const HAYLAZ_SPAWN_TRIES: int = 40
const HAYLAZ_HIT_FACTOR: float = 1.15      # kartopu Haylaz yarıçapı × bu + kartopu yarıçapında çarpar
const HAYLAZ_KNOCKBACK := { "atici": 0.4, "kosucu": 0.4, "koca": 0.2, "kral": 0.1 }   # vurulunca geri itilme (m)
const HAYLAZ_CONTACT_MARGIN: float = 0.05  # koşucunun oyuncuya değme payı
const HAYLAZ_STUCK_TIME: float = 0.35      # engele takılıp bu kadar ilerleyemezse yan yoldan dolaşır
const HAYLAZ_DETOUR_TIME: float = 0.7

const ENEMY_BALL_RADIUS: float = 0.175
const ENEMY_BALL_RANGE: float = 16.0

# Atıcı: uzakta durur, yan yan kayar, kartopu atar
# Dikey ekranda yanlarda ~±6,5 m görünür: atıcılar ekranın içinde kalsın diye prototipteki
# 5,25–8,25 m yerine 3,5–5,5 m.
const ATICI_NEAR: float = 3.5              # bundan yakınsa geri çekilir
const ATICI_FAR: float = 5.5               # bundan uzaksa yaklaşır
const ATICI_STRAFE: float = 0.7            # yan kayma hızı (tam hızın oranı)
const ATICI_FLIP_RATE: float = 0.4         # yan kayma yönünü saniyede bu olasılıkla değiştirir
const ATICI_THROW_RANGE: float = 14.0
const ATICI_SPREAD: float = 0.12           # nişan sapması (± radyan)
const ATICI_BALL_SPEED := Vector3(8.0, 0.2, 11.5)    # (başlangıç, fırtına başına artış, en fazla)
const ATICI_INTERVAL := Vector2(1.6, 2.6)  # atış arası (sn)
const ATICI_INTERVAL_DROP: float = 0.05    # her fırtınada atış arası bu kadar kısalır
const ATICI_INTERVAL_MIN: float = 0.9
const ATICI_FIRST_THROW := Vector2(1.0, 2.2)

# Koşucu: zikzakla üstüne koşar, değerse üşütür ve sersemler
const KOSUCU_ZIG_FREQ: float = 6.0
const KOSUCU_ZIG: float = 0.5
const KOSUCU_STUN: float = 1.0
const KOSUCU_BOUNCE: float = 0.75          # değince geri sekme (m)
const KOSUCU_STUN_SPEED: float = 0.6

# Koca: yavaş yaklaşır, 3'lü yelpaze atar
const KOCA_NEAR: float = 5.0               # bundan uzaksa yaklaşır (dikey ekran için 7 m yerine)
const KOCA_THROW_RANGE: float = 15.0
const KOCA_FAN: float = 0.25               # yelpazenin yan kartoplarının açısı (radyan)
const KOCA_BALL_SPEED: float = 7.0
const KOCA_BALL_RADIUS: float = 0.275
const KOCA_INTERVAL := Vector2(2.6, 3.4)
const KOCA_FIRST_THROW := Vector2(1.5, 2.5)

# Kar Kralı (SPEC §6): her 5. fırtınada gelir
const KRAL_EVERY: int = 5
const KRAL_HP_PER_STORM: int = 4           # dayanıklılık = 30 + fırtına × 4
const KRAL_NEAR: float = 4.5               # dikey ekran için prototipteki 5,75 m yerine
const KRAL_FAR: float = 6.5                # prototipte 8,5 m
const KRAL_FLIP_RATE: float = 0.25
const KRAL_FIRST_ATTACK: float = 2.0
const KRAL_INTERVAL: float = 2.2           # saldırı arası
const KRAL_INTERVAL_ANGRY: float = 1.5     # dayanıklılığı yarının altına inince
const KRAL_RING: int = 14                  # halka atış: 14 kartopu her yöne
const KRAL_RING_SPEED: float = 6.25
const KRAL_RING_RADIUS: float = 0.225
const KRAL_AIMED: int = 5                  # oyuncuya 5'li atış
const KRAL_AIMED_SPREAD: float = 0.15
const KRAL_AIMED_SPEED: float = 9.5
const KRAL_AIMED_RADIUS: float = 0.2
const KRAL_SUMMON: int = 2                 # 2 koşucu çağırır
const KRAL_SUMMON_SPREAD: float = 1.75
const KRAL_SUMMON_MAX: int = 14            # sahada bundan çok Haylaz varsa çağırmaz
const KRAL_PUSH: float = 1.0               # değince oyuncuyu bu kadar iter
const KRAL_FREEZE_TIME: float = 0.6        # Buz Topu Kar Kralı'nı daha kısa dondurur
const KRAL_POWER_DROPS: int = 2
const KRAL_PILE: int = 6

# ---------- Çalılıkta saklanma (SPEC §12) ----------
const HIDE_MAX: float = 10.0               # bir çalılıkta en fazla gizlenme süresi
const HIDE_COOL: float = 10.0              # süre dolunca çalı bu kadar kullanılamaz
const HIDE_REVEAL: float = 1.5             # gizliyken atış yapınca bu kadar görünür olur
const HIDE_RECOVER: float = 0.5            # çalıdan çıkınca harcanan süre yarı hızda geri dolar
const HIDE_SEARCH_DIST := Vector2(12.0, 18.75)   # Haylazlar çalıdan bu kadar ötede arar
const HIDE_SEARCH_MIN_PLAYER: float = 10.75
const HIDE_SEARCH_REACHED: float = 1.0
const HIDE_BUSH_MARGIN: float = 0.15       # Haylazlar saklanılan çalıya bu paydan fazla yaklaşamaz

# ---------- Puan ve kombo (SPEC §10) ----------
const COMBO_WINDOW: float = 2.6            # bu süre içinde art arda dağıtmalar komboyu büyütür
const COMBO_STEP: int = 3                  # her 3 dağıtmada çarpan 1 artar
const COMBO_MAX: int = 5
const CLASH_POINTS: int = 10               # havada Haylaz kartopunu vurmak
const STORM_BONUS: int = 50                # fırtına dinince fırtına × bu kadar
const ORB_FULL_POINTS: int = 200           # kalpler doluyken Buz Küresi

# ---------- Güçlendirmeler (SPEC §9) ----------
# time: süre (sn), 0 = anında. color: simgenin rengi. name: çeviri anahtarı.
const POWERS := {
	"uclu": { "name": "PW_UCLU", "time": 10.0, "color": Color(1.0, 0.82, 0.25) },
	"buz": { "name": "PW_BUZ", "time": 9.0, "color": Color(0.45, 0.80, 1.0) },
	"kure": { "name": "PW_KURE", "time": 0.0, "color": Color(1.0, 0.42, 0.62) },
	"kalkan": { "name": "PW_KALKAN", "time": 10.0, "color": Color(0.42, 0.52, 1.0) },
	"miknatis": { "name": "PW_MIKNATIS", "time": 12.0, "color": Color(0.95, 0.28, 0.35) },
	"yagmur": { "name": "PW_YAGMUR", "time": 7.0, "color": Color(0.72, 0.48, 1.0) },
}
const POWER_ORDER := ["uclu", "buz", "kure", "kalkan", "miknatis", "yagmur"]
const POWER_DROP_CHANCE: float = 0.16      # dağılan Haylaz bu ihtimalle güçlendirme düşürür
const SMALL_PILE_CHANCE: float = 0.3       # düşürmediyse bu ihtimalle 2'lik küçük yığın
const SMALL_PILE_AMOUNT: int = 2
const POWER_LIFE: float = 12.0             # yerde kalma süresi
const POWER_BLINK: float = 3.0             # son bu kadar sn yanıp söner
const POWER_PICKUP: float = 0.5            # oyuncu yarıçapı + bu kadar mesafede alınır
const LOW_HEART_ORB_CHANCE: float = 0.5    # tek kalp kalmışsa düşen güçlendirme bu ihtimalle Buz Küresi
const TRIPLE_ANGLE: float = 0.2            # üçlü atışta yan kartopların açısı (radyan)
const FREEZE_TIME: float = 2.2             # Buz Topu'yla vurulan Haylaz donar
const SHIELD_FACTOR: float = 1.9           # kalkan, oyuncu yarıçapı × bu kadar uzaktaki kartoplarını durdurur
const MAGNET_RANGE: float = 7.0
const MAGNET_SPEED: float = 8.5
const RAIN_COOLDOWN_MUL: float = 0.6       # Kartopu Yağmuru: atış arası %40 kısa

# ---------- Fırtınalar (SPEC §7) ----------
const STORM_FIRST_BREAK: float = 1.3       # oyun başında ilk fırtınaya kadar
const STORM_BREAK: float = 3.5             # iki fırtına arası mola
const STORM_SPAWN_INTERVAL := Vector3(1.1, 0.05, 0.35)  # (başlangıç, fırtına başına azalma, en az)
const STORM_MAX_ALIVE_BASE: int = 6        # aynı anda en fazla 6 + fırtına Haylaz
const STORM_SPEED_STEP: float = 0.03       # Haylaz hızı fırtına başına +%3
const STORM_SPEED_MAX: float = 0.4         # en fazla +%40
const STORM_HP_EVERY: int = 6              # her 6 fırtınada bir dayanıklılık ×1,5
const STORM_HP_MUL: float = 0.5


## Fırtınadaki Haylaz sayısı (Kar Kralı fırtınaları 6. adımda).
static func storm_count(storm: int) -> int:
	return 3 + int(floorf(storm * 1.6))


## Fırtınaya göre Haylaz hız çarpanı ve dayanıklılığı.
static func haylaz_speed_mul(storm: int) -> float:
	return 1.0 + minf(STORM_SPEED_MAX, storm * STORM_SPEED_STEP)


static func haylaz_hp(type: String, storm: int) -> int:
	var base: int = HAYLAZ[type]["hp"]
	if type == "kral":
		return base + storm * KRAL_HP_PER_STORM
	var mul := 1.0 + floorf((storm - 1) / float(STORM_HP_EVERY)) * STORM_HP_MUL
	return int(round(base * mul))

# ---------- Kontroller (SPEC §13) ----------
const JOY_RADIUS_RATIO: float = 0.15       # joystick yarıçapı = ekranın kısa kenarı × bu oran
const JOY_DEADZONE: float = 0.15           # merkezdeki ölü bölge (yarıçapın oranı)

# ---------- Karakterler (SPEC §5) ----------
# id: kayıtta saklanan sabit kimlik. name: çeviri anahtarı (i18n/texts.csv).
# Yeni karakterler listenin sonuna eklenir.
const CHARACTERS := [
	{ "id": "pamuk", "name": "CHAR_PAMUK", "speed": 5.1, "hearts": 5, "capacity": 10, "power": 1,
		"ball_speed": 13.5, "cooldown": 0.26, "size": 1.0, "hat": "top",
		"color": Color(0.902, 0.224, 0.275), "price": 0 },
	{ "id": "ruzgar", "name": "CHAR_RUZGAR", "speed": 6.9, "hearts": 3, "capacity": 9, "power": 1,
		"ball_speed": 14.5, "cooldown": 0.18, "size": 0.9, "hat": "beanie",
		"color": Color(0.165, 0.616, 0.561), "price": 0 },
	{ "id": "kocabuz", "name": "CHAR_KOCABUZ", "speed": 4.0, "hearts": 8, "capacity": 14, "power": 2,
		"ball_speed": 11.25, "cooldown": 0.42, "size": 1.2, "hat": "bucket",
		"color": Color(0.416, 0.298, 0.576), "price": 0 },
	{ "id": "keskin", "name": "CHAR_KESKIN", "speed": 5.25, "hearts": 4, "capacity": 6, "power": 2,
		"ball_speed": 20.5, "cooldown": 0.32, "size": 1.0, "hat": "cap",
		"color": Color(0.957, 0.635, 0.380), "price": 0 },
	{ "id": "ninja", "name": "CHAR_NINJA", "speed": 6.25, "hearts": 4, "capacity": 12, "power": 1,
		"ball_speed": 17.0, "cooldown": 0.14, "size": 0.95, "hat": "ninja",
		"color": Color(0.067, 0.541, 0.698), "price": 1500 },
	{ "id": "sovalye", "name": "CHAR_SOVALYE", "speed": 4.9, "hearts": 7, "capacity": 12, "power": 2,
		"ball_speed": 15.0, "cooldown": 0.30, "size": 1.1, "hat": "helmet",
		"color": Color(1.0, 0.718, 0.012), "price": 2500 },
]


## Kar yığınının yarıçapı (m): içindeki kartopu sayısına göre büyür.
static func pile_radius(amount: int) -> float:
	return (10.0 + amount * 3.0) / 40.0


## Kimliği verilen karakterin tablosunu döndürür. Bulunamazsa ilk karakter.
static func character(id: String) -> Dictionary:
	for c: Dictionary in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]
