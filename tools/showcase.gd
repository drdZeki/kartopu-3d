extends SceneTree
## Geliştirme aracı: karakter vitrini. Haritanın ortasına tüm karakterleri dizer,
## yakın plan ve oyun kamerasından iki ekran görüntüsü alır, çizim sayısını yazar.
## Çalıştırma (proje klasöründe, pencere kısa bir an açılır):
##   & "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --script res://tools/showcase.gd -- <klasör>
## Görüntüler: <klasör>/vitrin_yakin.png, vitrin_harita.png, vitrin_kenar.png

const Balance = preload("res://scripts/data/balance.gd")
const World = preload("res://scripts/core/world.gd")
const WorldView = preload("res://scripts/view/world_view.gd")
const SnowmanView = preload("res://scripts/view/snowman_view.gd")

var _frame: int = 0
var _out_dir: String = "user://"
var _cam: Camera3D
var _men: Array = []
var _t: float = 0.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	var world := World.new()
	world.generate(3)
	var wv := WorldView.new()
	root.add_child.call_deferred(wv)
	wv.ready.connect(func() -> void: wv.build(world))

	# önde oyuncu karakterleri, arkada Haylazlar
	var rows: Array = [[Balance.CHARACTERS, "player", 0.0, 1.35], [Balance.HAYLAZ.values(), "haylaz", -2.4, 1.9]]
	for row: Array in rows:
		var list: Array = row[0]
		var n := list.size()
		for i in n:
			var man := SnowmanView.new()
			root.add_child.call_deferred(man)
			var data: Dictionary = list[i]
			var style: String = row[1]
			var x := (i - (n - 1) * 0.5) * float(row[3])
			var z: float = row[2]
			man.ready.connect(func() -> void:
				man.build(data, style)
				man.position = Vector3(x, 0, z)
				man.snap_facing(Vector2(0, 1)))
			_men.append(man)

	_cam = Camera3D.new()
	_cam.fov = 40.0
	root.add_child.call_deferred(_cam)
	_cam.ready.connect(func() -> void:
		_cam.make_current()
		_cam.look_at_from_position(Vector3(0, 4.2, 9.5), Vector3(0, 1.0, -1.0)))


func _process(delta: float) -> bool:
	_frame += 1
	_t += delta
	# karakterler yerinde dursun ama canlı hareketleri (nefes, göz kırpma) çalışsın
	for man in _men:
		if man.is_inside_tree():
			man.update_pose(man.position, Vector2(0, 1), 0.0, delta)
	if _frame == 60:
		_save("vitrin_yakin.png")
		_cam.look_at_from_position(Vector3(0, 10.0, 8.4), Vector3(0, 0.8, 0))
	elif _frame == 90:
		_save("vitrin_harita.png")
		# kuzey kenarı: çit, fenerler, kulübe
		var h := Balance.MAP_SIZE * 0.5
		_cam.look_at_from_position(Vector3(0, 9.0, -h + 9.0), Vector3(0, 0.8, -h - 1.0))
	elif _frame == 120:
		_save("vitrin_kenar.png")
		quit()
	return false


func _save(file_name: String) -> void:
	var path := _out_dir.path_join(file_name)
	root.get_texture().get_image().save_png(path)
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("kaydedildi: %s  (çizim: %d, üçgen: %d)" % [path, calls, prims])
