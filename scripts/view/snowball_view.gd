extends Node3D
## Uçan kartoplarının görüntüsü. Kural tarafında kartopu düz gider; burada elden çıkıp
## hafif bir yay çizerek yere doğru iner. Altında yerde küçük bir gölge olur.
## Tüm kartopları tek çizimle (MultiMesh) çizilir.

const Kit = preload("res://scripts/view/mesh_kit.gd")
const Snowball = preload("res://scripts/core/snowball.gd")

const MAX_BALLS: int = 64
const HAND_HEIGHT: float = 1.25   # elden çıkış yüksekliği (boyut 1,0)
const END_HEIGHT: float = 0.2     # menzilin sonundaki yükseklik
const ARC: float = 0.45           # yayın tepesi
const VISUAL_SCALE: float = 1.4   # kartopu ekranda kolay görünsün diye kuraldakinden biraz iri çizilir
const SNOW := Color(0.98, 0.99, 1.0)
const SHADOW := Color(0.35, 0.45, 0.7, 0.35)

const ENEMY := Color(0.58, 0.80, 1.0)   # Haylaz kartopları açık mavi: oyuncununkilerden ayrılsın

const FREEZE := Color(0.55, 0.92, 1.0)  # Buz Topu güçlendirmesiyle atılan kartopları buz mavisi

var _balls: MultiMeshInstance3D
var _enemy_balls: MultiMeshInstance3D
var _ice_balls: MultiMeshInstance3D
var _shadows: MultiMeshInstance3D


func _ready() -> void:
	_balls = _make(Kit.sphere(1.0, 14, 7), Kit.mat(SNOW, 0.12))
	_balls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_enemy_balls = _make(Kit.sphere(1.0, 14, 7), Kit.mat(ENEMY, 0.12))
	_enemy_balls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ice_balls = _make(Kit.sphere(1.0, 8, 4), Kit.mat(FREEZE, 0.12))   # köşeli: buz kristali gibi
	_ice_balls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = SHADOW
	_shadows = _make(Kit.cylinder(1.0, 1.0, 0.01, 12), shadow_mat)
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make(mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = MAX_BALLS
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	add_child(inst)
	return inst


## Uçuşun ilerleyişine (0–1) göre görsel yükseklik.
static func height_at(t: float) -> float:
	return lerpf(HAND_HEIGHT, END_HEIGHT, t * t) + ARC * sin(PI * t)


## Her karede çağrılır. f: iki kural adımı arasındaki oran (yumuşatma).
func sync(balls: Array, f: float) -> void:
	var n := mini(balls.size(), MAX_BALLS)
	var mine := 0
	var theirs := 0
	var icy := 0
	for i in n:
		var b: Snowball = balls[i]
		var p := b.prev_pos.lerp(b.pos, f)
		var h := height_at(b.progress())
		var r := b.radius * VISUAL_SCALE
		var t := Transform3D(Basis.from_scale(Vector3.ONE * r), Vector3(p.x, h, p.y))
		if b.freeze:
			_ice_balls.multimesh.set_instance_transform(icy, t.rotated_local(Vector3.UP, b.traveled * 3.0))
			icy += 1
		elif b.owner_id == 0:
			_balls.multimesh.set_instance_transform(mine, t)
			mine += 1
		else:
			_enemy_balls.multimesh.set_instance_transform(theirs, t)
			theirs += 1
		var s := r * (1.1 - 0.3 * clampf(h / 1.6, 0.0, 1.0))   # yükseldikçe gölge küçülür
		_shadows.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, 1, s)), Vector3(p.x, 0.015, p.y)))
	_balls.multimesh.visible_instance_count = mine
	_enemy_balls.multimesh.visible_instance_count = theirs
	_ice_balls.multimesh.visible_instance_count = icy
	_shadows.multimesh.visible_instance_count = n
