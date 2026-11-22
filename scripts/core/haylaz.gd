extends RefCounted
## Bir Haylaz (kural tarafı): konum, dayanıklılık, davranış sayaçları.
## Davranışları GameSim yürütür; görüntüsü scripts/view/haylaz_view.gd içinde.

const Balance = preload("res://scripts/data/balance.gd")

var id: int
var type: String
var data: Dictionary
var pos: Vector2
var prev_pos: Vector2
var vel: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0, 1)
var radius: float
var speed: float
var hp: int
var max_hp: int
var alive: bool = true

var spawn_left: float = Balance.HAYLAZ_SPAWN_TIME   # kardan çıkıyor (vurulamaz)
var throw_timer: float = 0.0
var strafe: float = 1.0          # atıcının yan kayma yönü (+1 / -1)
var zig: float = 0.0             # koşucunun zikzak evresi
var stun: float = 0.0            # koşucunun sersemlik süresi
var frozen: float = 0.0          # Buz Topu'yla donmuş: kıpırdamaz, atış yapmaz, üşütmez
var phase: int = -1              # Kar Kralı'nın saldırı sırası (0 halka, 1 hedefli, 2 çağırma)
var searching: bool = false      # oyuncu saklanınca: arama noktasına yürüyor
var search_pos: Vector2 = Vector2.ZERO
var stuck: float = 0.0           # engele takılı kalma süresi
var detour_dir: Vector2 = Vector2.ZERO
var detour_left: float = 0.0


func _init(p_id: int, p_type: String, p_pos: Vector2, storm: int, rng: RandomNumberGenerator) -> void:
	id = p_id
	type = p_type
	data = Balance.HAYLAZ[type]
	pos = p_pos
	prev_pos = p_pos
	radius = data["radius"]
	var base_speed: float = data["speed"]
	speed = base_speed * Balance.haylaz_speed_mul(storm)
	hp = Balance.haylaz_hp(type, storm)
	max_hp = hp
	strafe = 1.0 if rng.randf() < 0.5 else -1.0
	zig = rng.randf_range(0.0, 6.0)
	match type:
		"atici":
			throw_timer = rng.randf_range(Balance.ATICI_FIRST_THROW.x, Balance.ATICI_FIRST_THROW.y)
		"koca":
			throw_timer = rng.randf_range(Balance.KOCA_FIRST_THROW.x, Balance.KOCA_FIRST_THROW.y)
		"kral":
			throw_timer = Balance.KRAL_FIRST_ATTACK


## Vurulabilir mi (kardan çıkışı bitti ve dağılmadı).
func is_active() -> bool:
	return alive and spawn_left <= 0.0
