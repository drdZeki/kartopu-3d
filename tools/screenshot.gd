extends SceneTree
## Geliştirme aracı: oyunu açar, birkaç ekran görüntüsü alıp kapanır.
## Çalıştırma (proje klasöründe, pencere kısa bir an açılır):
##   & "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --script res://tools/screenshot.gd -- <klasör>
## Görüntüler: <klasör>/ekran_1_duruyor.png, ekran_2_yuruyor.png (klavye), ekran_3_joystick.png (dokunma)

var _frame: int = 0
var _out_dir: String = "user://"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	var scene: PackedScene = load("res://scenes/main.tscn")
	root.add_child.call_deferred(scene.instantiate())


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 60:
		print("pencere: %s, ekran: %s, görüntü: %s, mod: %d" % [DisplayServer.window_get_size(), DisplayServer.screen_get_size(),
			root.get_visible_rect().size, DisplayServer.window_get_mode()])
		_save("ekran_1_duruyor.png")
		Input.action_press("move_up", 1.0)
		Input.action_press("move_right", 1.0)
	elif _frame == 130:
		_save("ekran_2_yuruyor.png")
		Input.action_release("move_up")
		Input.action_release("move_right")
		# joystick: sol alttaki merkeze dokun, sola doğru sürükle
		var size := root.get_visible_rect().size
		var r := minf(size.x, size.y) * 0.15
		var c := Vector2(r * 1.7, size.y - r * 1.7)
		_touch(true, c + Vector2(5, 0))
		_drag(c + Vector2(-r * 0.9, -r * 0.3))
	elif _frame == 200:
		_save("ekran_3_joystick.png")
		_touch(false, Vector2.ZERO)
		quit()
	return false


func _touch(pressed: bool, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = _to_window(pos)
	Input.parse_input_event(ev)


func _drag(pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = _to_window(pos)
	Input.parse_input_event(ev)


## Dokunma olayları pencere koordinatıyla gelir; oyun ekranı (720×1280) pencereye ölçeklenmiş olabilir.
func _to_window(p: Vector2) -> Vector2:
	return p * Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size


func _save(file_name: String) -> void:
	var path := _out_dir.path_join(file_name)
	root.get_texture().get_image().save_png(path)
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("kaydedildi: %s  (çizim: %d, üçgen: %d, FPS: %d)" % [path, calls, prims, Engine.get_frames_per_second()])
