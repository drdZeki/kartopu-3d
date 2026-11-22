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


## Kimliği verilen karakterin tablosunu döndürür. Bulunamazsa ilk karakter.
static func character(id: String) -> Dictionary:
	for c: Dictionary in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]
