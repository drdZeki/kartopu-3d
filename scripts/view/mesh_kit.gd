extends RefCounted
## Paylaşılan basit 3D şekiller ve renkler.
## Aynı şekil ya da renk bir kez oluşturulur ve tekrar kullanılır (telefon için hafif).

const OUTLINE_COLOR := Color(0.16, 0.20, 0.32)  # kontur rengi: koyu lacivert (siyahtan yumuşak)

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## Çizgi film tarzı malzeme: ışık yumuşak iki tonlu (aydınlık / gölge).
## outline > 0 verilirse çevresine o kalınlıkta (m) koyu kontur çizilir.
static func mat(color: Color, outline: float = 0.0) -> StandardMaterial3D:
	var key := "%s/%.3f" % [color.to_html(), outline]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if outline > 0.0:
			m.next_pass = _outline_mat(outline)
		_materials[key] = m
	return _materials[key]


## Kontur: şeklin biraz şişirilmiş, içi dışına çevrilmiş koyu kopyası.
static func _outline_mat(width: float) -> StandardMaterial3D:
	var key := "outline/%.3f" % width
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = OUTLINE_COLOR
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.grow = true
		m.grow_amount = width
		_materials[key] = m
	return _materials[key]


## Kendi kendine parlayan malzeme (fener ışığı, göz parıltısı gibi).
static func glow(color: Color) -> StandardMaterial3D:
	var key := "glow/%s" % color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		_materials[key] = m
	return _materials[key]


## Az yüzeyli küre (low-poly görünüm).
static func sphere(radius: float, segments: int = 16, rings: int = 8) -> SphereMesh:
	var key := "sphere/%.3f/%d/%d" % [radius, segments, rings]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = rings
		_meshes[key] = m
	return _meshes[key]


## Silindir. top = 0 verilirse koni olur.
static func cylinder(top: float, bottom: float, height: float, segments: int = 16) -> CylinderMesh:
	var key := "cyl/%.3f/%.3f/%.3f/%d" % [top, bottom, height, segments]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func box(size: Vector3) -> BoxMesh:
	var key := "box/%.3f/%.3f/%.3f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "torus/%.3f/%.3f" % [inner, outer]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 16
		m.ring_segments = 8
		_meshes[key] = m
	return _meshes[key]


## Bundan sonra eklenen parçaların kontur kalınlığı (m). 0 = kontur yok.
## Çizen kod önce ayarlar, işi bitince 0'a geri çeker.
static var outline: float = 0.0


## parent'a renkli bir parça ekler. Dönüş açıları derece.
static func part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadow: bool = true) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat(color, outline)
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = scl
	if not shadow:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


## Birleştirilmiş parçaların malzemesi: renk her köşede (vertex color) saklanır.
static func _vc_mat(width: float, shadow_side: bool = true) -> StandardMaterial3D:
	var key := "vc/%.3f/%s" % [width, shadow_side]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if width > 0.0:
			m.next_pass = _outline_mat(width)
		_materials[key] = m
	return _materials[key]


## Bir düğümün altındaki tüm parçaları tek bir şekilde birleştirir (telefon için çok daha hafif).
## Konturlu parçalar bir şekil, konutsuzlar başka bir şekil olur: en fazla 3 çizim.
## stop: hareket eden alt düğümler (kol, kafa, göz). Onlara dokunulmaz, ayrıca birleştirilir.
static func bake(root: Node3D, stop: Array = []) -> void:
	var lined: Array = []
	var plain: Array = []
	_collect(root, Transform3D.IDENTITY, stop, lined, plain)
	var width := 0.0
	for it: Array in lined:
		var mi: MeshInstance3D = it[0]
		var pass_mat := (mi.material_override as StandardMaterial3D).next_pass as StandardMaterial3D
		width = maxf(width, pass_mat.grow_amount)
	for group: Array in [lined, plain]:
		if group.is_empty():
			continue
		var inst := MeshInstance3D.new()
		inst.mesh = _merge(group)
		inst.material_override = _vc_mat(width if group == lined else 0.0)
		var casts := false
		for it: Array in group:
			var mi: MeshInstance3D = it[0]
			casts = casts or mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not casts:
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
		for it: Array in group:
			var mi: MeshInstance3D = it[0]
			mi.get_parent().remove_child(mi)
			mi.queue_free()


static func _collect(node: Node, xf: Transform3D, stop: Array, lined: Array, plain: Array) -> void:
	for child in node.get_children():
		if stop.has(child) or not (child is Node3D):
			continue
		var cxf: Transform3D = xf * (child as Node3D).transform
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var m := mi.material_override as StandardMaterial3D
			if m != null and m.next_pass != null:
				lined.append([mi, cxf])
			else:
				plain.append([mi, cxf])
		_collect(child, cxf, stop, lined, plain)


static func _merge(items: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for it: Array in items:
		var mi: MeshInstance3D = it[0]
		var xf: Transform3D = it[1]
		var color := (mi.material_override as StandardMaterial3D).albedo_color
		var nb := xf.basis.inverse().transposed()   # yassılaştırılmış şekillerde de ışık doğru düşsün
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var base := verts.size()
			for i in v.size():
				verts.append(xf * v[i])
				norms.append((nb * n[i]).normalized())
				cols.append(color)
			if ind.is_empty():
				for i in v.size():
					idx.append(base + i)
			else:
				for i in ind:
					idx.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


## Aynı şekilden çok sayıda (orman, çit direkleri, süsler) tek çizimle göstermek için.
## material verilirse renk yerine o kullanılır (örneğin parlayan fener camı).
static func multi(parent: Node3D, mesh: Mesh, color: Color, transforms: Array, shadow: bool = true,
		material: Material = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material if material != null else mat(color, outline)
	if not shadow:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst
