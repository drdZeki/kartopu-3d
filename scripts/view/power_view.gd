extends Node3D
## Yerdeki güçlendirmelerin görüntüsü: her türün kendine özgü küçük 3D simgesi
## (üç kartopu, buz küpü, kalp, kalkan, mıknatıs, bulut) havada döner ve hafifçe süzülür.
## Altında güçlendirmenin renginde parlayan bir halka vardır. Son 3 sn yanıp söner.

const Kit = preload("res://scripts/view/mesh_kit.gd")
const Power = preload("res://scripts/core/power.gd")
const Balance = preload("res://scripts/data/balance.gd")

const SNOW := Color(0.98, 0.99, 1.0)
const ICE := Color(0.70, 0.90, 1.0)
const GOLD := Color(1.0, 0.80, 0.2)
const SILVER := Color(0.85, 0.88, 0.95)
const HOVER: float = 1.0
const ICON_SCALE: float = 1.7     # uzaktan seçilsin diye simge büyük çizilir

var _nodes: Dictionary = {}       # Power -> {"root", "icon", "ring_mat"}
var _time: float = 0.0


func clear() -> void:
	for w in _nodes:
		_nodes[w]["root"].queue_free()
	_nodes.clear()


func sync(powers: Array, dt: float) -> void:
	_time += dt
	var alive := {}
	for w: Power in powers:
		alive[w] = true
		if not _nodes.has(w):
			_nodes[w] = _build(w)
		var e: Dictionary = _nodes[w]
		var root: Node3D = e["root"]
		var icon: Node3D = e["icon"]
		var phase := float(hash(w) % 100) * 0.1
		icon.position.y = HOVER + 0.1 * sin(_time * 3.0 + phase)
		icon.rotation.y += dt * 1.8
		var ring_mat: StandardMaterial3D = e["ring_mat"]
		ring_mat.albedo_color.a = 0.45 + 0.25 * sin(_time * 4.0 + phase)
		# belirirken zıplayarak büyür; son 3 sn yanıp söner
		var age := Balance.POWER_LIFE - w.life
		var s := 1.0
		if age < 0.4:
			var k := age / 0.4
			s = k * (1.0 + 0.4 * sin(k * PI))
		root.scale = Vector3.ONE * maxf(s, 0.01)
		root.visible = w.life > Balance.POWER_BLINK or fmod(w.life, 0.25) > 0.1
	for w in _nodes.keys():
		if not alive.has(w):
			_nodes[w]["root"].queue_free()
			_nodes.erase(w)


func _build(w: Power) -> Dictionary:
	var color: Color = Balance.POWERS[w.type]["color"]
	var root := Node3D.new()
	root.position = Vector3(w.pos.x, 0, w.pos.y)
	add_child(root)
	# parlayan halka ve yerde renkli bir leke
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(color, 0.6)
	var ring := MeshInstance3D.new()
	ring.mesh = Kit.torus(0.8, 1.0)
	ring.material_override = ring_mat
	ring.scale = Vector3(0.7, 0.25, 0.7)
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var spot := MeshInstance3D.new()
	spot.mesh = Kit.cylinder(1.0, 1.0, 0.01, 20)
	spot.material_override = ring_mat
	spot.scale = Vector3(0.5, 1, 0.5)
	spot.position.y = 0.02
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(spot)

	var icon := Node3D.new()
	icon.position.y = HOVER
	root.add_child(icon)
	var inner := Node3D.new()
	inner.scale = Vector3.ONE * ICON_SCALE
	icon.add_child(inner)
	_build_icon(inner, w.type, color)
	Kit.bake(inner)
	return {"root": root, "icon": icon, "ring_mat": ring_mat}


func _build_icon(icon: Node3D, type: String, color: Color) -> void:
	Kit.outline = 0.02
	match type:
		"uclu":
			# yelpaze gibi dizilmiş üç kartopu, altında altın bir bant
			for i in 3:
				var a := (i - 1) * 0.55
				Kit.part(icon, Kit.sphere(0.13, 12, 6), SNOW, Vector3(sin(a) * 0.26, cos(a) * 0.12 - 0.04, 0))
			Kit.part(icon, Kit.box(Vector3(0.5, 0.06, 0.12)), color, Vector3(0, -0.17, 0))
		"buz":
			# eğik duran buz küpü, içinde açık renk parıltı
			Kit.part(icon, Kit.box(Vector3(0.32, 0.32, 0.32)), ICE, Vector3.ZERO, Vector3(30, 0, 35))
			Kit.outline = 0.0
			Kit.part(icon, Kit.box(Vector3(0.12, 0.05, 0.34)), Color.WHITE, Vector3(-0.05, 0.08, 0.0), Vector3(30, 0, 35), Vector3.ONE, false)
		"kure":
			# kalp: iki yuvarlak + aşağı bakan koni
			Kit.part(icon, Kit.sphere(0.13, 14, 7), color, Vector3(-0.1, 0.06, 0))
			Kit.part(icon, Kit.sphere(0.13, 14, 7), color, Vector3(0.1, 0.06, 0))
			Kit.part(icon, Kit.cylinder(0.0, 0.2, 0.26, 14), color, Vector3(0, -0.1, 0), Vector3(180, 0, 0), Vector3(1, 1, 0.65))
			Kit.outline = 0.0
			Kit.part(icon, Kit.sphere(0.04, 8, 4), Color.WHITE, Vector3(-0.13, 0.12, 0.09), Vector3.ZERO, Vector3.ONE, false)
		"kalkan":
			# yuvarlak kalkan: renkli yüz, altın kenar, ortada beyaz kartopu
			Kit.part(icon, Kit.cylinder(0.24, 0.24, 0.06, 24), color, Vector3.ZERO, Vector3(90, 0, 0))
			Kit.part(icon, Kit.torus(0.22, 0.28), GOLD, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 0.6, 1))
			Kit.part(icon, Kit.sphere(0.08, 10, 5), SNOW, Vector3(0, 0, 0.04))
		"miknatis":
			# U biçiminde mıknatıs: kırmızı kollar, gümüş uçlar
			for side in [-1.0, 1.0]:
				Kit.part(icon, Kit.box(Vector3(0.09, 0.24, 0.09)), color, Vector3(side * 0.12, 0.02, 0))
				Kit.part(icon, Kit.box(Vector3(0.095, 0.08, 0.095)), SILVER, Vector3(side * 0.12, 0.18, 0))
			Kit.part(icon, Kit.box(Vector3(0.33, 0.09, 0.09)), color, Vector3(0, -0.14, 0))
		"yagmur":
			# kabarık bulut ve altında düşen kartopları
			for p in [Vector3(-0.14, 0.04, 0), Vector3(0.0, 0.1, 0), Vector3(0.15, 0.04, 0), Vector3(0.0, 0.0, 0.06)]:
				Kit.part(icon, Kit.sphere(0.12, 12, 6), SNOW, p)
			Kit.part(icon, Kit.box(Vector3(0.36, 0.05, 0.1)), color, Vector3(0, -0.06, 0))
			for x in [-0.12, 0.0, 0.12]:
				Kit.part(icon, Kit.sphere(0.04, 8, 4), ICE, Vector3(x, -0.2 - absf(x) * 0.4, 0))
	Kit.outline = 0.0
