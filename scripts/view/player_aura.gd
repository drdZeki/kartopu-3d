extends Node3D
## Oyuncunun etkin güçlendirmelerinin görüntüsü (kardan adamın çevresinde):
##   kalkan:   kardan adamı saran, nabız gibi atan mavi baloncuk
##   yağmur:   kafasının üstünde süzülen, kar yağdıran küçük bulut
##   mıknatıs: ayağının altında dönen kırmızı-gümüş halka
##   buz:      göğsünün çevresinde dönen buz kristalleri
##   üçlü:     kafasının çevresinde dönen üç küçük altın kartopu
## Süresi bitmek üzereyken (son 2 sn) yanıp söner.

const Kit = preload("res://scripts/view/mesh_kit.gd")
const Balance = preload("res://scripts/data/balance.gd")

const SHIELD := Color(0.45, 0.62, 1.0)
const ICE := Color(0.70, 0.90, 1.0)
const GOLD := Color(1.0, 0.82, 0.25)

var _shield: MeshInstance3D
var _shield_mat: StandardMaterial3D
var _cloud: Node3D
var _snow: CPUParticles3D
var _magnet: Node3D
var _crystals: Node3D
var _triple: Node3D
var _seen: Node3D           # "Görüldün!" rozeti: kafanın üstünde gözlü kırmızı baloncuk
var _seen_ring: MeshInstance3D
var _time: float = 0.0


func _ready() -> void:
	_shield_mat = StandardMaterial3D.new()
	_shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_mat.albedo_color = Color(SHIELD, 0.22)
	# baloncuğun kenarında parlak bir halka (içi dışına çevrilmiş, biraz şişirilmiş kopya)
	var rim := StandardMaterial3D.new()
	rim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim.cull_mode = BaseMaterial3D.CULL_FRONT
	rim.grow = true
	rim.grow_amount = 0.06
	rim.albedo_color = Color(0.75, 0.88, 1.0, 0.85)
	_shield_mat.next_pass = rim
	_shield = MeshInstance3D.new()
	_shield.mesh = Kit.sphere(1.0, 24, 12)
	_shield.material_override = _shield_mat
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shield)

	_cloud = Node3D.new()
	add_child(_cloud)
	Kit.outline = 0.02
	for p in [Vector3(-0.28, 0, 0), Vector3(0, 0.12, 0), Vector3(0.28, 0, 0), Vector3(0.05, 0, 0.15), Vector3(-0.1, 0.02, -0.14)]:
		Kit.part(_cloud, Kit.sphere(0.22, 14, 7), Color(0.98, 0.98, 1.0), p, Vector3.ZERO, Vector3.ONE, false)
	Kit.outline = 0.0
	Kit.bake(_cloud)
	_snow = CPUParticles3D.new()
	_snow.amount = 16
	_snow.lifetime = 0.8
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(0.35, 0.05, 0.2)
	_snow.direction = Vector3.DOWN
	_snow.spread = 8.0
	_snow.gravity = Vector3(0, -3.0, 0)
	_snow.initial_velocity_min = 0.6
	_snow.initial_velocity_max = 1.0
	_snow.mesh = Kit.sphere(0.04, 6, 3)
	_snow.material_override = Kit.mat(ICE)
	_snow.position.y = -0.15
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud.add_child(_snow)

	_magnet = Node3D.new()
	add_child(_magnet)
	for i in 10:
		var a := TAU * i / 10.0
		var col := Color(0.95, 0.28, 0.35) if i % 2 == 0 else Color(0.88, 0.9, 0.96)
		var dash := Kit.part(_magnet, Kit.box(Vector3(0.32, 0.03, 0.1)), col, Vector3(cos(a) * 1.05, 0.04, sin(a) * 1.05), Vector3.ZERO, Vector3.ONE, false)
		dash.rotation.y = -a + PI * 0.5
	Kit.bake(_magnet)

	_crystals = Node3D.new()
	add_child(_crystals)
	Kit.outline = 0.015
	for i in 3:
		var a := TAU * i / 3.0
		Kit.part(_crystals, Kit.sphere(0.1, 4, 2), ICE, Vector3(cos(a) * 0.75, 0, sin(a) * 0.75), Vector3.ZERO, Vector3(0.8, 1.5, 0.8), false)
	Kit.outline = 0.0
	Kit.bake(_crystals)

	_triple = Node3D.new()
	add_child(_triple)
	Kit.outline = 0.015
	for i in 3:
		var a := TAU * i / 3.0
		Kit.part(_triple, Kit.sphere(0.09, 10, 5), GOLD, Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), Vector3.ZERO, Vector3.ONE, false)
	Kit.outline = 0.0
	Kit.bake(_triple)

	_seen = Node3D.new()
	add_child(_seen)
	Kit.outline = 0.02
	Kit.part(_seen, Kit.sphere(0.32, 16, 8), Color(0.93, 0.22, 0.28), Vector3.ZERO, Vector3.ZERO, Vector3(1.25, 0.9, 0.6), false)
	Kit.part(_seen, Kit.cylinder(0.0, 0.1, 0.18, 6), Color(0.93, 0.22, 0.28), Vector3(0, -0.3, 0), Vector3(180, 0, 0), Vector3.ONE, false)
	Kit.outline = 0.0
	for side in [-1.0, 1.0]:
		Kit.part(_seen, Kit.sphere(0.11, 12, 6), Color.WHITE, Vector3(side * 0.14, 0.02, 0.16), Vector3.ZERO, Vector3(1, 1.1, 0.5), false)
		Kit.part(_seen, Kit.sphere(0.05, 8, 4), Color(0.1, 0.1, 0.15), Vector3(side * 0.14 + 0.03, 0.0, 0.21), Vector3.ZERO, Vector3(1, 1, 0.5), false)
	Kit.bake(_seen)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.93, 0.22, 0.28)
	_seen_ring = MeshInstance3D.new()
	_seen_ring.mesh = Kit.torus(0.85, 1.0)
	_seen_ring.material_override = ring_mat
	_seen_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_seen_ring)
	update_aura(Vector3.ZERO, {}, 1.0, 0.0)


## Çalılıktayken görünür olunca (atış yaptı): kafanın üstünde gözlü rozet, ayağında yanıp sönen halka.
func set_seen(seen: bool, size: float) -> void:
	_seen.visible = seen
	_seen.position = Vector3(0, 2.75 * size + 0.06 * sin(_time * 8.0), 0)
	_seen.scale = Vector3.ONE * size
	_seen_ring.visible = seen and fmod(_time, 0.4) < 0.25
	_seen_ring.scale = Vector3(0.75 * size, 0.3, 0.75 * size)
	_seen_ring.position.y = 0.04


## powers: oyuncunun etkin güçlendirmeleri (tür -> kalan sn). size: kardan adamın boyutu.
func update_aura(pos: Vector3, powers: Dictionary, size: float, dt: float) -> void:
	_time += dt
	position = pos
	_show(_shield, powers, "kalkan")
	var r := Balance.PLAYER_BASE_RADIUS * size * Balance.SHIELD_FACTOR
	_shield.scale = Vector3(r, r * 1.15, r) * (1.0 + 0.03 * sin(_time * 6.0))
	_shield.position.y = 0.95 * size
	_shield_mat.albedo_color.a = 0.28 + 0.08 * sin(_time * 6.0)

	_show(_cloud, powers, "yagmur")
	_cloud.position = Vector3(0, 3.3 * size + 0.08 * sin(_time * 2.5), 0)
	_cloud.scale = Vector3.ONE * 1.25 * size
	_snow.emitting = _cloud.visible

	_show(_magnet, powers, "miknatis")
	_magnet.rotation.y = _time * 2.0
	_magnet.scale = Vector3.ONE * size

	_show(_crystals, powers, "buz")
	_crystals.position.y = 1.1 * size
	_crystals.rotation.y = -_time * 2.5
	_crystals.scale = Vector3.ONE * size

	_show(_triple, powers, "uclu")
	_triple.position.y = 2.35 * size
	_triple.rotation.y = _time * 3.0
	_triple.scale = Vector3.ONE * size


func _show(node: Node3D, powers: Dictionary, type: String) -> void:
	var left: float = powers.get(type, 0.0)
	node.visible = left > 0.0 and (left > 2.0 or fmod(left, 0.3) > 0.12)
