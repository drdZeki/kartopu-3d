extends Node3D
## Kardan adamın 3D görüntüsü: basit şekillerden (küre, silindir, koni) yapılır.
## Kural durumunu okuyup çizer: konum, baktığı yön, yürüme.
## Canlı hareketler: nefes alma, göz kırpma, kol sallama, yürürken zıplama ve yalpalama.
## Model boyut 1,0 için ölçülüdür: gövde yarıçapı 0,5 m, boy ~2 m. Ön yüzü +z'ye bakar.
## Çocuklara sevimli gelsin diye kafa iri, gözler parlak, yanaklar pembe.

const Kit = preload("res://scripts/view/mesh_kit.gd")

const SNOW := Color(0.97, 0.98, 1.0)
const SNOW_BASE := Color(0.88, 0.92, 0.99)
const COAL := Color(0.10, 0.11, 0.16)
const CARROT := Color(1.0, 0.52, 0.12)
const STICK := Color(0.47, 0.31, 0.19)
const CHEEK := Color(1.0, 0.58, 0.64)
const SHINE := Color(1, 1, 1)
const HOLLY := Color(0.16, 0.55, 0.30)
const BERRY := Color(0.88, 0.12, 0.18)

const OUTLINE_BODY: float = 0.022   # büyük parçaların kontur kalınlığı (m)
const OUTLINE_SMALL: float = 0.012  # küçük parçaların kontur kalınlığı

const HEAD_Y: float = 1.60          # kafa merkezinin yüksekliği
const HEAD_R: float = 0.37

const WALK_FREQ: float = 11.0       # yürürken adım hızı
const WALK_BOB: float = 0.07        # zıplama yüksekliği (m)
const WALK_TILT: float = 0.13       # sağa sola yalpalama (radyan)
const TURN_SPEED: float = 14.0      # dönme yumuşaklığı
const ARM_REST: float = 0.45        # kolların dinlenirken yukarı açısı (radyan)

var _body: Node3D
var _head: Node3D
var _eyes: Array = []
var _arm_l: Node3D
var _arm_r: Node3D
var _size: float = 1.0
var _walk_phase: float = 0.0
var _walk_amount: float = 0.0
var _time: float = 0.0
var _blink_timer: float = 2.0
var _blink_left: float = 0.0


## data: Balance.CHARACTERS içinden bir karakter.
func build(data: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_eyes.clear()
	_size = data["size"]
	var color: Color = data["color"]
	var hat: String = data["hat"]
	_time = randf() * 10.0   # yan yana duran kardan adamlar aynı anda nefes almasın

	_body = Node3D.new()
	_body.scale = Vector3.ONE * _size
	add_child(_body)

	# ayağının altında küçük kar birikintisi (yere oturmuş görünsün)
	Kit.outline = 0.0
	Kit.part(_body, Kit.sphere(1.0, 20, 6), SNOW_BASE, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(0.62, 0.14, 0.62), false)

	# gövde: iki kar topu
	Kit.outline = OUTLINE_BODY
	Kit.part(_body, Kit.sphere(0.50, 24, 12), SNOW, Vector3(0, 0.47, 0), Vector3.ZERO, Vector3(1, 0.94, 1))
	Kit.part(_body, Kit.sphere(0.34, 24, 12), SNOW, Vector3(0, 1.07, 0))

	# kömür düğmeler (biri alttaki topta)
	Kit.outline = 0.0
	var button := Kit.sphere(0.045, 10, 5)
	Kit.part(_body, button, COAL, Vector3(0, 1.19, 0.315), Vector3.ZERO, Vector3(1, 1, 0.7), false)
	Kit.part(_body, button, COAL, Vector3(0, 1.05, 0.335), Vector3.ZERO, Vector3(1, 1, 0.7), false)
	Kit.part(_body, button, COAL, Vector3(0, 0.74, 0.40), Vector3.ZERO, Vector3(1, 1, 0.7), false)

	_arm_l = _build_arm(-1.0, color)
	_arm_r = _build_arm(1.0, color)
	_build_scarf(color)
	_build_head(color, hat)
	Kit.outline = 0.0

	# hareket eden her parça grubunu tek şekle birleştir (çizim sayısı ~55'ten ~15'e iner)
	Kit.bake(_body, [_head, _arm_l, _arm_r])
	Kit.bake(_head, _eyes)
	Kit.bake(_arm_l)
	Kit.bake(_arm_r)
	for eye: Node3D in _eyes:
		Kit.bake(eye)


# ---------- Parçalar ----------

## side: -1 sol, +1 sağ. Kol omuzdan döner (pivot).
func _build_arm(side: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.27 * side, 1.15, 0.0)
	_body.add_child(pivot)
	Kit.outline = OUTLINE_SMALL
	# dal: silindir yatırılıp omuzdan dışarı uzanır
	Kit.part(pivot, Kit.cylinder(0.022, 0.032, 0.46, 6), STICK, Vector3(0.25 * side, 0, 0), Vector3(0, 0, 90))
	# küçük yan dal
	Kit.part(pivot, Kit.cylinder(0.012, 0.018, 0.14, 5), STICK, Vector3(0.33 * side, 0.05, 0), Vector3(0, 0, -35 * side))
	# eldiven: avuç + başparmak
	Kit.part(pivot, Kit.sphere(0.075, 12, 6), color, Vector3(0.50 * side, 0, 0), Vector3.ZERO, Vector3(1.1, 1, 0.9))
	Kit.part(pivot, Kit.sphere(0.035, 8, 4), color, Vector3(0.47 * side, 0.06, 0.03))
	return pivot


func _build_scarf(color: Color) -> void:
	Kit.outline = OUTLINE_SMALL
	var stripe := color.lightened(0.55)
	Kit.part(_body, Kit.torus(0.22, 0.34), color, Vector3(0, 1.33, 0), Vector3.ZERO, Vector3(1, 1.2, 1))
	# sarkan uç, üstünde iki açık renk çizgi ve püsküller
	var tail := Node3D.new()
	tail.position = Vector3(0.17, 1.26, 0.25)
	tail.rotation_degrees = Vector3(12, 0, 14)
	_body.add_child(tail)
	Kit.part(tail, Kit.box(Vector3(0.13, 0.34, 0.05)), color, Vector3(0, -0.17, 0))
	Kit.outline = 0.0
	for y in [-0.12, -0.24]:
		Kit.part(tail, Kit.box(Vector3(0.135, 0.045, 0.055)), stripe, Vector3(0, y, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 3:
		Kit.part(tail, Kit.box(Vector3(0.025, 0.06, 0.03)), color, Vector3(-0.045 + i * 0.045, -0.37, 0), Vector3.ZERO, Vector3.ONE, false)


func _build_head(color: Color, hat: String) -> void:
	_head = Node3D.new()
	_head.position = Vector3(0, HEAD_Y, 0)
	_body.add_child(_head)
	Kit.outline = OUTLINE_BODY
	Kit.part(_head, Kit.sphere(HEAD_R, 24, 12), SNOW, Vector3.ZERO)

	# gözler: iri kömür + beyaz parıltı. Göz kırpmak için her göz kendi düğümünde.
	Kit.outline = 0.0
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = _on_head(0.125 * side, 0.07, -0.01)
		_head.add_child(eye)
		Kit.part(eye, Kit.sphere(0.068, 14, 7), COAL, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.12, 0.55), false)
		var shine := Kit.part(eye, Kit.sphere(0.022, 8, 4), SHINE, Vector3(0.022, 0.03, 0.035), Vector3.ZERO, Vector3.ONE, false)
		shine.material_override = Kit.glow(SHINE)
		_eyes.append(eye)
	# pembe yanaklar
	for side in [-1.0, 1.0]:
		Kit.part(_head, Kit.sphere(0.065, 12, 6), CHEEK, _on_head(0.215 * side, -0.06, -0.012),
			Vector3(0, 30 * side, 0), Vector3(1, 0.62, 0.3), false)
	# gülümseyen ağız: yay biçiminde küçük kömürler
	var dot := Kit.sphere(0.024, 8, 4)
	for i in 5:
		var t := (i - 2) / 2.0                  # -1 .. 1
		Kit.part(_head, dot, COAL, _on_head(t * 0.1, -0.13 + t * t * 0.035, -0.008), Vector3.ZERO, Vector3.ONE, false)
	# havuç burun: hafif aşağı bakan koni, üstünde ince çizgiler
	Kit.outline = OUTLINE_SMALL
	var nose := Kit.part(_head, Kit.cylinder(0.0, 0.06, 0.32, 10), CARROT, Vector3(0, -0.01, HEAD_R + 0.13), Vector3(95, 0, 0))
	nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_build_hat(hat, color)


## Kafa yüzeyinde, merkezden (x, y) kadar kaymış noktayı verir. push: yüzeyden dışarı (+) / içeri (-).
func _on_head(x: float, y: float, push: float) -> Vector3:
	var r := HEAD_R + push
	var z := sqrt(maxf(0.0, r * r - x * x - y * y))
	return Vector3(x, y, z)


func _build_hat(hat: String, color: Color) -> void:
	Kit.outline = OUTLINE_SMALL
	var dark := color.darkened(0.25)
	match hat:
		"top":
			# silindir şapka: siyah, karakter renginde bant, yanında çobanpüskülü
			Kit.part(_head, Kit.cylinder(0.36, 0.36, 0.05, 24), COAL, Vector3(0, 0.30, 0), Vector3(-6, 0, 4))
			Kit.part(_head, Kit.cylinder(0.25, 0.23, 0.42, 24), COAL, Vector3(0.02, 0.52, -0.02), Vector3(-6, 0, 4))
			Kit.part(_head, Kit.cylinder(0.245, 0.24, 0.09, 24), color, Vector3(0.007, 0.37, -0.007), Vector3(-6, 0, 4))
			Kit.outline = 0.0
			for a in [-25.0, 25.0]:
				Kit.part(_head, Kit.sphere(0.07, 8, 4), HOLLY, Vector3(-0.16, 0.40, 0.17), Vector3(0, 40, a), Vector3(1.4, 0.35, 0.7), false)
			for p in [Vector3(-0.19, 0.40, 0.20), Vector3(-0.14, 0.42, 0.22), Vector3(-0.17, 0.36, 0.22)]:
				Kit.part(_head, Kit.sphere(0.03, 8, 4), BERRY, p, Vector3.ZERO, Vector3.ONE, false)
		"beanie":
			# bere: kafayı saran kubbe, kalın kıvrık kenar, kocaman ponpon
			Kit.part(_head, Kit.sphere(0.39, 24, 12), color, Vector3(0, 0.14, -0.01), Vector3(-8, 0, 0), Vector3(1, 0.82, 1))
			Kit.part(_head, Kit.torus(0.31, 0.42), dark, Vector3(0, 0.13, -0.01), Vector3(-8, 0, 0), Vector3(1, 1.3, 1))
			Kit.part(_head, Kit.sphere(0.12, 14, 7), SNOW, Vector3(0, 0.50, -0.06))
		"bucket":
			# ters kova, yana yatık, kenarı kalın
			Kit.part(_head, Kit.cylinder(0.23, 0.31, 0.38, 24), color, Vector3(0.03, 0.42, 0), Vector3(0, 0, -10))
			Kit.part(_head, Kit.torus(0.28, 0.34), dark, Vector3(0.0, 0.24, 0), Vector3(0, 0, -10))
			Kit.part(_head, Kit.cylinder(0.235, 0.235, 0.02, 24), dark, Vector3(0.065, 0.61, 0), Vector3(0, 0, -10))
		"cap":
			# kasket: yassı kubbe, öne uzanan siperlik, tepede düğme
			Kit.part(_head, Kit.sphere(0.385, 24, 12), color, Vector3(0, 0.17, -0.01), Vector3.ZERO, Vector3(1, 0.62, 1))
			Kit.part(_head, Kit.cylinder(0.24, 0.24, 0.04, 20), dark, Vector3(0, 0.19, 0.38), Vector3(-10, 0, 0), Vector3(1.05, 1, 1.0))
			Kit.part(_head, Kit.sphere(0.045, 8, 4), dark, Vector3(0, 0.41, -0.01))
		"ninja":
			# ninja bandı: alında bant, arkada düğüm ve uçuşan iki uç
			Kit.part(_head, Kit.torus(0.33, 0.40), color, Vector3(0, 0.12, 0), Vector3(-6, 0, 0), Vector3(1, 1.5, 1))
			Kit.part(_head, Kit.sphere(0.06, 10, 5), dark, Vector3(0, 0.10, -0.38))
			Kit.part(_head, Kit.box(Vector3(0.07, 0.26, 0.03)), color, Vector3(-0.06, -0.02, -0.43), Vector3(35, 0, 20))
			Kit.part(_head, Kit.box(Vector3(0.07, 0.26, 0.03)), color, Vector3(0.07, -0.04, -0.42), Vector3(35, 0, -25))
		"helmet":
			# şövalye miğferi: kafanın üst yarısını saran altın kubbe (yüz açık), kenar, tepede kırmızı tüyler
			var dome := SphereMesh.new()
			dome.radius = 0.40
			dome.height = 0.40
			dome.is_hemisphere = true
			dome.radial_segments = 24
			dome.rings = 8
			Kit.part(_head, dome, color, Vector3(0, 0.17, -0.02), Vector3(-6, 0, 0), Vector3(1, 1.15, 1))
			Kit.part(_head, Kit.torus(0.355, 0.43), dark, Vector3(0, 0.17, -0.02), Vector3(-6, 0, 0), Vector3(1, 1.1, 1))
			var plume := Color(0.86, 0.16, 0.22)
			for i in 4:
				Kit.part(_head, Kit.sphere(0.085 - i * 0.01, 10, 5), plume, Vector3(0, 0.64 - i * 0.04, -0.04 - i * 0.1))


# ---------- Hareket ----------

## Her karede çağrılır. walk_ratio: 0 = duruyor, 1 = tam hız.
func update_pose(pos: Vector3, facing: Vector2, walk_ratio: float, dt: float) -> void:
	_time += dt
	position = pos
	var yaw := atan2(facing.x, facing.y)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-TURN_SPEED * dt))

	var moving := walk_ratio > 0.05
	_walk_amount = lerpf(_walk_amount, 1.0 if moving else 0.0, 1.0 - exp(-10.0 * dt))
	if moving:
		_walk_phase += dt * WALK_FREQ * (0.6 + 0.4 * walk_ratio)
	elif _walk_amount < 0.02:
		_walk_phase = 0.0
	var step := sin(_walk_phase)
	var idle := 1.0 - _walk_amount

	# yürürken zıpla ve yalpala; dururken yavaşça nefes al
	var breathe := sin(_time * 2.2) * 0.018 * idle
	_body.position.y = absf(step) * WALK_BOB * _walk_amount * _size
	_body.rotation.z = step * WALK_TILT * _walk_amount
	_body.scale = Vector3(1.0 - breathe * 0.5, 1.0 + breathe, 1.0 - breathe * 0.5) * _size
	_head.rotation.z = -step * 0.08 * _walk_amount + sin(_time * 1.3) * 0.04 * idle

	# kollar: yürürken öne arkaya sallanır, dururken hafifçe el sallar
	var swing := step * 0.6 * _walk_amount
	var wave := sin(_time * 2.6) * 0.12 * idle
	_arm_l.rotation = Vector3(0, swing, -ARM_REST - wave)
	_arm_r.rotation = Vector3(0, swing, ARM_REST + wave * 0.4)

	_update_blink(dt)


func _update_blink(dt: float) -> void:
	_blink_timer -= dt
	if _blink_timer <= 0.0:
		_blink_left = 0.14
		_blink_timer = randf_range(2.0, 4.5)
	var squash := 1.0
	if _blink_left > 0.0:
		_blink_left -= dt
		squash = 0.12
	for eye: Node3D in _eyes:
		eye.scale.y = squash


## Yönü bir anda ayarlar (yeni oyun başında).
func snap_facing(facing: Vector2) -> void:
	rotation.y = atan2(facing.x, facing.y)
