extends RefCounted
## Harita kuralları: engellerin ve çalılıkların yerleşimi, çarpışma.
## Görüntüden bağımsızdır; 3D düğümlere dokunmaz.

const Balance = preload("res://scripts/data/balance.gd")
const Obstacle = preload("res://scripts/core/obstacle.gd")
const Bush = preload("res://scripts/core/bush.gd")

var size: float = Balance.MAP_SIZE
var half: float = Balance.MAP_SIZE * 0.5
var seed_value: int = 0
var obstacles: Array = []   # Obstacle listesi
var bushes: Array = []      # Bush listesi


## Aynı tohum (seed) her zaman aynı haritayı üretir.
func generate(p_seed: int) -> void:
	seed_value = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	obstacles = _generate_obstacles(rng)
	bushes = _generate_bushes(rng)


# ---------- Yerleşim ----------

func _generate_obstacles(rng: RandomNumberGenerator) -> Array:
	var list: Array = []
	var limit := half - Balance.OBSTACLE_EDGE_MARGIN
	var tries := 0
	while list.size() < Balance.OBSTACLE_COUNT and tries < Balance.OBSTACLE_TRIES:
		tries += 1
		var kind: String = Balance.OBSTACLE_KINDS[rng.randi_range(0, Balance.OBSTACLE_KINDS.size() - 1)]
		var c := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		if c.length() < Balance.OBSTACLE_CENTER_CLEAR:
			continue
		var ob := _make_obstacle(kind, c, rng)
		var fits := true
		for other: Obstacle in list:
			if c.distance_to(other.center()) < other.bound_radius() + ob.bound_radius() + Balance.OBSTACLE_GAP:
				fits = false
				break
		if fits:
			list.append(ob)
	return list


func _make_obstacle(kind: String, c: Vector2, rng: RandomNumberGenerator) -> Obstacle:
	match kind:
		"tree":
			return Obstacle.new(kind, c, c, rng.randf_range(Balance.TREE_RADIUS.x, Balance.TREE_RADIUS.y))
		"rock":
			return Obstacle.new(kind, c, c, rng.randf_range(Balance.ROCK_RADIUS.x, Balance.ROCK_RADIUS.y))
		_:
			# kar duvarı: rastgele yönde uzanan kısa bir duvar
			var half_len := rng.randf_range(Balance.WALL_HALF_LENGTH.x, Balance.WALL_HALF_LENGTH.y)
			var dir := Vector2.RIGHT.rotated(rng.randf_range(0.0, PI))
			return Obstacle.new("wall", c - dir * half_len, c + dir * half_len, Balance.WALL_THICKNESS)


func _generate_bushes(rng: RandomNumberGenerator) -> Array:
	var list: Array = []
	var limit := half - Balance.BUSH_EDGE_MARGIN
	var tries := 0
	while list.size() < Balance.BUSH_COUNT and tries < Balance.BUSH_TRIES:
		tries += 1
		var p := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		if p.length() < Balance.BUSH_CENTER_CLEAR:
			continue
		var fits := true
		for other: Bush in list:
			if p.distance_to(other.pos) < Balance.BUSH_GAP:
				fits = false
				break
		if fits:
			for ob: Obstacle in obstacles:
				if ob.edge_distance(p) < Balance.BUSH_RADIUS + Balance.BUSH_OBSTACLE_GAP:
					fits = false
					break
		if fits:
			list.append(Bush.new(p, Balance.BUSH_RADIUS))
	return list


# ---------- Çarpışma ----------

## r yarıçaplı bir daireyi engellerin ve çitin dışına iter.
## Engele çapraz çarpan, kenarından kayarak geçer.
func resolve_circle(pos: Vector2, r: float) -> Vector2:
	var p := pos
	for _pass in 3:
		var moved := false
		for ob: Obstacle in obstacles:
			var cp := ob.closest_point(p)
			var d := p - cp
			var min_dist := ob.radius + r
			var dist_sq := d.length_squared()
			if dist_sq < min_dist * min_dist:
				var dist := sqrt(dist_sq)
				var n := d / dist if dist > 0.0001 else Vector2.RIGHT
				p = cp + n * min_dist
				moved = true
		p = clamp_inside(p, r)
		if not moved:
			break
	return p


## Çitin içinde kalacak şekilde sınırlar.
func clamp_inside(p: Vector2, r: float) -> Vector2:
	var limit := half - r
	return Vector2(clampf(p.x, -limit, limit), clampf(p.y, -limit, limit))


## from noktasından dir yönünde giden r yarıçaplı bir kartopu, engele ya da çite çarpmadan
## en fazla ne kadar gider (max_dist'i geçmez). Nişan çizgisi için.
func cast(from: Vector2, dir: Vector2, r: float, max_dist: float) -> float:
	var step := 0.1
	var d := 0.0
	while d < max_dist:
		var p := from + dir * (d + step)
		if absf(p.x) > half or absf(p.y) > half:
			return d
		for ob: Obstacle in obstacles:
			if ob.edge_distance(p) < r:
				return d
		d += step
	return max_dist


## r yarıçaplı daire bu noktada engellere en az `margin` kadar uzak mı?
func is_free(p: Vector2, r: float, margin: float = 0.0) -> bool:
	if absf(p.x) > half - r or absf(p.y) > half - r:
		return false
	for ob: Obstacle in obstacles:
		if ob.edge_distance(p) < r + margin:
			return false
	return true
