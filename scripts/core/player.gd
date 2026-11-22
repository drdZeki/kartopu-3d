extends RefCounted
## Oyuncunun kural tarafı: konum, hız, baktığı yön.
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


func setup(id: String) -> void:
	data = Balance.character(id)
	char_id = data["id"]
	var body_size: float = data["size"]
	radius = Balance.PLAYER_BASE_RADIUS * body_size
	speed = data["speed"]


## Bir adım ilerletir. move: joystick ya da klavyeden gelen yön (uzunluğu 0–1).
func step(dt: float, move: Vector2, world: World) -> void:
	prev_pos = pos
	var m := move.limit_length(1.0)
	velocity = m * speed
	if m.length_squared() > 0.0001:
		facing = m.normalized()
	var target := pos + velocity * dt
	pos = world.resolve_circle(target, radius)
	# engele dayanınca gerçekte gidilen hız (görüntüdeki yürüme hızı için)
	velocity = (pos - prev_pos) / dt if dt > 0.0 else Vector2.ZERO


## Görüntü için: oyuncunun şu an ne kadar hızlı yürüdüğü (0 = duruyor, 1 = tam hız).
func walk_ratio() -> float:
	return clampf(velocity.length() / speed, 0.0, 1.0) if speed > 0.0 else 0.0
