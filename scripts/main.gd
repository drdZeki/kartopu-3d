extends Node3D
## Oyun sahnesi: kural tarafını (GameSim) sabit adımla ilerletir,
## görüntüyü (harita, kardan adam, kamera) ve kontrolleri birbirine bağlar.
##
## Geliştirme tuşları (bilgisayarda test için):
##   1–4: karakter değiştir   R: yeni harita   J: joystick modu   L: dil

const Balance = preload("res://scripts/data/balance.gd")
const GameSim = preload("res://scripts/core/game_sim.gd")
const WorldView = preload("res://scripts/view/world_view.gd")
const SnowmanView = preload("res://scripts/view/snowman_view.gd")
const CameraRig = preload("res://scripts/view/camera_rig.gd")
const GameInput = preload("res://scripts/ui/game_input.gd")
const TouchJoystick = preload("res://scripts/ui/touch_joystick.gd")
const Footprints = preload("res://scripts/view/footprints.gd")

const TEST_CHARACTERS := ["pamuk", "ruzgar", "kocabuz", "keskin"]

var sim: GameSim
var _world_view: WorldView
var _footprints: Footprints
var _player_view: SnowmanView
var _camera: CameraRig
var _joystick: TouchJoystick
var _hud: Label
var _hud_timer: float = 0.0
var _char_index: int = 0


func _ready() -> void:
	GameInput.ensure_actions()
	sim = GameSim.new()

	_world_view = WorldView.new()
	add_child(_world_view)
	_footprints = Footprints.new()
	add_child(_footprints)
	_player_view = SnowmanView.new()
	add_child(_player_view)
	_camera = CameraRig.new()
	add_child(_camera)

	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(_make_vignette())
	_joystick = TouchJoystick.new()
	ui.add_child(_joystick)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_color", Color(0.17, 0.34, 0.52))
	_hud.add_theme_color_override("font_outline_color", Color.WHITE)
	_hud.add_theme_constant_override("outline_size", 6)
	ui.add_child(_hud)

	_new_game(randi())


func _new_game(p_seed: int) -> void:
	sim.new_game(p_seed, TEST_CHARACTERS[_char_index])
	_world_view.build(sim.world)
	_footprints.clear()
	_player_view.build(sim.player.data)
	_player_view.snap_facing(sim.player.facing)
	_camera.snap(_to3(sim.player.pos))
	_refresh_hud()


func _physics_process(dt: float) -> void:
	var move := _joystick.vector if _joystick.is_active() else GameInput.keyboard_vector()
	sim.step(dt, move)


func _process(dt: float) -> void:
	# iki kural adımı arasını yumuşat (yüksek yenileme hızlı ekranlarda takılmasın)
	var f := Engine.get_physics_interpolation_fraction()
	var p := sim.player
	var pos2 := p.prev_pos.lerp(p.pos, f)
	var pos := _to3(pos2)
	_player_view.update_pose(pos, p.facing, p.walk_ratio(), dt)
	var body_size: float = p.data["size"]
	_footprints.track(0, pos2, p.facing, body_size, p.walk_ratio() > 0.05)
	_camera.follow(pos, dt)

	_hud_timer -= dt
	if _hud_timer <= 0.0:
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_char_index = key.physical_keycode - KEY_1
			sim.change_character(TEST_CHARACTERS[_char_index])
			_player_view.build(sim.player.data)
			_refresh_hud()
		KEY_R:
			_new_game(randi())
		KEY_J:
			_joystick.set_mode("serbest" if _joystick.mode == "sabit" else "sabit")
			_refresh_hud()
		KEY_L:
			TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("tr") else "tr")
			_refresh_hud()


func _refresh_hud() -> void:
	_hud_timer = 0.25
	var joy := tr("JOY_FIXED") if _joystick.mode == "sabit" else tr("JOY_FREE")
	var name_key: String = sim.player.data["name"]
	_hud.text = "%s   |   %s   |   FPS %d\n%s" % [tr(name_key), joy, Engine.get_frames_per_second(), tr("DEV_HINT")]


## Ekran kenarlarında hafif mavi gölge: göz ortaya odaklanır, kış havası verir.
func _make_vignette() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.45, 0.6, 0.85, 0.0))
	grad.set_color(1, Color(0.45, 0.6, 0.85, 0.32))
	grad.add_point(0.6, Color(0.45, 0.6, 0.85, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## Kural düzlemindeki (x, y) noktayı 3D'ye (x, 0, z) çevirir.
static func _to3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)
