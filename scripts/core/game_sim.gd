extends RefCounted
## Oyunun tüm kural durumu ve adım adım ilerleyişi.
## Görüntüden bağımsızdır: aynı kod ileride online modda sunucuda da çalışabilsin.
## Sabit adımla (saniyede 60 kez) ilerletilir.

const World = preload("res://scripts/core/world.gd")
const Player = preload("res://scripts/core/player.gd")

var world: World
var player: Player
var time: float = 0.0


func new_game(p_seed: int, char_id: String) -> void:
	time = 0.0
	world = World.new()
	world.generate(p_seed)
	player = Player.new()
	player.setup(char_id)
	player.pos = Vector2.ZERO
	player.prev_pos = Vector2.ZERO


## Oyuncuyu olduğu yerde başka bir karaktere çevirir (geliştirme sırasında deneme için).
func change_character(char_id: String) -> void:
	var p := player.pos
	var f := player.facing
	player.setup(char_id)
	player.pos = world.resolve_circle(p, player.radius)
	player.prev_pos = player.pos
	player.facing = f


func step(dt: float, move: Vector2) -> void:
	time += dt
	player.step(dt, move, world)
