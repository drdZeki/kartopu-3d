extends Node3D
## Kartopu azalınca (SPEC §8) kardan adamın ayağının dibinde en yakın kar yığınını gösteren,
## o yöne doğru zıplayan turuncu ok.

const Kit = preload("res://scripts/view/mesh_kit.gd")

const COLOR := Color(1.0, 0.58, 0.16)
## Okun oyuncunun merkezinden uzaklığı. Eğik kamerada 2 m boyundaki kardan adam yerde ~1,4 m
## kuzeyi kapatır; ok en üste çizildiği için bundan uzakta durmalı, yoksa kafasının üstüne biner.
const DIST: float = 1.75
const NEAR: float = 2.4           # yığın bundan yakınsa ok gerekmez
const SIZE: float = 1.7

var _arrow: Node3D
var _shown: float = 0.0           # 0 = gizli, 1 = tam görünür (yumuşak geçiş)
var _time: float = 0.0


func _ready() -> void:
	_arrow = Node3D.new()
	add_child(_arrow)
	Kit.outline = 0.02
	# ok +z yönüne bakar: gövde + üçgen uç
	Kit.part(_arrow, Kit.box(Vector3(0.14, 0.05, 0.32)), COLOR, Vector3(0, 0, -0.08), Vector3.ZERO, Vector3.ONE, false)
	# 3 köşeli silindir = üçgen; Godot'da ilk köşesi +z'de, yani sivri ucu zaten ileri bakar
	Kit.part(_arrow, Kit.cylinder(0.24, 0.24, 0.05, 3), COLOR, Vector3(0, 0, 0.1), Vector3.ZERO, Vector3(1, 1, 1.1), false)
	Kit.outline = 0.0
	Kit.bake(_arrow)
	# ok çalı ya da ağaç arkasında kalsa da görünsün: derinliğe bakmadan en üste çizilir
	for c in _arrow.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.no_depth_test = true
		m.render_priority = 2
		if m.next_pass != null:
			var o := (m.next_pass as StandardMaterial3D).duplicate() as StandardMaterial3D
			o.no_depth_test = true
			o.render_priority = 1
			m.next_pass = o
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scale = Vector3.ZERO


## target: en yakın yığının konumu; null ise ok kaybolur.
func update_arrow(player_pos: Vector2, target: Variant, dt: float) -> void:
	_time += dt
	var want := 0.0
	if target != null:
		var tp: Vector2 = target
		if tp.distance_to(player_pos) > NEAR:
			want = 1.0
	_shown = move_toward(_shown, want, dt * 5.0)
	scale = Vector3.ONE * _shown * SIZE
	visible = _shown > 0.01
	if target == null:
		return
	var t: Vector2 = target
	var dir := (t - player_pos)
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var bob := 0.18 * absf(sin(_time * 5.0))
	# kuzeyi gösterirken (ekranın yukarısı) kardan adamın kafasının üstüne binmesin: biraz daha uzağa
	var dist := DIST + 0.9 * maxf(0.0, -dir.y)
	var p := player_pos + dir * (dist + bob)
	position = Vector3(p.x, 0.1, p.y)
	rotation.y = atan2(dir.x, dir.y)
