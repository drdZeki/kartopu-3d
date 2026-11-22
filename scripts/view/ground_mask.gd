extends RefCounted
## Haritaya özel zemin maskesi: her harita için bir kez, kuraldaki engellere bakarak çizilir.
##   Kırmızı (R): engellerin ve çalılıkların dibindeki mavimsi gölge çukuru
##   Yeşil   (G): çit boyunca ve rüzgâr yönünde biriken parlak kar
##   Mavi    (B): ortadan çite uzanan ezilmiş kar patikaları
## Kar zemini gölgelendiricisi (shaders/snow_ground.gdshader) bu maskeyi okur.

const World = preload("res://scripts/core/world.gd")
const Obstacle = preload("res://scripts/core/obstacle.gd")

const RES: int = 256                         # maskenin bir kenarı (piksel); 1 piksel ≈ 0,15 m
const WIND := Vector2(0.88, 0.47)            # gölgelendiricideki rüzgâr dalgalarıyla aynı yön
const PATH_COUNT: int = 3
const PATH_WIDTH: float = 0.55               # patikanın yarı genişliği (m)

var _size: float
var _r := PackedFloat32Array()
var _g := PackedFloat32Array()
var _b := PackedFloat32Array()


## Kullanım: GroundMask.new().build(world, rng)
func build(world: World, rng: RandomNumberGenerator) -> ImageTexture:
	_size = world.size
	_r.resize(RES * RES)
	_g.resize(RES * RES)
	_b.resize(RES * RES)

	_paths(world, rng)
	_drifts(world, rng)
	# gölge çukurları en son: patikanın üstüne de düşsün
	for ob: Obstacle in world.obstacles:
		var grow := 1.0 if ob.kind == "tree" else 0.7
		_stamp_capsule(_r, ob.a, ob.b, ob.radius * 0.5, ob.radius + grow, 0.9)
	for b in world.bushes:
		_stamp_capsule(_r, b.pos, b.pos, b.radius * 0.5, b.radius + 0.5, 0.55)

	var bytes := PackedByteArray()
	bytes.resize(RES * RES * 3)
	for i in RES * RES:
		bytes[i * 3] = int(clampf(_r[i], 0.0, 1.0) * 255.0)
		bytes[i * 3 + 1] = int(clampf(_g[i], 0.0, 1.0) * 255.0)
		bytes[i * 3 + 2] = int(clampf(_b[i], 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(RES, RES, false, Image.FORMAT_RGB8, bytes)
	return ImageTexture.create_from_image(img)


# ---------- Çizimler ----------

## Ortadan çite doğru kıvrılarak giden patikalar. Engellerin içinden geçmez.
func _paths(world: World, rng: RandomNumberGenerator) -> void:
	var base_angle := rng.randf_range(0.0, TAU)
	for k in PATH_COUNT:
		var angle := base_angle + TAU * k / PATH_COUNT + rng.randf_range(-0.4, 0.4)
		var dir := Vector2.RIGHT.rotated(angle)
		var points: Array = [dir * 1.5]
		var steps := 5
		var bend := rng.randf_range(-2.5, 2.5)
		for i in range(1, steps + 1):
			var t := float(i) / steps
			var p: Vector2 = dir * lerpf(1.5, world.half + 1.0, t)
			p += dir.orthogonal() * (bend * sin(t * PI) + rng.randf_range(-0.6, 0.6))
			# engelin üstüne denk gelirse kenara kaydır
			for _try in 6:
				if world.is_free(p, PATH_WIDTH, 0.3) or absf(p.x) > world.half - 1.0 or absf(p.y) > world.half - 1.0:
					break
				p += dir.orthogonal() * 0.8
			points.append(p)
		# noktalar arasından yumuşak bir eğri geçir (Catmull-Rom): köşeli zikzak olmasın
		for i in points.size() - 1:
			var p0: Vector2 = points[maxi(i - 1, 0)]
			var p1: Vector2 = points[i]
			var p2: Vector2 = points[i + 1]
			var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
			var n := int(p1.distance_to(p2) / 0.2) + 1
			for j in n:
				var c := _catmull(p0, p1, p2, p3, float(j) / n)
				var w := PATH_WIDTH * (0.85 + 0.3 * sin(c.x * 1.3 + c.y * 0.7))   # kenarı hafif dalgalı
				_stamp_capsule(_b, c, c, w * 0.3, w, 0.8)


## Çitin dibinde ve rüzgâr yönünde uzanan parlak kar birikintileri.
func _drifts(world: World, rng: RandomNumberGenerator) -> void:
	var band := 1.4
	for y in RES:
		for x in RES:
			var p := _to_world(x, y)
			var edge := world.half - maxf(absf(p.x), absf(p.y))
			if edge < band:
				var i := y * RES + x
				var wobble := 0.75 + 0.25 * sin(p.x * 1.7 + p.y * 2.3)
				_g[i] = maxf(_g[i], (1.0 - edge / band) * wobble)
	for k in 10:
		var c := Vector2(rng.randf_range(-world.half + 3, world.half - 3), rng.randf_range(-world.half + 3, world.half - 3))
		var half_len := rng.randf_range(1.5, 3.0)
		_stamp_capsule(_g, c - WIND * half_len, c + WIND * half_len, 0.1, 0.7, 0.7)


# ---------- Yardımcılar ----------

## a–b doğru parçası çevresine yumuşak kenarlı bir leke basar: inner içinde tam, outer'a doğru söner.
func _stamp_capsule(arr: PackedFloat32Array, a: Vector2, b: Vector2, inner: float, outer: float, strength: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * outer
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * outer
	var p0 := _to_pixel(lo)
	var p1 := _to_pixel(hi)
	var ab := b - a
	var len_sq := maxf(ab.length_squared(), 0.000001)
	for y in range(maxi(0, p0.y), mini(RES, p1.y + 1)):
		for x in range(maxi(0, p0.x), mini(RES, p1.x + 1)):
			var p := _to_world(x, y)
			var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d < outer:
				var v := strength * (1.0 - smoothstep(inner, outer, d))
				var i := y * RES + x
				arr[i] = maxf(arr[i], v)


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _to_world(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) / RES - 0.5, (y + 0.5) / RES - 0.5) * _size


func _to_pixel(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x / _size + 0.5) * RES), int((p.y / _size + 0.5) * RES))
