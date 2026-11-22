extends MultiMeshInstance3D
## Karda iz: kardan adam yürürken her zıplayışında karda yuvarlak bir iz kalır,
## iz birkaç saniyede yavaşça kaybolur. Tüm izler tek çizimle çizilir.
## İleride Haylazlar da iz bırakabilsin diye her kardan adam için ayrı çağrılabilir.

const MAX_PRINTS: int = 90
const STEP: float = 0.55          # iki iz arası (m, boyut 1,0 için)
const LIFE: float = 7.0           # izin kaybolma süresi (sn)
const COLOR := Color(0.58, 0.68, 0.88)
const ALPHA: float = 0.5

var _ages := PackedFloat32Array()
var _next: int = 0
var _walked: Dictionary = {}       # kardan adam kimliği -> son izden beri yürünen mesafe
var _last: Dictionary = {}         # kardan adam kimliği -> son konum


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	disc.radial_segments = 16
	disc.rings = 1
	mm.mesh = disc
	mm.instance_count = MAX_PRINTS
	multimesh = mm

	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_ages.resize(MAX_PRINTS)
	for i in MAX_PRINTS:
		_ages[i] = LIFE
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		mm.set_instance_color(i, Color(COLOR, 0.0))


## Her karede çağrılır. id: kardan adamın kimliği, size: boyutu.
func track(id: int, pos: Vector2, facing: Vector2, size: float, moving: bool) -> void:
	var last: Vector2 = _last.get(id, pos)
	_last[id] = pos
	if not moving:
		return
	var walked: float = _walked.get(id, STEP * size) + pos.distance_to(last)
	if walked >= STEP * size:
		walked = 0.0
		_add_print(pos, facing, size)
	_walked[id] = walked


## Tüm izler silinir (yeni harita).
func clear() -> void:
	for i in MAX_PRINTS:
		_ages[i] = LIFE
		multimesh.set_instance_color(i, Color(COLOR, 0.0))
	_walked.clear()
	_last.clear()


func _process(dt: float) -> void:
	for i in MAX_PRINTS:
		if _ages[i] >= LIFE:
			continue
		_ages[i] += dt
		var t := _ages[i] / LIFE
		multimesh.set_instance_color(i, Color(COLOR, ALPHA * (1.0 - t * t)))


func _add_print(pos: Vector2, facing: Vector2, size: float) -> void:
	var yaw := atan2(facing.x, facing.y)
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.30 * size, 1.0, 0.36 * size))
	multimesh.set_instance_transform(_next, Transform3D(b, Vector3(pos.x, 0.012, pos.y)))
	multimesh.set_instance_color(_next, Color(COLOR, ALPHA))
	_ages[_next] = 0.0
	_next = (_next + 1) % MAX_PRINTS
