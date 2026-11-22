extends RefCounted
## Oyuncunun kural tarafı: konum, hız, baktığı yön, kartopu sayısı, atış bekleme süresi.
## Görüntüden bağımsızdır; kardan adamın çizimi scripts/view/snowman_view.gd içinde.

const Balance = preload("res://scripts/data/balance.gd")
const World = preload("res://scripts/core/world.gd")

var data: Dictionary = {}          # karakter tablosu (Balance.CHARACTERS içinden)
var char_id: String = ""
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO  # bir önceki adımdaki konum (görüntü arayı yumuşatır)
var radius: float = Balance.PLAYER_BASE_RADIUS
var speed: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0.0, 1.0)  # başta kameraya (güneye) bakar

var ammo: int = 0                  # elindeki kartopu
var capacity: int = 0              # en fazla taşıyabileceği kartopu
var power: int = 1
var ball_speed: float = 0.0
var ball_radius: float = Balance.BALL_BASE_RADIUS
var cooldown: float = 0.0          # iki atış arası (sn)
var cooldown_left: float = 0.0
var face_lock: float = 0.0         # atıştan sonra atış yönüne bakma süresi

var hearts: int = 0                # ❤️ (can)
var max_hearts: int = 0
var invulnerable: float = 0.0      # üşüdükten sonraki dokunulmazlık süresi
var powers: Dictionary = {}        # etkin güçlendirme -> kalan süre (sn)
var reveal: float = 0.0            # çalılıktayken atış yapınca görünür kalma süresi


func has_power(type: String) -> bool:
	return powers.get(type, 0.0) > 0.0


## Kartopu Yağmuru sırasında kartopu sınırsız.
func unlimited() -> bool:
	return has_power("yagmur")


func setup(id: String) -> void:
	data = Balance.character(id)
	char_id = data["id"]
	var body_size: float = data["size"]
	radius = Balance.PLAYER_BASE_RADIUS * body_size
	ball_radius = Balance.BALL_BASE_RADIUS * body_size
	speed = data["speed"]
	capacity = data["capacity"]
	ammo = capacity
	power = data["power"]
	ball_speed = data["ball_speed"]
	cooldown = data["cooldown"]
	cooldown_left = 0.0
	max_hearts = data["hearts"]
	hearts = max_hearts
	invulnerable = 0.0
	powers = {}
	reveal = 0.0


## Bir adım ilerletir. move: joystick ya da klavyeden gelen yön (uzunluğu 0–1).
func step(dt: float, move: Vector2, world: World) -> void:
	prev_pos = pos
	cooldown_left = maxf(0.0, cooldown_left - dt)
	face_lock = maxf(0.0, face_lock - dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	reveal = maxf(0.0, reveal - dt)
	var m := move.limit_length(1.0)
	velocity = m * speed
	if m.length_squared() > 0.0001 and face_lock <= 0.0:
		facing = m.normalized()
	var target := pos + velocity * dt
	pos = world.resolve_circle(target, radius)
	# engele dayanınca gerçekte gidilen hız (görüntüdeki yürüme hızı için)
	velocity = (pos - prev_pos) / dt if dt > 0.0 else Vector2.ZERO


func ready_to_throw() -> bool:
	return cooldown_left <= 0.0


## Atışın kurallarını uygular (kartopu azalır, bekleme başlar, atış yönüne döner).
## Kartopunun kendisini GameSim oluşturur.
func on_throw(dir: Vector2) -> void:
	if not unlimited():
		ammo -= 1
	cooldown_left = cooldown * (Balance.RAIN_COOLDOWN_MUL if unlimited() else 1.0)
	facing = dir
	face_lock = Balance.THROW_FACE_TIME
	reveal = Balance.HIDE_REVEAL


## Görüntü için: oyuncunun şu an ne kadar hızlı yürüdüğü (0 = duruyor, 1 = tam hız).
func walk_ratio() -> float:
	return clampf(velocity.length() / speed, 0.0, 1.0) if speed > 0.0 else 0.0
