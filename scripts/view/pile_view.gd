extends Node3D
## Kar yığınlarının görüntüsü: karlı bir tümseğin üstünde, içindeki sayı kadar kartopu dizilidir
## (kaç tane olduğu gözle görülsün). Yeni yığın zıplayarak belirir; çevresinde yavaşça
## parlayıp sönen bir halka vardır, kolay bulunsun.

const Kit = preload("res://scripts/view/mesh_kit.gd")
const Pile = preload("res://scripts/core/pile.gd")

const SNOW := Color(0.98, 0.99, 1.0)
const MOUND := Color(0.86, 0.91, 0.99)
const GLOW := Color(0.35, 0.78, 1.0)
const BALL_R: float = 0.17

var _nodes: Dictionary = {}       # Pile -> {"node": Node3D, "amount": int, "age": float}
var _glow_mat: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Color(GLOW, 0.4)


## Yeni harita: tüm yığın görüntüleri silinir.
func clear() -> void:
	for k in _nodes:
		_nodes[k]["node"].queue_free()
	_nodes.clear()


## Her karede çağrılır: kuraldaki yığınlarla görüntüyü eşitler.
func sync(piles: Array, dt: float) -> void:
	_time += dt
	_glow_mat.albedo_color = Color(GLOW, 0.5 + 0.3 * sin(_time * 3.0))
	var alive := {}
	for p: Pile in piles:
		alive[p] = true
		if not _nodes.has(p):
			_nodes[p] = {"node": _build(p), "amount": p.amount, "age": 0.0}
		elif _nodes[p]["amount"] != p.amount:
			_nodes[p]["node"].queue_free()
			_nodes[p] = {"node": _build(p), "amount": p.amount, "age": 1.0}
		var e: Dictionary = _nodes[p]
		e["age"] += dt
		e["node"].position = Vector3(p.pos.x, 0, p.pos.y)   # Kar Mıknatısı yığınları kaydırabilir
		# zıplayarak belirme: biraz büyüyüp yerine oturur
		var a: float = e["age"]
		var s := 1.0
		if a < 0.45:
			var k := a / 0.45
			s = k * (1.0 + 0.35 * sin(k * PI))
		e["node"].scale = Vector3.ONE * maxf(s, 0.01)
	for p in _nodes.keys():
		if not alive.has(p):
			_nodes[p]["node"].queue_free()
			_nodes.erase(p)


func _build(p: Pile) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(p.pos.x, 0, p.pos.y)
	root.rotation.y = float(hash(p) % 628) / 100.0
	add_child(root)
	var r := p.radius()
	var body := Node3D.new()
	root.add_child(body)
	Kit.outline = 0.0
	Kit.part(body, Kit.sphere(1.0, 16, 6), MOUND, Vector3(0, 0, 0), Vector3.ZERO, Vector3(r * 1.05, 0.16, r * 1.05), false)
	Kit.outline = 0.018
	for q in _ball_layout(p.amount):
		Kit.part(body, Kit.sphere(BALL_R, 12, 6), SNOW, q)
	Kit.outline = 0.0
	Kit.bake(body)
	# parlayan halka
	var ring := MeshInstance3D.new()
	ring.mesh = Kit.torus(0.82, 1.0)
	ring.material_override = _glow_mat
	ring.scale = Vector3(r + 0.25, 0.25, r + 0.25)
	ring.position.y = 0.02
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	return root


## Kartopu sayısına göre dizilim: alt sırada halka, üstte tepe.
static func _ball_layout(n: int) -> Array:
	var out: Array = []
	var y := 0.12 + BALL_R * 0.6
	match n:
		1:
			out.append(Vector3(0, y, 0))
		2:
			out.append(Vector3(-0.15, y, 0))
			out.append(Vector3(0.15, y, 0))
		_:
			var bottom := n - 1 if n >= 4 else n
			var ring_r := 0.13 + 0.035 * bottom
			for i in bottom:
				var a := TAU * i / bottom
				out.append(Vector3(cos(a) * ring_r, y, sin(a) * ring_r))
			if n >= 4:
				out.append(Vector3(0, y + BALL_R * 1.45, 0))
	return out
