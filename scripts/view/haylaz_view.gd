extends Node3D
## Haylazların görüntüsü: her Haylaz için bir kardan adam (SnowmanView, "haylaz" tarzı).
## Kuraldaki Haylaz listesiyle her karede eşitlenir: yenisi kardan yükselerek belirir,
## dağılan kaybolur (dağılma parçacıklarını Effects çizer).
## Buz Topu'yla donan Haylaz yarı saydam bir buz kalıbının içinde, kıpırdamadan durur.

const SnowmanView = preload("res://scripts/view/snowman_view.gd")
const Haylaz = preload("res://scripts/core/haylaz.gd")
const Balance = preload("res://scripts/data/balance.gd")
const Kit = preload("res://scripts/view/mesh_kit.gd")

var _views: Dictionary = {}       # Haylaz -> SnowmanView
var _ice: Dictionary = {}         # Haylaz -> buz kalıbı (MeshInstance3D)
var _ice_mat: StandardMaterial3D


func _ready() -> void:
	_ice_mat = StandardMaterial3D.new()
	_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ice_mat.albedo_color = Color(0.62, 0.88, 1.0, 0.45)
	_ice_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	_ice_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	Kit.register_outline(_ice_mat, Kit._outline_mat(0.03), 0.03)


func clear() -> void:
	for h in _views:
		_views[h].queue_free()
	_views.clear()
	_ice.clear()


## f: iki kural adımı arasındaki oran (yumuşatma).
func sync(haylazlar: Array, f: float, dt: float) -> void:
	var alive := {}
	for h: Haylaz in haylazlar:
		alive[h] = true
		var v: SnowmanView = _views.get(h)
		if v == null:
			v = SnowmanView.new()
			add_child(v)
			v.build(h.data, "haylaz")
			v.snap_facing(h.facing)
			_views[h] = v
		var p := h.prev_pos.lerp(h.pos, f)
		v.rise = clampf(h.spawn_left / Balance.HAYLAZ_SPAWN_TIME, 0.0, 1.0)
		var frozen := h.frozen > 0.0
		var walk := 0.0 if frozen else clampf(h.vel.length() / maxf(h.speed, 0.01), 0.0, 1.0)
		v.update_pose(Vector3(p.x, 0, p.y), h.facing, walk, 0.0 if frozen else dt)
		_update_ice(h, v, frozen)
	for h in _views.keys():
		if not alive.has(h):
			_views[h].queue_free()
			_views.erase(h)
			_ice.erase(h)


func _update_ice(h: Haylaz, v: SnowmanView, frozen: bool) -> void:
	var ice: MeshInstance3D = _ice.get(h)
	if not frozen:
		if ice != null:
			ice.visible = false
		return
	if ice == null:
		ice = MeshInstance3D.new()
		ice.mesh = Kit.box(Vector3.ONE)
		ice.material_override = _ice_mat
		ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.add_child(ice)
		_ice[h] = ice
	ice.visible = true
	var s := h.radius / 0.5
	# kalıp donmanın son anlarında küçülerek erir
	var melt := clampf(h.frozen / 0.4, 0.0, 1.0)
	ice.scale = Vector3(1.25 * s, 2.25 * s, 1.25 * s) * (0.85 + 0.15 * melt)
	ice.position = Vector3(0, 1.05 * s, 0)
	ice.rotation.y = 0.3


func view_of(h: Haylaz) -> SnowmanView:
	return _views.get(h)
