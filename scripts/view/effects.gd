extends Node3D
## Anlık efektler:
##   burst(): kartopu çarpınca saçılan kar parçacıkları
##   splat_mark(): kartopunun yere düştüğü yerde birkaç saniyede kaybolan kar lekesi
##   text(): yukarı süzülüp kaybolan yazı ("Süper!", "+3")
## Her biri havuzdan kullanılır: oyun sırasında yeni düğüm oluşturulmaz.

const Kit = preload("res://scripts/view/mesh_kit.gd")

const BURST_POOL: int = 10
const MARK_POOL: int = 40
const MARK_LIFE: float = 5.0
const TEXT_POOL: int = 10
const TEXT_LIFE: float = 0.9
const OUTLINE := Color(0.16, 0.20, 0.32)

var _bursts: Array = []
var _next_burst: int = 0
var _marks: MultiMeshInstance3D
var _mark_ages := PackedFloat32Array()
var _mark_scales := PackedFloat32Array()
var _next_mark: int = 0
var _texts: Array = []          # [Label3D, yaş, başlangıç konumu]
var _next_text: int = 0


func _ready() -> void:
	_build_bursts()
	_build_marks()
	_build_texts()


func _process(dt: float) -> void:
	_update_marks(dt)
	_update_texts(dt)
	_update_debris(dt)


# ---------- Haylaz dağılınca uçuşan parçalar ----------

const DEBRIS_LIFE: float = 1.4
const CARROT := Color(1.0, 0.52, 0.12)
var _debris: Array = []         # [MeshInstance3D, hız, dönüş, yaş, yarıçap]


## Kardan adam dağıldı: kar topakları, şapkası ve havucu havaya saçılır, yere seker, küçülüp kaybolur.
func debris(pos: Vector3, size: float, hat_color: Color, push: Vector3) -> void:
	var items: Array = []
	for i in 4:
		var r := randf_range(0.13, 0.22) * size
		items.append([Kit.sphere(1.0, 10, 5), Color(0.97, 0.98, 1.0), Vector3.ONE * r, r])
	items.append([Kit.cylinder(0.75, 1.0, 0.8, 12), hat_color, Vector3.ONE * 0.24 * size, 0.18 * size])
	items.append([Kit.cylinder(0.0, 0.06, 0.3, 8), CARROT, Vector3.ONE * size, 0.06 * size])
	for it: Array in items:
		var mi := MeshInstance3D.new()
		mi.mesh = it[0]
		mi.material_override = Kit.mat(it[1], 0.1 if it[1] != CARROT else 0.0)
		mi.scale = it[2]
		mi.position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.5, 1.5) * size, randf_range(-0.3, 0.3))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var a := randf() * TAU
		var vel := Vector3(cos(a), 0, sin(a)) * randf_range(1.2, 3.2) + push * 1.5 + Vector3(0, randf_range(3.5, 6.0), 0)
		var spin := Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		_debris.append([mi, vel, spin, 0.0, it[3], it[2]])


func _update_debris(dt: float) -> void:
	var keep: Array = []
	for d: Array in _debris:
		var mi: MeshInstance3D = d[0]
		var vel: Vector3 = d[1]
		var age: float = d[3] + dt
		var r: float = d[4]
		vel.y -= 14.0 * dt
		mi.position += vel * dt
		if mi.position.y < r:
			mi.position.y = r
			vel.y = absf(vel.y) * 0.35
			vel.x *= 0.6
			vel.z *= 0.6
		mi.rotation += (d[2] as Vector3) * dt * (1.0 if mi.position.y > r + 0.01 else 0.2)
		var base: Vector3 = d[5]
		if age > DEBRIS_LIFE - 0.35:
			mi.scale = base * clampf((DEBRIS_LIFE - age) / 0.35, 0.0, 1.0)
		d[1] = vel
		d[3] = age
		if age >= DEBRIS_LIFE:
			mi.queue_free()
		else:
			keep.append(d)
	_debris = keep


# ---------- Kar patlaması ----------

func _build_bursts() -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	for i in BURST_POOL:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 14
		p.lifetime = 0.55
		p.explosiveness = 1.0
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.1
		p.direction = Vector3.UP
		p.spread = 75.0
		p.initial_velocity_min = 1.6
		p.initial_velocity_max = 3.6
		p.gravity = Vector3(0, -9.0, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		p.scale_amount_curve = curve
		p.mesh = Kit.sphere(0.06, 8, 4)
		p.material_override = Kit.mat(Color(0.98, 0.99, 1.0))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_bursts.append(p)


## Düşük kalitede kar patlamaları daha az parçacıkla çizilir.
var light_mode: bool = false


func burst(pos: Vector3, big: bool = false) -> void:
	var p: CPUParticles3D = _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % BURST_POOL
	p.global_position = pos
	p.amount = (24 if big else 14) / (2 if light_mode else 1)
	p.initial_velocity_max = 4.5 if big else 3.6
	p.restart()


# ---------- Yerdeki kar lekeleri ----------

func _build_marks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Kit.cylinder(1.0, 1.0, 0.01, 14)
	mm.instance_count = MARK_POOL
	_marks = MultiMeshInstance3D.new()
	_marks.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marks.material_override = m
	_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marks)
	_mark_ages.resize(MARK_POOL)
	_mark_scales.resize(MARK_POOL)
	for i in MARK_POOL:
		_mark_ages[i] = MARK_LIFE
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		mm.set_instance_color(i, Color(1, 1, 1, 0))


func splat_mark(pos: Vector2) -> void:
	var i := _next_mark
	_next_mark = (_next_mark + 1) % MARK_POOL
	_mark_ages[i] = 0.0
	_mark_scales[i] = randf_range(0.28, 0.4)
	_set_mark(i, pos)


func clear_marks() -> void:
	for i in MARK_POOL:
		_mark_ages[i] = MARK_LIFE
		_marks.multimesh.set_instance_color(i, Color(1, 1, 1, 0))


func _set_mark(i: int, pos: Vector2) -> void:
	var s := _mark_scales[i]
	var b := Basis(Vector3.UP, randf() * TAU) * Basis.from_scale(Vector3(s * 1.2, 1, s))
	_marks.multimesh.set_instance_transform(i, Transform3D(b, Vector3(pos.x, 0.014, pos.y)))


func _update_marks(dt: float) -> void:
	for i in MARK_POOL:
		if _mark_ages[i] >= MARK_LIFE:
			continue
		_mark_ages[i] += dt
		var t := _mark_ages[i] / MARK_LIFE
		# ilk anda biraz büyüyerek yayılır, sonra yavaşça kaybolur
		var c := Color(1.0, 1.0, 1.0, 0.95 * (1.0 - t * t))
		_marks.multimesh.set_instance_color(i, c)


# ---------- Uçan yazı ----------

func _build_texts() -> void:
	for i in TEXT_POOL:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.0065
		l.font_size = 72
		l.outline_size = 22
		l.outline_modulate = OUTLINE
		l.render_priority = 10
		l.outline_render_priority = 9
		l.visible = false
		add_child(l)
		_texts.append([l, TEXT_LIFE, Vector3.ZERO])


func text(pos: Vector3, txt: String, color: Color) -> void:
	var e: Array = _texts[_next_text]
	_next_text = (_next_text + 1) % TEXT_POOL
	var l: Label3D = e[0]
	l.text = txt
	l.modulate = color
	l.visible = true
	e[1] = 0.0
	# art arda gelen yazılar üst üste binmesin
	e[2] = pos + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.4), 0)


func _update_texts(dt: float) -> void:
	for e: Array in _texts:
		var age: float = e[1]
		if age >= TEXT_LIFE:
			continue
		age += dt
		e[1] = age
		var l: Label3D = e[0]
		var t := age / TEXT_LIFE
		var start: Vector3 = e[2]
		l.position = start + Vector3(0, 1.1 * (1.0 - pow(1.0 - t, 2.0)), 0)
		# önce zıplayarak büyür, sonra kaybolur
		var s := 0.6 + 0.6 * sin(minf(t * 3.0, 1.0) * PI * 0.5) - 0.2 * minf(t * 3.0, 1.0)
		l.scale = Vector3.ONE * s
		var a := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
		l.modulate.a = a
		l.outline_modulate.a = a
		if age >= TEXT_LIFE:
			l.visible = false
