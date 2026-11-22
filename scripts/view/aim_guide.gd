extends Node3D
## Nişan çizgisi: sürükleyerek nişan alırken yerde, kartopunun gideceği yolu noktalarla gösterir.
## Kartopu bir engele çarpacaksa çizgi orada biter ve ucunda küçük bir çarpı belirir.

const Kit = preload("res://scripts/view/mesh_kit.gd")

const DOT_GAP: float = 0.7
const MAX_DOTS: int = 22
const COLOR := Color(1.0, 0.76, 0.22, 0.95)   # beyaz karda seçilsin diye turuncu-sarı
const END_COLOR := Color(1.0, 0.55, 0.2, 0.95)

var _dots: MultiMeshInstance3D
var _end: MeshInstance3D
var _time: float = 0.0


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Kit.cylinder(1.0, 1.0, 0.01, 12)
	mm.instance_count = MAX_DOTS
	mm.visible_instance_count = 0
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = COLOR
	Kit.register_outline(m, Kit._outline_mat(0.25), 0.25)
	_dots.material_override = m
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)

	_end = MeshInstance3D.new()
	_end.mesh = Kit.torus(0.75, 1.0)
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.albedo_color = END_COLOR
	_end.material_override = em
	_end.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_end)
	hide_aim()


## from: oyuncunun konumu, dir: atış yönü, length: kartopunun gidebileceği uzaklık.
func show_aim(from: Vector2, dir: Vector2, length: float, dt: float) -> void:
	_time += dt
	visible = true
	var shift := fmod(_time * 1.6, DOT_GAP)   # noktalar ileri doğru akar
	var n := 0
	var d := 0.8 + shift
	while d < length and n < MAX_DOTS:
		var p := from + dir * d
		var s := 0.11 * (1.0 - 0.35 * d / length)
		_dots.multimesh.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(s, 1, s)), Vector3(p.x, 0.03, p.y)))
		n += 1
		d += DOT_GAP
	_dots.multimesh.visible_instance_count = n
	var e := from + dir * length
	_end.position = Vector3(e.x, 0.035, e.y)
	var pulse := 0.3 + 0.05 * sin(_time * 10.0)
	_end.scale = Vector3(pulse, 0.4, pulse)


func hide_aim() -> void:
	visible = false
	_time = 0.0
