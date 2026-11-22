extends SceneTree
## Geliştirme aracı: oyunu açar, bir senaryo oynatır, ekran görüntüleri alıp kapanır.
## Çalıştırma (proje klasöründe, pencere kısa bir an açılır):
##   & "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --script res://tools/screenshot.gd -- <klasör>
## Görüntüler (<klasör> içinde):
##   ekran_1_firtina.png     ilk fırtınanın başlangıç yazısı
##   ekran_2_kapisma.png     Haylazlar yaklaştıktan sonra basılı tutarak otomatik nişanlı seri atış
##   ekran_3_joystick.png    joystick'le yürüyüş (dokunma)
##   ekran_4_nisan.png       sağ yarıda sürükleyerek nişan alma (nişan çizgisi)
##   ekran_5_usume.png       oyuncu üşüdü: buz çerçevesi, kalp gitti
##   ekran_6_bitti.png       kartopu bitince: uyarı ve en yakın yığını gösteren ok
##   ekran_8_guc.png         güçlendirmeler: yerdeki 6 simge, 5'i etkin (kalkan, bulut, mıknatıs...), donmuş Haylaz, kombo
##   ekran_9_gizli.png       çalılıkta gizli: yarı saydam kardan adam, solan çalı, "Gizlisin" göstergesi
##   ekran_10_goruldun.png   gizliyken atış yapınca: gözlü rozet, kırmızı halka, "Görüldün!"
##   ekran_11_kral.png       Kar Kralı fırtınası: başlık, Kar Kralı ve can çubuğu
##   ekran_7_dondun.png      kalpler bitince "Dondun!" ekranı (puanla)
##   ekran_12_ayarlar.png    ayarlar penceresi
##   ekran_13_dusuk.png      düşük kalite (gölge, kontur, zemin ayrıntısı kapalı; düşük çözünürlük)
## Not: senaryo kaliteyi değiştirip sonunda "otomatik"e geri alır (user://kayit.cfg).

const Haylaz = preload("res://scripts/core/haylaz.gd")
const Power = preload("res://scripts/core/power.gd")
const Settings = preload("res://scripts/ui/settings.gd")

var _frame: int = 0
var _out_dir: String = "user://"
var _main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	var scene: PackedScene = load("res://scenes/main.tscn")
	_main = scene.instantiate()
	root.add_child.call_deferred(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	var size := root.get_visible_rect().size
	var right := Vector2(size.x * 0.75, size.y * 0.75)
	match _frame:
		5:
			_main.sim.player.hearts = 99   # senaryo bitmeden donmasın
		95:
			_save("ekran_1_firtina.png")
			_main._open_settings()
		125:
			_save("ekran_12_ayarlar.png")
			_main._settings_menu.close()
			Settings.set_quality("dusuk")
			_main._apply_settings()
		160:
			_save("ekran_13_dusuk.png")
			Settings.set_quality("otomatik")
			_main._apply_settings()
		250:
			_touch(1, true, right)   # Haylazlar yaklaşınca seri atış
		330:
			_save("ekran_2_kapisma.png")
			_touch(1, false, right)
			var r := minf(size.x, size.y) * 0.15
			var c := Vector2(r * 1.7, size.y - r * 1.7)
			_touch(0, true, c + Vector2(5, 0))
			_drag(0, c + Vector2(-r * 0.9, -r * 0.3))
		380:
			_save("ekran_3_joystick.png")
			_touch(0, false, Vector2.ZERO)
			_touch(1, true, right)
			_drag(1, right + Vector2(60, -120))
		410:
			_save("ekran_4_nisan.png")
			_touch(1, false, right + Vector2(60, -120))
		420:
			_main.sim.player.hearts = 3
			_main.sim.player.invulnerable = 0.0
			_main.sim._hurt_player()
		432:
			_save("ekran_5_usume.png")
			_main.sim.player.ammo = 1
			_move_away_from_piles()
		440:
			_touch(1, true, right)
		520:
			_save("ekran_6_bitti.png")
			_touch(1, false, right)
			_power_scene()
		575:
			_save("ekran_8_guc.png")
			var sim = _main.sim
			sim.player.powers = {}
			sim.powerups.clear()
			sim.haylazlar.clear()
			sim.storm_queue.clear()
			# çalılığa gir
			var b = sim.world.bushes[0]
			sim.player.pos = b.pos
			sim.player.prev_pos = b.pos
			sim.player.ammo = sim.player.capacity
		610:
			_save("ekran_9_gizli.png")
			_touch(1, true, right)
		613:
			_touch(1, false, right)   # kısa dokunuş: atış, görünür olur
		600:
			print("çalılıkta FPS (ölçüm): %d" % Engine.get_frames_per_second())
		625:
			_save("ekran_10_goruldun.png")
			# Kar Kralı fırtınası (5.) başlasın
			var sim = _main.sim
			sim.player.pos = sim.world.resolve_circle(Vector2.ZERO, 0.6)
			sim.player.prev_pos = sim.player.pos
			sim.storm = 4
			sim.in_storm = false
			sim._break_timer = 0.0
		662:
			# kralı oyuncunun önüne getir (yoksa uzakta belirir)
			var sim = _main.sim
			for h in sim.haylazlar:
				if h.type == "kral":
					h.pos = sim.world.resolve_circle(sim.player.pos + Vector2(0.5, -5.5), h.radius)
					h.prev_pos = h.pos
		700:
			_save("ekran_11_kral.png")
			_main.sim.player.hearts = 1
			_main.sim.player.invulnerable = 0.0
			_main.sim._hurt_player()
		820:
			_save("ekran_7_dondun.png")
			quit()
	return false


## Güçlendirme görüntüsü için: çevreye 6 güçlendirme, beşi etkin, yakında donmuş bir Haylaz, 3'lü kombo.
func _power_scene() -> void:
	var sim = _main.sim
	var p: Vector2 = sim.player.pos
	sim.player.hearts = 3
	for type in ["uclu", "buz", "kalkan", "miknatis", "yagmur"]:
		sim.player.powers[type] = 8.0
	var types := ["uclu", "buz", "kure", "kalkan", "miknatis", "yagmur"]
	for i in types.size():
		var a := TAU * i / types.size() + 0.3
		sim.powerups.append(Power.new(types[i], sim.world.clamp_inside(p + Vector2(cos(a), sin(a)) * 3.0, 0.6)))
	var rng := RandomNumberGenerator.new()
	var frozen := Haylaz.new(990, "atici", sim.world.clamp_inside(p + Vector2(-1.8, -3.2), 1.0), 1, rng)
	frozen.spawn_left = 0.0
	frozen.frozen = 30.0
	sim.haylazlar.append(frozen)
	for i in 3:
		var h := Haylaz.new(991 + i, "kosucu", p + Vector2(2.0 + i * 0.6, -4.0), 1, rng)
		sim._haylaz_down(h, Vector2.UP)


## Oyuncuyu kar yığınlarından en az 4 m uzak, boş bir yere taşır (yön oku görünsün diye).
func _move_away_from_piles() -> void:
	var sim = _main.sim
	for x in range(-12, 13, 2):
		for y in range(-12, 13, 2):
			var p := Vector2(x, y)
			if not sim.world.is_free(p, 0.6, 0.5):
				continue
			var ok := true
			for pile in sim.piles:
				if pile.pos.distance_to(p) < 4.0:
					ok = false
			if ok:
				sim.player.pos = p
				sim.player.prev_pos = p
				return


func _touch(index: int, pressed: bool, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = _to_window(pos)
	Input.parse_input_event(ev)


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
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
	print("kaydedildi: %s  (çizim: %d, üçgen: %d, FPS: %d, Haylaz: %d)" % [path, calls, prims,
		Engine.get_frames_per_second(), _main.sim.haylazlar.size()])
