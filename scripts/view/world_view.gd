extends Node3D
## Haritanın 3D görüntüsü: gökyüzü ve ışık, karlı zemin, çit, dış orman ve süsler,
## engeller (çam, kaya, kar kalesi duvarı), karlı çalılıklar.
## Kuraldaki haritayı (World) okuyup çizer; kurallara dokunmaz.
## Telefon için: her engel tek şekle birleştirilir (Kit.bake), tekrar eden şeyler MultiMesh ile çizilir.

const Kit = preload("res://scripts/view/mesh_kit.gd")
const World = preload("res://scripts/core/world.gd")
const Obstacle = preload("res://scripts/core/obstacle.gd")
const GroundMask = preload("res://scripts/view/ground_mask.gd")
const GROUND_SHADER = preload("res://shaders/snow_ground.gdshader")

const SKY := Color(0.70, 0.84, 0.96)
const SNOW := Color(0.95, 0.97, 1.0)
const SNOW_BLUE := Color(0.83, 0.89, 0.99)
const ICE := Color(0.50, 0.68, 0.84)
const ICE_LIGHT := Color(0.66, 0.80, 0.92)
const BRICK_1 := Color(0.72, 0.81, 0.96)   # kar kalesi blokları: ışıkta bile seçilsin diye mavimsi
const BRICK_2 := Color(0.80, 0.87, 0.98)
const PINE_1 := Color(0.15, 0.46, 0.38)
const PINE_2 := Color(0.20, 0.55, 0.42)
const PINE_FAR := Color(0.14, 0.40, 0.36)
const TRUNK := Color(0.45, 0.29, 0.18)
const ROCK := Color(0.53, 0.57, 0.68)
const WOOD := Color(0.66, 0.45, 0.27)
const WOOD_DARK := Color(0.48, 0.31, 0.19)
const ROOF := Color(0.72, 0.25, 0.22)
const LEAF := Color(0.16, 0.50, 0.30)
const LEAF_LIGHT := Color(0.24, 0.62, 0.36)
const BERRY := Color(0.88, 0.13, 0.18)
const GRASS := Color(0.74, 0.66, 0.38)
const PEBBLE := Color(0.58, 0.60, 0.68)
const FLOWER_COLORS := [Color(0.62, 0.42, 0.86), Color(0.98, 0.62, 0.22), Color(0.95, 0.40, 0.55)]
const LAMP_LIGHT := Color(1.0, 0.85, 0.45)
const SLED := Color(0.85, 0.20, 0.22)

const OUTLINE: float = 0.025          # engellerin kontur kalınlığı (m)
const OUTLINE_THIN: float = 0.015
const FOREST_DEPTH: float = 10.0      # çitin dışındaki orman şeridinin genişliği
const FOREST_SPACING: float = 2.1
const PICKET_GAP: float = 0.34        # çit tahtaları arası

const SUN_NO_SHADOW_ENERGY: float = 1.15

var _env_built := false
var _sun: DirectionalLight3D
var _ground_mat: ShaderMaterial
var _forest: Array = []               # dış ormanın MultiMesh'leri (ayarlardan seyreltilebilir)
var _keep_clear: Array = []           # orman ağaçlarının girmeyeceği yerler: [merkez Vector2, yarıçap]
var _bush_nodes: Dictionary = {}      # Bush -> çalının düğümü (saydamlık, bekleme sayacı)


func build(world: World) -> void:
	if not _env_built:
		_build_environment()
		_env_built = true
	var old := get_node_or_null("Map")
	if old:
		remove_child(old)
		old.queue_free()
	var map := Node3D.new()
	map.name = "Map"
	add_child(map)
	_keep_clear.clear()
	_bush_nodes.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value + 7   # süsler de haritayla birlikte aynı kalsın

	_build_ground(map, world, rng)
	_build_fence(map, world)
	_build_outside_props(map, world, rng)
	_build_forest(map, world, rng)
	for ob: Obstacle in world.obstacles:
		match ob.kind:
			"tree": _build_tree(map, ob.center(), ob.radius, rng)
			"rock": _build_rock(map, ob.center(), ob.radius, rng)
			"wall": _build_wall(map, ob, rng)
	for b in world.bushes:
		_bush_nodes[b] = _build_bush(map, b.pos, b.radius, rng)
	_build_decorations(map, world, rng)
	Kit.outline = 0.0


# ---------- Gökyüzü ve ışık ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# gölgeli taraflar hafif mavimsi olsun (karlı bir gün havası)
	env.ambient_light_color = Color(0.72, 0.80, 0.95)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# sis kapalı: Compatibility görüntü ayarında renkleri çok soldurdu
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_make_sun(true)
	# gölge haritası 4096 yerine 2048: telefonda belirgin hızlanma, görünüşte fark az
	RenderingServer.directional_shadow_atlas_set_size(2048, true)


## Güneş. Compatibility görüntü ayarında çalışan bir ışığın gölgesini sonradan kapatınca ışığın
## tamamı kayboluyor (sahne griye dönüyor); bu yüzden gölge değişince güneş yeniden oluşturulur.
func _make_sun(shadows: bool) -> void:
	if _sun:
		_sun.queue_free()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	# gölgesiz güneş bu görüntü ayarında daha sönük düşüyor: aynı parlaklık için güçlendirilir
	sun.light_energy = 0.5 if shadows else SUN_NO_SHADOW_ENERGY
	sun.shadow_enabled = shadows
	sun.shadow_opacity = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0   # dikey ekranda kamera daha ileriyi görüyor
	add_child(sun)
	_sun = sun


# ---------- Zemin ----------

## Tek büyük kar zemini (oyun alanı + orman). Görünüşü gölgelendiricide (snow_ground.gdshader),
## haritaya özel gölge çukurları, patikalar ve birikintiler maskede (ground_mask.gd).
func _build_ground(map: Node3D, world: World, rng: RandomNumberGenerator) -> void:
	var plane := PlaneMesh.new()
	var big := world.size + FOREST_DEPTH * 2.0 + 40.0
	plane.size = Vector2(big, big)
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("map_mask", GroundMask.new().build(world, rng))
	m.set_shader_parameter("map_size", world.size)
	_ground_mat = m
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = m
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map.add_child(ground)


# ---------- Çit ----------

## Uçları sivri ahşap tahtalardan çit, kalın direkler, üst tahtada kar.
func _build_fence(map: Node3D, world: World) -> void:
	var h := world.half
	var planks: Array = []
	var tips: Array = []
	var posts: Array = []
	var caps: Array = []
	var count := int(round(world.size / PICKET_GAP))
	var step := world.size / count
	for side in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * side)
		for i in count:
			var t := -h + (i + 0.5) * step
			var p := turn * Vector3(t, 0, -h)
			planks.append(Transform3D(turn, p + Vector3(0, 0.36, 0)))
			tips.append(Transform3D(turn * Basis(Vector3.UP, PI * 0.25), p + Vector3(0, 0.78, 0)))
			if i % 9 == 0:
				var q := turn * Vector3(-h + i * step, 0, -h)
				posts.append(Transform3D(turn, q + Vector3(0, 0.45, 0)))
				caps.append(Transform3D(turn, q + Vector3(0, 0.93, 0)))
	Kit.outline = OUTLINE_THIN
	Kit.multi(map, Kit.box(Vector3(0.13, 0.72, 0.04)), WOOD, planks)
	Kit.multi(map, Kit.cylinder(0.0, 0.092, 0.12, 4), WOOD, tips)
	Kit.multi(map, Kit.box(Vector3(0.17, 0.9, 0.17)), WOOD_DARK, posts)
	Kit.multi(map, Kit.box(Vector3(0.22, 0.08, 0.22)), SNOW, caps, false)
	# iki sıra yatay tahta (çitin dış yüzünde) ve üst tahtada ince kar
	var rails := Node3D.new()
	map.add_child(rails)
	for side in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * side)
		for y in [0.22, 0.56]:
			var rail := Kit.part(rails, Kit.box(Vector3(world.size, 0.08, 0.05)), WOOD_DARK, turn * Vector3(0, y, -h - 0.045))
			rail.basis = turn
		var snow := Kit.part(rails, Kit.box(Vector3(world.size, 0.035, 0.08)), SNOW, turn * Vector3(0, 0.615, -h - 0.045))
		snow.basis = turn
	Kit.bake(rails)
	Kit.outline = 0.0


# ---------- Harita dışı: kulübe, fenerler, odun yığını, kızak, orman ----------

func _build_outside_props(map: Node3D, world: World, rng: RandomNumberGenerator) -> void:
	var h := world.half
	# kuzeyde (kameranın baktığı yön) sıcak ışıklı bir kulübe
	var cabin_pos := Vector2(rng.randf_range(-h * 0.5, h * 0.5), -(h + 4.2))
	_build_cabin(map, cabin_pos)
	_keep_clear.append([cabin_pos, 4.2])

	# çitin dışında fenerler
	var posts: Array = []
	var lights: Array = []
	var gap := world.size / 4.0
	for side in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * side)
		for i in 4:
			var p := turn * Vector3(-h + (i + 0.5) * gap, 0, -h - 0.9)
			posts.append(Transform3D(Basis(), p + Vector3(0, 0.9, 0)))
			lights.append(Transform3D(Basis(), p + Vector3(0, 1.95, 0)))
			_keep_clear.append([Vector2(p.x, p.z), 1.0])
	Kit.outline = OUTLINE_THIN
	Kit.multi(map, Kit.cylinder(0.06, 0.08, 1.8, 8), Color(0.22, 0.24, 0.32), posts)
	Kit.multi(map, Kit.box(Vector3(0.34, 0.06, 0.34)), Color(0.22, 0.24, 0.32), lights.map(
		func(t: Transform3D) -> Transform3D: return t.translated(Vector3(0, -0.2, 0))))
	Kit.multi(map, Kit.cylinder(0.0, 0.26, 0.18, 4), SNOW, lights.map(
		func(t: Transform3D) -> Transform3D: return Transform3D(Basis(Vector3.UP, PI * 0.25), t.origin + Vector3(0, 0.22, 0))), false)
	Kit.outline = 0.0
	Kit.multi(map, Kit.box(Vector3(0.24, 0.34, 0.24)), LAMP_LIGHT, lights, false, Kit.glow(LAMP_LIGHT))

	# odun yığınları ve bir kızak
	for i in 2:
		var side := rng.randi_range(0, 3)
		var turn := Basis(Vector3.UP, PI * 0.5 * side)
		var p3 := turn * Vector3(rng.randf_range(-h * 0.7, h * 0.7), 0, -h - 2.4)
		var p := Vector2(p3.x, p3.z)
		_build_log_pile(map, p, PI * 0.5 * side)
		_keep_clear.append([p, 1.8])
	var sled_side := rng.randi_range(1, 3)
	var sturn := Basis(Vector3.UP, PI * 0.5 * sled_side)
	var s3 := sturn * Vector3(rng.randf_range(-h * 0.6, h * 0.6), 0, -h - 1.8)
	_build_sled(map, Vector2(s3.x, s3.z), rng.randf_range(0.0, TAU))
	_keep_clear.append([Vector2(s3.x, s3.z), 1.4])


func _build_cabin(map: Node3D, p: Vector2) -> void:
	var t := Node3D.new()
	t.position = Vector3(p.x, 0, p.y)
	map.add_child(t)
	Kit.outline = OUTLINE
	var w := 3.6
	var d := 2.8
	var wall_h := 1.9
	# kütük duvarlar: üst üste yatay kütükler
	for i in 6:
		var y := 0.16 + i * 0.31
		var c := WOOD if i % 2 == 0 else WOOD.darkened(0.08)
		Kit.part(t, Kit.cylinder(0.17, 0.17, w + 0.3, 10), c, Vector3(0, y, d * 0.5), Vector3(0, 0, 90))
		Kit.part(t, Kit.cylinder(0.17, 0.17, w + 0.3, 10), c, Vector3(0, y, -d * 0.5), Vector3(0, 0, 90))
		Kit.part(t, Kit.cylinder(0.17, 0.17, d + 0.3, 10), c, Vector3(w * 0.5, y + 0.15, 0), Vector3(90, 0, 0))
		Kit.part(t, Kit.cylinder(0.17, 0.17, d + 0.3, 10), c, Vector3(-w * 0.5, y + 0.15, 0), Vector3(90, 0, 0))
	Kit.part(t, Kit.box(Vector3(w - 0.1, wall_h, d - 0.1)), WOOD_DARK, Vector3(0, wall_h * 0.5, 0))
	# çatı: iki eğik levha, üstünde kalın kar
	for s in [-1.0, 1.0]:
		Kit.part(t, Kit.box(Vector3(w + 0.8, 0.14, 2.0)), ROOF, Vector3(0, 2.45, s * 0.75), Vector3(s * 38.0, 0, 0))
		Kit.part(t, Kit.box(Vector3(w + 0.9, 0.12, 1.9)), SNOW, Vector3(0, 2.55, s * 0.72), Vector3(s * 38.0, 0, 0))
	# baca
	Kit.part(t, Kit.box(Vector3(0.45, 1.0, 0.45)), Color(0.62, 0.36, 0.30), Vector3(1.0, 3.0, -0.4))
	Kit.part(t, Kit.box(Vector3(0.55, 0.12, 0.55)), SNOW, Vector3(1.0, 3.52, -0.4))
	# kapı ve sıcak ışıklı pencereler (güneye, oyun alanına bakar)
	Kit.part(t, Kit.box(Vector3(0.75, 1.3, 0.08)), Color(0.40, 0.24, 0.16), Vector3(-0.8, 0.65, d * 0.5 + 0.18))
	for x in [0.55, 1.35]:
		var win := Kit.part(t, Kit.box(Vector3(0.55, 0.5, 0.06)), LAMP_LIGHT, Vector3(x, 1.15, d * 0.5 + 0.18))
		win.material_override = Kit.glow(LAMP_LIGHT)
		Kit.part(t, Kit.box(Vector3(0.65, 0.07, 0.12)), SNOW, Vector3(x, 0.87, d * 0.5 + 0.2))
	var glow_parts: Array = []
	for c in t.get_children():
		if (c as MeshInstance3D).material_override == Kit.glow(LAMP_LIGHT):
			glow_parts.append(c)
	Kit.bake(t, glow_parts)
	Kit.outline = 0.0


func _build_log_pile(map: Node3D, p: Vector2, yaw: float) -> void:
	var t := Node3D.new()
	t.position = Vector3(p.x, 0, p.y)
	t.rotation.y = yaw
	map.add_child(t)
	Kit.outline = OUTLINE_THIN
	var rows := [3, 2, 1]
	for r in rows.size():
		var n: int = rows[r]
		for i in n:
			var x := (i - (n - 1) * 0.5) * 0.34
			Kit.part(t, Kit.cylinder(0.16, 0.16, 1.3, 10), WOOD if (i + r) % 2 == 0 else WOOD_DARK, Vector3(x, 0.16 + r * 0.28, 0), Vector3(90, 0, 0))
			Kit.part(t, Kit.cylinder(0.11, 0.11, 1.32, 10), Color(0.86, 0.70, 0.48), Vector3(x, 0.16 + r * 0.28, 0), Vector3(90, 0, 0))
	Kit.part(t, Kit.sphere(0.5, 12, 6), SNOW, Vector3(0, 0.78, 0), Vector3.ZERO, Vector3(0.7, 0.25, 1.3))
	Kit.bake(t)
	Kit.outline = 0.0


func _build_sled(map: Node3D, p: Vector2, yaw: float) -> void:
	var t := Node3D.new()
	t.position = Vector3(p.x, 0, p.y)
	t.rotation.y = yaw
	map.add_child(t)
	Kit.outline = OUTLINE_THIN
	for s in [-1.0, 1.0]:
		Kit.part(t, Kit.box(Vector3(0.05, 0.05, 1.3)), Color(0.25, 0.25, 0.32), Vector3(s * 0.3, 0.04, 0))
		Kit.part(t, Kit.torus(0.08, 0.13), Color(0.25, 0.25, 0.32), Vector3(s * 0.3, 0.13, 0.66), Vector3(0, 0, 90), Vector3(1, 1, 1))
		for z in [-0.4, 0.3]:
			Kit.part(t, Kit.box(Vector3(0.04, 0.22, 0.04)), Color(0.25, 0.25, 0.32), Vector3(s * 0.3, 0.15, z))
	Kit.part(t, Kit.box(Vector3(0.75, 0.06, 1.1)), SLED, Vector3(0, 0.28, 0))
	Kit.part(t, Kit.box(Vector3(0.62, 0.03, 0.9)), SNOW, Vector3(0, 0.325, -0.05))
	Kit.bake(t)
	Kit.outline = 0.0


## Çitin dışındaki süs ormanı: yüzlerce ağaç, parça başına tek çizim (MultiMesh).
func _build_forest(map: Node3D, world: World, rng: RandomNumberGenerator) -> void:
	var trees: Array = []   # [taban, dönüş, boyut]
	var inner := world.half + 1.5
	var outer := world.half + FOREST_DEPTH
	var x := -outer
	while x <= outer:
		var z := -outer
		while z <= outer:
			var p := Vector2(x + rng.randf_range(-0.8, 0.8), z + rng.randf_range(-0.8, 0.8))
			if maxf(absf(p.x), absf(p.y)) > inner and not _is_kept_clear(p):
				var s := rng.randf_range(0.85, 1.5)
				trees.append([Vector3(p.x, 0, p.y), Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), s])
			z += FOREST_SPACING
		x += FOREST_SPACING
	# karışık sıra: ayarlardan orman azaltılınca (ilk N ağaç çizilir) her yerden eşit seyrelsin
	for i in range(trees.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = trees[i]
		trees[i] = trees[j]
		trees[j] = tmp
	var tiers: Array = [[], [], [], []]
	var snows: Array = [[], [], [], []]
	var trunks: Array = []
	for t: Array in trees:
		var base: Vector3 = t[0]
		var b: Basis = t[1]
		var s: float = t[2]
		trunks.append(Transform3D(b, base + Vector3(0, 0.25 * s, 0)))
		for k in 4:
			var y := (0.7 + k * 0.42) * s
			tiers[k].append(Transform3D(b, base + Vector3(0, y, 0)))
			snows[k].append(Transform3D(b, base + Vector3(0, y + 0.2 * s, 0)))
	var widths := [0.95, 0.78, 0.6, 0.4]
	_forest.clear()
	_forest.append(Kit.multi(map, Kit.cylinder(0.11, 0.15, 0.5, 6), TRUNK, trunks, false))
	for k in 4:
		var w: float = widths[k]
		_forest.append(Kit.multi(map, Kit.cylinder(0.0, w, 0.72, 8), PINE_FAR if k % 2 == 0 else PINE_1, tiers[k], false))
		_forest.append(Kit.multi(map, Kit.cylinder(0.0, w * 0.6, 0.34, 8), SNOW, snows[k], false))


# ---------- Ayarlar (eski telefonlar için) ----------

## Güneş gölgeleri. Kapalıyken zeminde gölge olmaz (telefonda en çok yoran şeylerden).
func set_shadows(on: bool) -> void:
	if _sun and _sun.shadow_enabled != on:
		_make_sun(on)


## Dış ormanın ne kadarı çizilir (0–1).
func set_forest(fraction: float) -> void:
	for mm: MultiMeshInstance3D in _forest:
		if is_instance_valid(mm):
			mm.multimesh.visible_instance_count = int(mm.multimesh.instance_count * clampf(fraction, 0.0, 1.0))


## Zemin ayrıntısı: rüzgâr dalgaları, ton farkları ve parıltılar. Kapalıyken zemin daha sade, daha hızlı.
func set_ground_detail(on: bool) -> void:
	if _ground_mat:
		_ground_mat.set_shader_parameter("detail", on)


func _is_kept_clear(p: Vector2) -> bool:
	for k: Array in _keep_clear:
		var c: Vector2 = k[0]
		var r: float = k[1]
		if p.distance_to(c) < r:
			return true
	return false


# ---------- Engeller ----------

func _build_tree(map: Node3D, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.position = Vector3(c.x, 0, c.y)
	t.rotation = Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(0.0, TAU), rng.randf_range(-0.04, 0.04))
	map.add_child(t)
	var s := r / 0.65   # boyut ağacın çarpışma yarıçapına göre
	Kit.outline = OUTLINE
	Kit.part(t, Kit.cylinder(0.12 * s, 0.17 * s, 0.6 * s, 8), TRUNK, Vector3(0, 0.3 * s, 0))
	var widths := [1.40, 1.12, 0.86, 0.58]
	for k in 4:
		var w: float = widths[k] * r
		var y := (0.78 + k * 0.42) * s
		var col := PINE_1 if k % 2 == 0 else PINE_2
		Kit.part(t, Kit.cylinder(0.0, w, 0.78 * s, 9), col, Vector3(0, y, 0), Vector3(0, rng.randf_range(0, 40), 0))
		# katın üstünde kar örtüsü
		Kit.part(t, Kit.cylinder(0.0, w * 0.62, 0.38 * s, 9), SNOW, Vector3(0, y + 0.2 * s, 0), Vector3(0, rng.randf_range(0, 40), 0))
	Kit.bake(t)
	Kit.outline = 0.0


func _build_rock(map: Node3D, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.position = Vector3(c.x, 0, c.y)
	t.rotation.y = rng.randf_range(0.0, TAU)
	map.add_child(t)
	Kit.outline = OUTLINE
	var shade := rng.randf_range(-0.05, 0.05)
	var col := Color(ROCK.r + shade, ROCK.g + shade, ROCK.b + shade)
	# büyük kaya + yanında küçük kaya, üstlerinde kar
	Kit.part(t, Kit.sphere(1.0, 7, 5), col, Vector3(0, r * 0.28, 0), Vector3(0, 0, rng.randf_range(-8, 8)), Vector3(r * 1.0, r * 0.78, r * 0.92))
	Kit.part(t, Kit.sphere(1.0, 8, 4), SNOW, Vector3(0, r * 0.86, 0), Vector3(0, 20, 0), Vector3(r * 0.66, r * 0.2, r * 0.6))
	Kit.part(t, Kit.sphere(1.0, 6, 4), col.darkened(0.08), Vector3(r * 0.85, r * 0.12, r * 0.35), Vector3(0, 30, 10), Vector3(r * 0.45, r * 0.38, r * 0.42))
	Kit.part(t, Kit.sphere(1.0, 8, 4), SNOW, Vector3(r * 0.85, r * 0.45, r * 0.35), Vector3.ZERO, Vector3(r * 0.28, r * 0.1, r * 0.26))
	Kit.outline = 0.0
	Kit.bake(t)


## Kar kalesi duvarı: tuğla gibi dizilmiş kar blokları, tepesinde mazgallar.
## Kural tarafındaki kapsül biçimine (iki yuvarlak uç + aradaki parça) uyar.
func _build_wall(map: Node3D, ob: Obstacle, rng: RandomNumberGenerator) -> void:
	var c := ob.center()
	var dir := (ob.b - ob.a)
	var length := dir.length()
	var t := Node3D.new()
	t.position = Vector3(c.x, 0, c.y)
	t.rotation.y = -atan2(dir.y, dir.x)   # yerel x ekseni duvar boyunca
	map.add_child(t)
	var r := ob.radius
	var span := length + r * 1.4          # uçlardaki yuvarlak kısmı da kapla
	var bw := 0.36
	var bh := 0.26
	var depth := r * 1.9
	var n := maxi(2, int(round(span / bw)))
	var w := span / n
	Kit.outline = OUTLINE
	for row in 3:
		var offset := 0.5 * w if row % 2 == 1 else 0.0
		var count := n if row % 2 == 0 else n - 1
		for i in count:
			if row == 2 and i % 2 == 1:
				continue   # en üst sırada boşluklar: mazgal
			var x := -span * 0.5 + w * (i + 0.5) + offset
			var col := BRICK_1 if (i + row) % 2 == 0 else BRICK_2
			Kit.part(t, Kit.box(Vector3(w - 0.03, bh - 0.02, depth)), col, Vector3(x, bh * (row + 0.5), rng.randf_range(-0.02, 0.02)),
				Vector3(0, rng.randf_range(-2.0, 2.0), 0))
	Kit.outline = 0.0
	Kit.bake(t)


# ---------- Çalılık ----------

## Karlı çobanpüskülü çalısı: koyu yeşil topaklar, kırmızı meyveler, tepesinde kar.
func _build_bush(map: Node3D, c: Vector2, r: float, rng: RandomNumberGenerator) -> Node3D:
	var t := Node3D.new()
	t.position = Vector3(c.x, 0, c.y)
	map.add_child(t)
	# bekleme sayacı (süre dolunca çalının üstünde geri sayar)
	var label := Label3D.new()
	label.name = "Cool"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.007
	label.font_size = 72
	label.outline_size = 20
	label.modulate = Color(0.85, 0.92, 1.0)
	label.outline_modulate = Color(0.17, 0.25, 0.42)
	label.position = Vector3(0, 1.9, 0)
	label.visible = false
	t.add_child(label)
	Kit.outline = OUTLINE
	Kit.part(t, Kit.sphere(1.0, 12, 6), LEAF, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(r * 0.7, r * 0.62, r * 0.7))
	var tops: Array = []
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf_range(-0.25, 0.25)
		var d := r * rng.randf_range(0.5, 0.68)
		var s := r * rng.randf_range(0.34, 0.46)
		var p := Vector3(cos(a) * d, 0.12 + rng.randf_range(0.0, 0.15), sin(a) * d)
		var col := LEAF if i % 2 == 0 else LEAF_LIGHT
		Kit.part(t, Kit.sphere(1.0, 12, 6), col, p, Vector3.ZERO, Vector3(s, s * 0.9, s))
		tops.append(p + Vector3(0, s * 0.75, 0))
	Kit.outline = 0.0
	# kırmızı meyveler (üç tane bir arada)
	for i in 9:
		var a := rng.randf_range(0.0, TAU)
		var p := Vector3(cos(a) * r * 0.78, rng.randf_range(0.35, 0.7), sin(a) * r * 0.78)
		for j in 3:
			Kit.part(t, Kit.sphere(0.055, 8, 4), BERRY, p + Vector3((j - 1) * 0.06, (j % 2) * 0.05, 0.03), Vector3.ZERO, Vector3.ONE, false)
	# tepelerde kar
	Kit.part(t, Kit.sphere(1.0, 12, 5), SNOW, Vector3(0, 0.3 + r * 0.6, 0), Vector3.ZERO, Vector3(r * 0.26, r * 0.1, r * 0.26), false)
	for i in 3:
		var p: Vector3 = tops[rng.randi_range(0, tops.size() - 1)]
		Kit.part(t, Kit.sphere(1.0, 10, 4), SNOW, p, Vector3.ZERO, Vector3(r * 0.22, r * 0.08, r * 0.22), false)
	Kit.bake(t, [label])
	return t


## Her karede: oyuncunun içinde durduğu çalı yarı saydam olur (oyuncu görünsün);
## süresi dolmuş çalı soluk görünür, üstünde kalan bekleme saniyesi yazar.
func update_bushes(bushes: Array, inside) -> void:
	for b in bushes:
		var t: Node3D = _bush_nodes.get(b)
		if t == null:
			continue
		var fade := 0.0
		if b.cool > 0.0:
			fade = 0.55
		elif b == inside:
			fade = 0.5
		var label: Label3D = t.get_node("Cool")
		label.visible = b.cool > 0.0
		if label.visible:
			label.text = str(ceili(b.cool))
		if not is_equal_approx(t.get_meta("fade", 0.0), fade):
			t.set_meta("fade", fade)
			Kit.set_alpha(t, 1.0 - fade)


# ---------- Süsler (hepsi tek şekilde birleştirilir) ----------

func _build_decorations(map: Node3D, world: World, rng: RandomNumberGenerator) -> void:
	var decor := Node3D.new()
	map.add_child(decor)
	var limit := world.half - 1.0
	Kit.outline = 0.0

	# çitin dibinde kar yığıntıları
	for side in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * side)
		var x := -world.half
		while x < world.half:
			var len := rng.randf_range(1.5, 3.2)
			var p := turn * Vector3(x + len * 0.5, 0, -world.half + 0.1)
			var drift := Kit.part(decor, Kit.sphere(1.0, 14, 6), SNOW, p, Vector3.ZERO, Vector3(len * 0.6, rng.randf_range(0.22, 0.4), 0.55), false)
			drift.basis = turn * Basis.from_scale(Vector3(len * 0.6, rng.randf_range(0.22, 0.4), 0.55))
			x += len * rng.randf_range(0.7, 1.0)

	# donmuş gölcükler: buz, ortası açık renk, karlı kenar, parıltı çizgileri
	for i in 3:
		for _try in 20:
			var p := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
			var r := rng.randf_range(1.3, 2.2)
			if p.length() > 4.0 and world.is_free(p, r, 0.5):
				var squash := rng.randf_range(0.65, 0.9)
				var g := Node3D.new()
				g.position = Vector3(p.x, 0, p.y)
				g.rotation.y = rng.randf_range(0.0, TAU)
				decor.add_child(g)
				Kit.part(g, Kit.cylinder(1.0, 1.0, 0.03, 28), ICE, Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(r, 1, r * squash), false)
				Kit.part(g, Kit.cylinder(1.0, 1.0, 0.03, 28), ICE_LIGHT, Vector3(0.12 * r, 0.018, -0.1 * r), Vector3.ZERO, Vector3(r * 0.6, 1, r * squash * 0.55), false)
				Kit.part(g, Kit.torus(0.92, 1.1), SNOW, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(r, 0.7, r * squash), false)
				for k in 2:
					Kit.part(g, Kit.box(Vector3(r * 0.5 - k * 0.2, 0.01, 0.06)), Color.WHITE, Vector3(-0.2 * r + k * 0.15, 0.035, 0.15 * r + k * 0.14), Vector3(0, 30, 0), Vector3.ONE, false)
				break

	# kardan çıkan kuru ot öbekleri
	for i in 22:
		var p := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		if not world.is_free(p, 0.4, 0.2):
			continue
		for j in 5:
			var a := rng.randf_range(0.0, TAU)
			var lean := rng.randf_range(10.0, 30.0)
			Kit.part(decor, Kit.cylinder(0.0, 0.025, rng.randf_range(0.18, 0.32), 4), GRASS.darkened(rng.randf_range(0.0, 0.2)),
				Vector3(p.x + cos(a) * 0.05, 0.1, p.y + sin(a) * 0.05), Vector3(cos(a) * lean, 0, sin(a) * lean), Vector3.ONE, false)

	# küçük kış çiçekleri
	for i in 12:
		var p := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		if not world.is_free(p, 0.4, 0.2):
			continue
		var col: Color = FLOWER_COLORS[rng.randi_range(0, FLOWER_COLORS.size() - 1)]
		for j in 3:
			var q := p + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
			var hgt := rng.randf_range(0.12, 0.2)
			Kit.part(decor, Kit.cylinder(0.008, 0.01, hgt, 4), LEAF_LIGHT, Vector3(q.x, hgt * 0.5, q.y), Vector3.ZERO, Vector3.ONE, false)
			Kit.part(decor, Kit.sphere(0.04, 8, 4), col, Vector3(q.x, hgt + 0.02, q.y), Vector3.ZERO, Vector3(1, 1.3, 1), false)

	# çakıl taşları ve yerdeki dallar
	for i in 20:
		var p := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		if not world.is_free(p, 0.3):
			continue
		if i % 2 == 0:
			var s := rng.randf_range(0.06, 0.12)
			Kit.part(decor, Kit.sphere(1.0, 6, 4), PEBBLE, Vector3(p.x, 0.0, p.y), Vector3(0, rng.randf_range(0, 360), 0), Vector3(s * 1.3, s * 0.6, s), false)
		else:
			Kit.part(decor, Kit.cylinder(0.015, 0.02, rng.randf_range(0.3, 0.5), 5), TRUNK, Vector3(p.x, 0.02, p.y),
				Vector3(0, rng.randf_range(0, 360), 90), Vector3.ONE, false)

	Kit.bake(decor)
