extends Node3D
## Oyun sahnesi: kural tarafını (GameSim) sabit adımla ilerletir,
## görüntüyü (harita, kardan adamlar, Haylazlar, kartopları, efektler, kamera) ve kontrolleri bağlar.
## Kuraldan gelen olaylar (atış, çarpma, üşüme, fırtına...) burada görüntüye ve efektlere dağıtılır.
##
## Geliştirme tuşları (bilgisayarda test için):
##   1–4: karakter değiştir   R: yeni oyun   J: joystick modu   L: dil   Boşluk: otomatik atış

const Balance = preload("res://scripts/data/balance.gd")
const GameSim = preload("res://scripts/core/game_sim.gd")
const Pile = preload("res://scripts/core/pile.gd")
const Haylaz = preload("res://scripts/core/haylaz.gd")
const WorldView = preload("res://scripts/view/world_view.gd")
const SnowmanView = preload("res://scripts/view/snowman_view.gd")
const HaylazView = preload("res://scripts/view/haylaz_view.gd")
const SnowballView = preload("res://scripts/view/snowball_view.gd")
const PileView = preload("res://scripts/view/pile_view.gd")
const Effects = preload("res://scripts/view/effects.gd")
const AimGuide = preload("res://scripts/view/aim_guide.gd")
const PileArrow = preload("res://scripts/view/pile_arrow.gd")
const PowerView = preload("res://scripts/view/power_view.gd")
const PlayerAura = preload("res://scripts/view/player_aura.gd")
const CameraRig = preload("res://scripts/view/camera_rig.gd")
const Footprints = preload("res://scripts/view/footprints.gd")
const GameInput = preload("res://scripts/ui/game_input.gd")
const TouchJoystick = preload("res://scripts/ui/touch_joystick.gd")
const ThrowInput = preload("res://scripts/ui/throw_input.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const OffscreenArrows = preload("res://scripts/ui/offscreen_arrows.gd")
const GameOver = preload("res://scripts/ui/game_over.gd")
const Settings = preload("res://scripts/ui/settings.gd")
const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")
const Kit = preload("res://scripts/view/mesh_kit.gd")

const AUTO_FPS_MIN: float = 45.0     # otomatik kalitede bunun altında kalırsa bir seviye düşer
const AUTO_WINDOW: float = 4.0       # bu kadar sn'lik ortalamaya bakılır
const AUTO_WARMUP: float = 3.0       # oyun açılınca ilk bu kadar sn ölçülmez

const TEST_CHARACTERS := ["pamuk", "ruzgar", "kocabuz", "keskin"]
const HIT_TEXTS := ["HIT_1", "HIT_2", "HIT_3"]
const HIT_COLORS := [Color(1.0, 0.82, 0.2), Color(0.45, 0.85, 1.0), Color(1.0, 0.5, 0.6)]
const PICKUP_COLOR := Color(0.55, 0.85, 1.0)
const SCORE_COLORS := [Color(1.0, 0.86, 0.3), Color(1.0, 0.86, 0.3), Color(1.0, 0.78, 0.15), Color(1.0, 0.55, 0.15),
	Color(0.95, 0.25, 0.3), Color(0.72, 0.35, 1.0)]
const STORM_COLOR := Color(0.17, 0.34, 0.52)
const KRAL_COLOR := Color(0.52, 0.22, 0.72)
const HIDE_COLOR := Color(0.25, 0.65, 0.4)
const CALM_COLOR := Color(0.13, 0.60, 0.50)
const GAME_OVER_DELAY: float = 1.0

var sim: GameSim
var _world_view: WorldView
var _footprints: Footprints
var _player_view: SnowmanView
var _haylaz_view: HaylazView
var _balls_view: SnowballView
var _powers_view: PowerView
var _aura: PlayerAura
var _piles_view: PileView
var _effects: Effects
var _aim: AimGuide
var _arrow: PileArrow
var _camera: CameraRig
var _joystick: TouchJoystick
var _throw_input: ThrowInput
var _hud: Hud
var _offscreen: OffscreenArrows
var _game_over: GameOver
var _dev_label: Label
var _dev_timer: float = 0.0
var _char_index: int = 0
var _pending_throw: Dictionary = {}   # bekleme süresi dolana kadar bekletilen atış isteği
var _pending_ttl: float = 0.0
var _space_was_down: bool = false
var _game_over_timer: float = -1.0
var _ghost: bool = false
var _prewarm: int = 0
var _settings_menu: SettingsMenu
var _vignette: TextureRect
var _paused: bool = false
var _auto_time: float = 0.0          # otomatik kalite ölçümü
var _auto_frames: int = 0
var _auto_wait: float = AUTO_WARMUP
var _time: float = 0.0


func _ready() -> void:
	GameInput.ensure_actions()
	Settings.load_all()
	if Settings.lang != "":
		TranslationServer.set_locale(Settings.lang)
	sim = GameSim.new()

	_world_view = WorldView.new()
	add_child(_world_view)
	_footprints = Footprints.new()
	add_child(_footprints)
	_piles_view = PileView.new()
	add_child(_piles_view)
	_player_view = SnowmanView.new()
	add_child(_player_view)
	_haylaz_view = HaylazView.new()
	add_child(_haylaz_view)
	_balls_view = SnowballView.new()
	add_child(_balls_view)
	_powers_view = PowerView.new()
	add_child(_powers_view)
	_aura = PlayerAura.new()
	add_child(_aura)
	_aim = AimGuide.new()
	add_child(_aim)
	_arrow = PileArrow.new()
	add_child(_arrow)
	_effects = Effects.new()
	add_child(_effects)
	_camera = CameraRig.new()
	add_child(_camera)

	var ui := CanvasLayer.new()
	add_child(ui)
	_vignette = _make_vignette()
	ui.add_child(_vignette)
	_offscreen = OffscreenArrows.new()
	ui.add_child(_offscreen)
	_hud = Hud.new()
	ui.add_child(_hud)
	_joystick = TouchJoystick.new()
	ui.add_child(_joystick)
	_throw_input = ThrowInput.new()
	ui.add_child(_throw_input)
	_dev_label = Label.new()
	_dev_label.add_theme_font_size_override("font_size", 18)
	_dev_label.add_theme_color_override("font_color", Color(0.17, 0.34, 0.52, 0.7))
	_dev_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_dev_label.add_theme_constant_override("outline_size", 5)
	ui.add_child(_dev_label)
	_game_over = GameOver.new()
	ui.add_child(_game_over)
	_game_over.restart.connect(func() -> void: _new_game(randi()))
	_settings_menu = SettingsMenu.new()
	ui.add_child(_settings_menu)
	_settings_menu.closed.connect(_resume)
	_settings_menu.new_game.connect(func() -> void:
		_resume()
		_new_game(randi()))
	_settings_menu.changed.connect(_apply_settings)
	_hud.settings_pressed.connect(_open_settings)

	_new_game(randi())


# ---------- Ayarlar ve duraklatma ----------

func _open_settings() -> void:
	if _paused or sim.game_over:
		return
	_paused = true
	_settings_menu.open()


func _resume() -> void:
	_paused = false
	_throw_input.reset()
	_joystick.release()
	_pending_throw = {}
	_auto_wait = AUTO_WARMUP


## Ayarları uygular (açılışta, yeni haritada ve menüde bir şey değişince).
func _apply_settings() -> void:
	Kit.set_outlines(Settings.get_b("outlines"))
	_world_view.set_shadows(Settings.get_b("shadows"))
	_world_view.set_forest(Settings.get_f("forest"))
	_world_view.set_ground_detail(Settings.get_b("ground_detail"))
	_footprints.set_enabled(Settings.get_b("footprints"))
	var fx := Settings.get_b("effects")
	_vignette.visible = fx
	_effects.light_mode = not fx
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = Settings.get_f("render_scale")
	vp.msaa_3d = Viewport.MSAA_2X if Settings.get_f("render_scale") >= 0.999 else Viewport.MSAA_DISABLED
	Engine.max_fps = 30 if Settings.fps30 else 0
	if _joystick.mode != Settings.joy:
		_joystick.set_mode(Settings.joy)
	_refresh_dev_label()


## Otomatik kalite: oyun 4 sn boyunca saniyede 45 karenin altında kalırsa bir seviye düşer.
func _auto_quality(dt: float) -> void:
	if Settings.quality != "otomatik" or Settings.fps30 or _paused or sim.game_over:
		return
	if _auto_wait > 0.0:
		_auto_wait -= dt
		_auto_time = 0.0
		_auto_frames = 0
		return
	_auto_time += dt
	_auto_frames += 1
	if _auto_time < AUTO_WINDOW:
		return
	var fps := _auto_frames / _auto_time
	_auto_time = 0.0
	_auto_frames = 0
	if fps < AUTO_FPS_MIN and Settings.step_down():
		_apply_settings()
		_hud.toast(tr("AUTO_LOWERED"))
		_auto_wait = AUTO_WARMUP


func _new_game(p_seed: int) -> void:
	sim.new_game(p_seed, TEST_CHARACTERS[_char_index])
	_world_view.build(sim.world)
	_apply_settings()
	_footprints.clear()
	_piles_view.clear()
	_haylaz_view.clear()
	_powers_view.clear()
	_effects.clear_marks()
	_player_view.build(sim.player.data)
	_player_view.snap_facing(sim.player.facing)
	_player_view.visible = true
	# saydam malzemeyi açılışta bir kez çizdir: ilk saklanmada derlenip oyunu takıltmasın
	_player_view.set_ghost(0.55)
	_ghost = true
	_prewarm = 3
	_camera.snap(_to3(sim.player.pos))
	_pending_throw = {}
	_game_over_timer = -1.0
	_game_over.close()
	_refresh_dev_label()


# ---------- Kural adımı ----------

func _physics_process(dt: float) -> void:
	if _paused:
		return
	var move := _joystick.vector if _joystick.is_active() else GameInput.keyboard_vector()
	var used := sim.step(dt, move, _throw_request(dt))
	if used and not _pending_throw.is_empty():
		_pending_throw = {}
	for e: Dictionary in sim.take_events():
		_on_event(e)


## Bu adımdaki atış isteği: bırakılan dokunuş (bekletilebilir), basılı tutma ya da boşluk tuşu.
func _throw_request(dt: float) -> Dictionary:
	var req := _throw_input.take_request()
	var space := Input.is_physical_key_pressed(KEY_SPACE)
	if req.is_empty() and space and not _space_was_down:
		req = {"auto": true}
	_space_was_down = space
	if not req.is_empty():
		_pending_throw = req
		_pending_ttl = Balance.THROW_BUFFER
	if not _pending_throw.is_empty():
		_pending_ttl -= dt
		if _pending_ttl <= 0.0:
			_pending_throw = {}
		else:
			return _pending_throw
	if _throw_input.is_auto_holding() or space:
		return {"auto": true}
	return {}


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		"throw":
			_player_view.play_throw()
		"enemy_throw":
			var v := _haylaz_view.view_of(e["haylaz"])
			if v:
				v.play_throw()
		"splat", "ball_clash":
			var p: Vector2 = e["pos"]
			_effects.burst(Vector3(p.x, SnowballView.height_at(e["t"]), p.y))
		"land":
			var p: Vector2 = e["pos"]
			_effects.burst(Vector3(p.x, 0.15, p.y))
			_effects.splat_mark(p)
		"haylaz_spawn":
			var h: Haylaz = e["haylaz"]
			_effects.burst(Vector3(h.pos.x, 0.2, h.pos.y), true)
		"haylaz_hit":
			var p: Vector2 = e["pos"]
			var v := _haylaz_view.view_of(e["haylaz"])
			if v:
				v.play_hit()
			_effects.burst(Vector3(p.x, SnowballView.height_at(e["t"]), p.y))
		"haylaz_down":
			var h: Haylaz = e["haylaz"]
			var p: Vector2 = e["pos"]
			var d: Vector2 = e["dir"]
			var size: float = h.radius / 0.5
			_effects.burst(Vector3(p.x, 1.0 * size, p.y), true)
			_effects.debris(Vector3(p.x, 0, p.y), size, h.data["color"], Vector3(d.x, 0, d.y))
			if h.type == "kral":
				_effects.burst(Vector3(p.x, 2.5, p.y), true)
				_effects.burst(Vector3(p.x + 0.8, 1.5, p.y), true)
				_effects.burst(Vector3(p.x - 0.8, 1.5, p.y), true)
			_camera.shake({"koca": 0.45, "kral": 1.0}.get(h.type, 0.25))
		"score":
			var p: Vector2 = e["pos"]
			var mult: int = e["mult"]
			var txt := "+%d" % e["points"] + (" x%d" % mult if mult > 1 else "")
			_effects.text(Vector3(p.x, 1.9, p.y), txt, SCORE_COLORS[mini(mult, SCORE_COLORS.size() - 1)])
		"combo":
			# kombo arttı: "Süper!", "Harika!" gibi bir övgü
			var p: Vector2 = e["pos"]
			var k := randi() % HIT_TEXTS.size()
			_effects.text(Vector3(p.x, 3.0, p.y), tr(HIT_TEXTS[k]), HIT_COLORS[k])
		"power_spawn":
			var p: Vector2 = e["pos"]
			_effects.burst(Vector3(p.x, 0.8, p.y))
		"power_pickup":
			var type: String = e["power_type"]
			var pp := sim.player.pos
			_effects.burst(Vector3(pp.x, 1.2, pp.y), true)
			_effects.text(Vector3(pp.x, 2.6, pp.y), tr(Balance.POWERS[type]["name"]), Balance.POWERS[type]["color"])
		"shield_block", "freeze":
			var p: Vector2 = e["pos"] if e.has("pos") else (e["haylaz"] as Haylaz).pos
			_effects.burst(Vector3(p.x, 1.1, p.y))
		"pickup":
			var p: Vector2 = e["pos"]
			_effects.burst(Vector3(p.x, 0.3, p.y))
			var pp := sim.player.pos
			_effects.text(Vector3(pp.x, 2.4, pp.y), "+%d" % e["amount"], PICKUP_COLOR)
		"empty":
			_hud.flash_empty()
		"player_hurt":
			_hud.flash_frost()
			_player_view.play_hit()
			_camera.shake(0.6)
		"storm_start":
			if e["kral"]:
				_hud.show_banner(tr("KRAL_TITLE"), tr("KRAL_SUB"), KRAL_COLOR)
				_camera.shake(0.5)
			else:
				_hud.show_banner(tr("STORM_TITLE") % e["storm"], tr("STORM_SUB") % e["count"], STORM_COLOR)
		"kral_summon":
			var h: Haylaz = e["haylaz"]
			_effects.text(Vector3(h.pos.x, 4.8, h.pos.y), tr("KRAL_SUMMON"), KRAL_COLOR.lightened(0.3))
		"hidden":
			var pp := sim.player.pos
			_effects.text(Vector3(pp.x, 2.6, pp.y), tr("HIDE_START"), HIDE_COLOR)
		"hide_expired":
			var pp := sim.player.pos
			_effects.text(Vector3(pp.x, 2.6, pp.y), tr("HIDE_DONE"), Color(0.95, 0.3, 0.35))
			var p: Vector2 = e["pos"]
			_effects.burst(Vector3(p.x, 0.8, p.y), true)
		"storm_end":
			var sub: String = tr("STORM_END_HEAL") if e["healed"] else tr("STORM_END_REST")
			_hud.show_banner(tr("STORM_END"), sub + "   " + tr("STORM_BONUS") % e["bonus"], CALM_COLOR)
		"game_over":
			_game_over_timer = GAME_OVER_DELAY
			_camera.shake(1.0)


# ---------- Görüntü ----------

func _process(dt: float) -> void:
	_time += dt
	_auto_quality(dt)
	if _paused:
		dt = 0.0   # duraklatınca kardan adamlar ve efektler de dursun
	# iki kural adımı arasını yumuşat (yüksek yenileme hızlı ekranlarda takılmasın)
	var f := Engine.get_physics_interpolation_fraction()
	var p := sim.player
	var pos2 := p.prev_pos.lerp(p.pos, f)
	var pos := _to3(pos2)
	_player_view.update_pose(pos, p.facing, 0.0 if sim.game_over else p.walk_ratio(), dt)
	# üşüdükten sonra dokunulmazken yanıp söner
	_player_view.visible = p.invulnerable <= 0.0 or fmod(_time, 0.16) < 0.1
	var body_size: float = p.data["size"]
	_footprints.track(0, pos2, p.facing, body_size, p.walk_ratio() > 0.05 and not sim.game_over)
	_camera.follow(pos, dt)
	_haylaz_view.sync(sim.haylazlar, f, dt)
	for h: Haylaz in sim.haylazlar:
		if h.is_active():
			_footprints.track(h.id, h.pos, h.facing, h.radius / 0.5, h.vel.length() > 0.2)
	_balls_view.sync(sim.balls, f)
	_piles_view.sync(sim.piles, dt)
	_powers_view.sync(sim.powerups, dt)
	_aura.update_aura(pos, p.powers, body_size, dt)
	_update_hiding(body_size)
	_update_aim(pos2, dt)
	_update_pile_arrow(pos2, dt)
	_update_offscreen(pos2)

	_hud.set_ammo(p.ammo, p.capacity, p.unlimited())
	_hud.set_hearts(p.hearts, p.max_hearts)
	_hud.set_storm(sim.storm, sim.storm_remaining(), sim.in_storm)
	_hud.set_score(sim.score)
	_hud.set_combo(sim.combo_mult(), sim.combo_timer / Balance.COMBO_WINDOW)
	_hud.set_powers(p.powers)
	if _game_over_timer > 0.0:
		_game_over_timer -= dt
		if _game_over_timer <= 0.0:
			_game_over.open(sim.storm, sim.kills, sim.score)
	_dev_timer -= dt
	if _dev_timer <= 0.0:
		_refresh_dev_label()


## Çalılıkta saklanma: gizliyken kardan adam yarı saydam, içinde durduğu çalı solar;
## görülünce kafasında gözlü rozet; ekranda "Gizlisin 7" / "Görüldün!". Kar Kralı can çubuğu da burada.
func _update_hiding(body_size: float) -> void:
	if _prewarm > 0:
		_prewarm -= 1
	elif sim.hidden != _ghost:
		_ghost = sim.hidden
		_player_view.set_ghost(0.55 if _ghost else 0.0)
	var in_bush: bool = sim.hide_bush != null
	_aura.set_seen(in_bush and not sim.hidden, body_size)
	_world_view.update_bushes(sim.world.bushes, sim.hide_bush)
	if sim.hidden:
		var used: float = sim.hide_bush.use
		_hud.set_hide("hidden", 1.0 - used / Balance.HIDE_MAX, Balance.HIDE_MAX - used)
	elif in_bush:
		_hud.set_hide("seen", 0.0, 0.0)
	else:
		_hud.set_hide("", 0.0, 0.0)
	var boss_ratio := -1.0
	for h: Haylaz in sim.haylazlar:
		if h.type == "kral":
			boss_ratio = float(h.hp) / h.max_hp
	_hud.set_boss(tr("HAYLAZ_KRAL"), boss_ratio)


## Sürüklerken nişan çizgisi.
func _update_aim(pos2: Vector2, dt: float) -> void:
	var aim_dir := _throw_input.drag_dir()
	if aim_dir != Vector2.ZERO and not sim.game_over:
		var length := sim.world.cast(pos2, aim_dir, sim.player.ball_radius, Balance.BALL_RANGE)
		_aim.show_aim(pos2, aim_dir, length, dt)
	else:
		_aim.hide_aim()


## Kartopu azalınca en yakın yığını gösteren ok.
func _update_pile_arrow(pos2: Vector2, dt: float) -> void:
	var target: Variant = null
	if sim.player.ammo <= Balance.LOW_AMMO and not sim.game_over and not sim.player.unlimited():
		var best := INF
		for pile: Pile in sim.piles:
			var d := pile.pos.distance_to(pos2)
			if d < best:
				best = d
				target = pile.pos
	_arrow.update_arrow(pos2, target, dt)


## Ekran dışındaki Haylazlar için kenarda ok.
func _update_offscreen(pos2: Vector2) -> void:
	var items: Array = []
	var cam := _camera.camera
	var rect := get_viewport().get_visible_rect().grow(-20.0)
	for h: Haylaz in sim.haylazlar:
		if not h.alive:
			continue
		var p3 := Vector3(h.pos.x, 1.0, h.pos.y)
		if not cam.is_position_behind(p3) and rect.has_point(cam.unproject_position(p3)):
			continue
		# kamera dönmediği için yerdeki yön ekranda da aynı (yukarı = kuzey)
		items.append([h.pos - pos2, h.pos.distance_to(pos2)])
	_offscreen.set_items(items)


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
			_refresh_dev_label()
		KEY_R:
			_new_game(randi())
		KEY_J:
			Settings.joy = "serbest" if Settings.joy == "sabit" else "sabit"
			Settings.save()
			_apply_settings()
		KEY_L:
			Settings.lang = "en" if TranslationServer.get_locale().begins_with("tr") else "tr"
			Settings.save()
			TranslationServer.set_locale(Settings.lang)
			_refresh_dev_label()
		KEY_ESCAPE, KEY_P:
			_open_settings()


func _refresh_dev_label() -> void:
	_dev_timer = 0.25
	var joy := tr("JOY_FIXED") if _joystick.mode == "sabit" else tr("JOY_FREE")
	var name_key: String = sim.player.data["name"]
	var q := Settings.quality + ("/" + Settings.auto_level if Settings.quality == "otomatik" else "")
	if OS.has_feature("mobile"):
		# telefonda sadece hız bilgisi (test sürecinde yavaşlığı görmek için)
		_dev_label.text = "FPS %d  |  %s" % [Engine.get_frames_per_second(), q]
	else:
		_dev_label.text = "%s  |  %s  |  FPS %d  |  %s\n%s" % [tr(name_key), joy, Engine.get_frames_per_second(), q, tr("DEV_HINT")]
	var vp := get_viewport().get_visible_rect().size
	_dev_label.reset_size()
	_dev_label.position = Vector2((vp.x - _dev_label.size.x) * 0.5, vp.y - _dev_label.size.y - 8)


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
