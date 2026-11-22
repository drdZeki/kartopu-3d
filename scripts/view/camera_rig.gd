extends Node3D
## Eğik üstten bakan kamera (SPEC §4). Oyuncuyu yumuşakça takip eder, dönmez:
## ekranın yukarısı her zaman haritanın kuzeyi (-z).
## Oyun dikey ekranda oynanır: görüş açısı ekranın kısa kenarına (genişliğe) göre ayarlanır,
## böylece telefonun boyu ne olursa olsun yanlarda hep aynı genişlik görünür.

const PITCH_DEG: float = 55.0     # aşağı bakış açısı (daha dik olursa yüzler görünmez)
const DISTANCE: float = 20.0      # kameranın oyuncuya uzaklığı (m)
const SHORT_FOV_DEG: float = 36.0 # kısa kenardaki görüş açısı: oyuncunun hizasında ~13 m genişlik
const FOLLOW: float = 7.0         # takip yumuşaklığı (büyüdükçe daha sıkı)
const LOOK_OFFSET := Vector3(0.0, 0.8, 0.0)  # kardan adamın ayağına değil gövdesine bak

var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	var pitch := deg_to_rad(PITCH_DEG)
	# kamera hedefin güneyinde (+z) ve yukarısında durur
	camera.position = Vector3(0.0, sin(pitch) * DISTANCE, cos(pitch) * DISTANCE)
	camera.rotation_degrees = Vector3(-PITCH_DEG, 0.0, 0.0)
	camera.fov = SHORT_FOV_DEG
	camera.near = 0.5
	camera.far = 100.0
	add_child(camera)
	camera.make_current()
	get_viewport().size_changed.connect(_fit_aspect)
	_fit_aspect()


## Görüş açısı her zaman ekranın kısa kenarına göre (dikey ekranda genişlik).
func _fit_aspect() -> void:
	var s := get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_WIDTH if s.x < s.y else Camera3D.KEEP_HEIGHT


func follow(target: Vector3, dt: float) -> void:
	position = position.lerp(target + LOOK_OFFSET, 1.0 - exp(-FOLLOW * dt))


func snap(target: Vector3) -> void:
	position = target + LOOK_OFFSET
