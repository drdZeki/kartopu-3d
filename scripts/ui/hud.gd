extends Control
## Oyun ekranı bilgileri:
##   sol üst: ❤️ kalpler (kaybedilen kalp boş görünür), altında "Fırtına 2 · 5 Haylaz"
##   sağ üst: kartopu sayacı (kartopu simgesi + "7 / 10"); azalınca kırmızı ve nabız gibi atar
##   orta üst: kartopu bitince "Kartopu bitti!" uyarısı
##   sağ üst, sayacın altında: puan (artarken sayı hızla yükselir) ve kombo ("KOMBO x3!" + kalan süre çubuğu)
##   sol üst, fırtına bilgisinin altında: etkin güçlendirmeler (renkli simge + kalan süre halkası)
##   orta: fırtına başlangıç / bitiş yazısı ("FIRTINA 3", "FIRTINA DİNDİ!")
##   ekran kenarı: üşüyünce buz çerçevesi; tek kalp kalınca hafifçe atan buz çerçevesi

signal settings_pressed

const LOW := 2
const TOP_BAND: float = 0.13       # ekranın bu kadarlık üst şeridi bilgi alanı: dokunuşlar atış/joystick sayılmaz
const TEXT := Color(0.17, 0.34, 0.52)
const RED := Color(0.86, 0.18, 0.22)
const MARGIN: float = 22.0
const BANNER_TIME: float = 2.4

var _panel: PanelContainer
var _count: Label
var _empty: Label
var _empty_hint: Label
var _hearts: HeartsBar
var _storm: Label
var _banner: Label
var _banner_sub: Label
var _frost: TextureRect
var _time: float = 0.0
var _ammo: int = -1
var _bump: float = 0.0           # sayı değişince bir an büyüme
var _shake: float = 0.0          # kartopu yokken atmaya çalışınca sallanma
var _banner_t: float = 0.0
var _frost_flash: float = 0.0
var _low_hearts: bool = false
var _score: Label
var _score_value: int = 0
var _score_shown: float = 0.0
var _score_bump: float = 0.0
var _combo: Label
var _combo_bar: ComboBar
var _combo_mult: int = 1
var _combo_left: float = 0.0
var _combo_pop: float = 0.0
var _unlimited: bool = false
var _powers: PowerIcons
var _boss: BossBar
var _hide: HideIndicator
var _gear: GearButton
var _toast: Label
var _toast_t: float = 0.0

const COMBO_COLORS := [Color(1, 1, 1), Color(1, 1, 1), Color(1.0, 0.78, 0.15), Color(1.0, 0.55, 0.15),
	Color(0.95, 0.25, 0.3), Color(0.72, 0.35, 1.0)]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_frost = _make_frost()
	add_child(_frost)

	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.88)
	box.border_color = TEXT
	box.set_border_width_all(4)
	box.set_corner_radius_all(30)
	box.content_margin_left = 14
	box.content_margin_right = 22
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.shadow_color = Color(0.1, 0.2, 0.4, 0.25)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	_panel.add_theme_stylebox_override("panel", box)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_panel.add_child(row)
	var icon := SnowballIcon.new()
	icon.custom_minimum_size = Vector2(52, 52)
	row.add_child(icon)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 40)
	_count.add_theme_color_override("font_color", TEXT)
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_count)

	_hearts = HeartsBar.new()
	_hearts.position = Vector2(MARGIN, MARGIN + 6)
	add_child(_hearts)
	_storm = _make_label(28, TEXT, 8)
	_storm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_storm.visible = true

	_powers = PowerIcons.new()
	add_child(_powers)
	_boss = BossBar.new()
	_boss.visible = false
	add_child(_boss)
	_hide = HideIndicator.new()
	_hide.visible = false
	add_child(_hide)
	_gear = GearButton.new()
	_gear.size = Vector2(76, 76)
	_gear.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(_gear)
	_toast = _make_label(26, TEXT, 10)

	_score = _make_label(44, TEXT, 12)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score.visible = true
	_combo = _make_label(40, COMBO_COLORS[2], 12)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo.add_theme_color_override("font_outline_color", Color(0.17, 0.2, 0.35))
	_combo_bar = ComboBar.new()
	add_child(_combo_bar)

	_empty = _make_label(46, RED, 12)
	_empty_hint = _make_label(28, TEXT, 12)
	_banner = _make_label(92, TEXT, 22)
	_banner_sub = _make_label(36, TEXT, 12)
	set_ammo(0, 0)


func _make_label(size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	add_child(l)
	return l


## Ekran kenarında buz: ortası açık, kenarlara doğru buz mavisi ve beyaz.
func _make_frost() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 0.9, 1.0, 0.0))
	grad.set_color(1, Color(0.92, 0.97, 1.0, 0.95))
	grad.add_point(0.55, Color(0.75, 0.9, 1.0, 0.0))
	grad.add_point(0.8, Color(0.55, 0.8, 1.0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = 0.0
	return rect


# ---------- Dışarıdan çağrılanlar ----------

## unlimited: Kartopu Yağmuru sırasında sayaç "∞" gösterir.
func set_ammo(ammo: int, capacity: int, unlimited: bool = false) -> void:
	if ammo != _ammo or unlimited != _unlimited:
		_bump = 1.0
		_ammo = ammo
	_unlimited = unlimited
	_count.text = "∞" if unlimited else "%d / %d" % [ammo, capacity]
	var low := ammo <= LOW and not unlimited
	_count.add_theme_color_override("font_color", RED if low else (Color(0.55, 0.3, 0.85) if unlimited else TEXT))
	_empty.visible = ammo == 0 and not unlimited
	_empty_hint.visible = _empty.visible


func set_score(score: int) -> void:
	if score > _score_value:
		_score_bump = 1.0
	_score_value = score


## mult: kombo çarpanı, left: kombonun bitmesine kalan süre oranı (0–1).
func set_combo(mult: int, left: float) -> void:
	if mult > _combo_mult:
		_combo_pop = 1.0
	_combo_mult = mult
	_combo_left = left


## powers: oyuncunun etkin güçlendirmeleri (tür -> kalan sn).
func set_powers(powers: Dictionary) -> void:
	_powers.set_powers(powers)


## Ekranın altında kısa süre görünen bilgi yazısı.
func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 3.0


## Kar Kralı sahadaysa can çubuğu. ratio < 0 ise gizlenir.
func set_boss(name: String, ratio: float) -> void:
	_boss.visible = ratio >= 0.0
	if _boss.visible:
		_boss.set_value(name, ratio)


## Çalılıkta saklanma göstergesi. state: "" (yok), "hidden" (gizli), "seen" (görüldü).
## left: gizlenme süresinden kalan oran (0–1), seconds: kalan saniye.
func set_hide(state: String, left: float, seconds: float) -> void:
	_hide.visible = state != ""
	if _hide.visible:
		_hide.set_state(state, left, tr("HIDE_ON") % ceili(seconds) if state == "hidden" else tr("HIDE_SEEN"))


func set_hearts(hearts: int, max_hearts: int) -> void:
	_hearts.set_hearts(hearts, max_hearts)
	_low_hearts = hearts == 1


## storm = 0 ise henüz fırtına başlamadı.
func set_storm(storm: int, remaining: int, in_storm: bool) -> void:
	if storm == 0:
		_storm.text = ""
	elif in_storm:
		_storm.text = tr("HUD_STORM") % storm + "   " + tr("HUD_LEFT") % remaining
	else:
		_storm.text = tr("HUD_STORM") % storm + "   " + tr("HUD_CALM")


## Kartopu yokken atmaya çalışıldı: uyarı sallansın.
func flash_empty() -> void:
	_shake = 1.0


## Üşüdü: ekran kenarı bir an buz tutar, kaybedilen kalp sallanır.
func flash_frost() -> void:
	_frost_flash = 1.0
	_hearts.pop()


func show_banner(title: String, sub: String, color: Color) -> void:
	_banner.text = title
	_banner_sub.text = sub
	_banner.add_theme_color_override("font_color", color)
	_banner_t = BANNER_TIME


func _process(dt: float) -> void:
	_time += dt
	_bump = maxf(0.0, _bump - dt * 5.0)
	_shake = maxf(0.0, _shake - dt * 3.0)
	var vp := get_viewport_rect().size
	# sağ üst köşe: kartopu sayacı
	_panel.reset_size()
	var ps := _panel.size
	_panel.pivot_offset = ps * 0.5
	_panel.position = Vector2(vp.x - ps.x - MARGIN, MARGIN)
	var pulse := 0.0
	if _ammo <= LOW:
		pulse = 0.06 * (0.5 + 0.5 * sin(_time * 8.0))
	_panel.scale = Vector2.ONE * (1.0 + 0.15 * sin(_bump * PI) + pulse)
	# dişli: sayacın solunda
	_gear.position = Vector2(vp.x - ps.x - MARGIN - _gear.size.x - 12.0, MARGIN - 6.0)
	# bilgi yazısı
	_toast_t = maxf(0.0, _toast_t - dt)
	_toast.visible = _toast_t > 0.0
	if _toast.visible:
		_toast.reset_size()
		_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, vp.y - 300)
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
	# sol üst: fırtına bilgisi kalplerin altında, onun altında etkin güçlendirmeler
	_storm.reset_size()
	_storm.position = Vector2(MARGIN + 4, MARGIN + 66)
	_powers.position = Vector2(MARGIN, MARGIN + 112)
	_boss.size = Vector2(vp.x - MARGIN * 2.0, 54)
	_boss.position = Vector2(MARGIN, MARGIN + 186)
	_hide.size = Vector2(300, 64)
	_hide.position = Vector2((vp.x - 300.0) * 0.5, vp.y - 230)
	# sağ üst, sayacın altında: puan (hızla yükselen sayı) ve kombo
	_score_shown = move_toward(_score_shown, _score_value, maxf(30.0, absf(_score_value - _score_shown) * 8.0) * dt)
	_score_bump = maxf(0.0, _score_bump - dt * 4.0)
	_score.text = tr("HUD_SCORE") % int(round(_score_shown))
	_score.reset_size()
	_score.pivot_offset = Vector2(_score.size.x, _score.size.y * 0.5)
	_score.scale = Vector2.ONE * (1.0 + 0.12 * sin(_score_bump * PI))
	_score.position = Vector2(vp.x - _score.size.x - MARGIN, MARGIN + 74)
	_combo_pop = maxf(0.0, _combo_pop - dt * 3.0)
	var show_combo := _combo_mult >= 2 and _combo_left > 0.0
	_combo.visible = show_combo
	_combo_bar.visible = show_combo
	if show_combo:
		_combo.text = tr("HUD_COMBO") % _combo_mult
		_combo.add_theme_color_override("font_color", COMBO_COLORS[_combo_mult])
		_combo.reset_size()
		_combo.pivot_offset = Vector2(_combo.size.x, _combo.size.y * 0.5)
		_combo.scale = Vector2.ONE * (1.0 + 0.45 * sin(_combo_pop * PI) + 0.04 * sin(_time * 10.0))
		_combo.position = Vector2(vp.x - _combo.size.x - MARGIN, MARGIN + 128)
		_combo_bar.size = Vector2(_combo.size.x, 8)
		_combo_bar.position = Vector2(vp.x - _combo.size.x - MARGIN, MARGIN + 128 + _combo.size.y)
		_combo_bar.set_fill(_combo_left, COMBO_COLORS[_combo_mult])
	# orta üst: kartopu bitti uyarısı
	_empty.text = tr("AMMO_EMPTY")
	_empty_hint.text = tr("AMMO_EMPTY_HINT")
	_empty.reset_size()
	_empty_hint.reset_size()
	var shake_x := sin(_time * 50.0) * 14.0 * _shake
	_empty.position = Vector2((vp.x - _empty.size.x) * 0.5 + shake_x, vp.y * 0.2)
	_empty_hint.position = Vector2((vp.x - _empty_hint.size.x) * 0.5, vp.y * 0.2 + _empty.size.y)
	_empty.modulate.a = 0.75 + 0.25 * sin(_time * 5.0)
	_update_banner(dt, vp)
	# buz çerçevesi
	_frost_flash = maxf(0.0, _frost_flash - dt * 1.4)
	var low := 0.0
	if _low_hearts:
		low = 0.3 + 0.12 * sin(_time * 4.0)
	_frost.modulate.a = maxf(_frost_flash, low)


func _update_banner(dt: float, vp: Vector2) -> void:
	if _banner_t <= 0.0:
		_banner.visible = false
		_banner_sub.visible = false
		return
	_banner_t -= dt
	var age := BANNER_TIME - _banner_t
	_banner.visible = true
	_banner_sub.visible = true
	_banner.reset_size()
	_banner_sub.reset_size()
	# zıplayarak büyür, sonunda solar
	var s := 1.0
	if age < 0.35:
		var k := age / 0.35
		s = 0.4 + 0.6 * k + 0.25 * sin(k * PI)
	var a := clampf(_banner_t / 0.4, 0.0, 1.0)
	# uzun başlıklar (örneğin İngilizce) ekrana sığsın
	var fit := minf(1.0, (vp.x - 40.0) / maxf(_banner.size.x, 1.0))
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * s * fit
	_banner.position = Vector2((vp.x - _banner.size.x) * 0.5, vp.y * 0.3)
	_banner_sub.position = Vector2((vp.x - _banner_sub.size.x) * 0.5, vp.y * 0.3 + _banner.size.y)
	_banner.modulate.a = a
	_banner_sub.modulate.a = a


## Sayaçtaki kartopu simgesi: mavi gölgeli top, sol üstte açık kısım ve parlak nokta.
class SnowballIcon extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.44
		draw_circle(c, r, Color(0.62, 0.78, 0.97))
		draw_circle(c - Vector2(r * 0.14, r * 0.14), r * 0.8, Color(0.86, 0.93, 1.0))
		draw_circle(c - Vector2(r * 0.26, r * 0.26), r * 0.52, Color(0.98, 0.99, 1.0))
		draw_circle(c - Vector2(r * 0.42, r * 0.42), r * 0.16, Color(1, 1, 1))
		draw_arc(c, r, 0.0, TAU, 40, Color(0.17, 0.34, 0.52), 4.0, true)


## Ayarlar düğmesi: beyaz yuvarlak içinde lacivert dişli çark.
class GearButton extends Button:
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		var edge := Color(0.17, 0.34, 0.52)
		draw_circle(c, r, Color(1, 1, 1, 0.92) if not button_pressed else Color(0.85, 0.9, 1.0))
		draw_arc(c, r, 0.0, TAU, 32, edge, 4.0, true)
		var teeth := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			var rr := r * (0.62 if i % 2 == 0 else 0.48)
			teeth.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(teeth, edge)
		draw_circle(c, r * 0.2, Color.WHITE)


## Kar Kralı can çubuğu: altın taç simgesi, adı ve kırmızı dolgu (vurulunca bir an beyaz parlar).
class BossBar extends Control:
	var _name: String = ""
	var _ratio: float = 1.0
	var _shown: float = 1.0
	var _flash: float = 0.0

	func set_value(n: String, r: float) -> void:
		if r < _ratio - 0.001:
			_flash = 1.0
		_name = n
		_ratio = r
		queue_redraw()

	func _process(dt: float) -> void:
		_shown = move_toward(_shown, _ratio, dt * 0.6)
		_flash = maxf(0.0, _flash - dt * 5.0)
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var bar := Rect2(Vector2(64, 24), Vector2(size.x - 70, 26))
		draw_rect(bar.grow(4), Color(0.17, 0.2, 0.35, 0.85))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _shown, bar.size.y)), Color(1.0, 0.75, 0.75))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _ratio, bar.size.y)), Color(0.9, 0.22, 0.3).lerp(Color.WHITE, _flash))
		# taç
		var c := Vector2(30, 32)
		var pts := PackedVector2Array([c + Vector2(-24, 16), c + Vector2(-24, -8), c + Vector2(-12, 4), c + Vector2(0, -18),
			c + Vector2(12, 4), c + Vector2(24, -8), c + Vector2(24, 16)])
		draw_colored_polygon(pts, Color(1.0, 0.8, 0.2))
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Color(0.55, 0.35, 0.05), 3.0, true)
		draw_circle(c + Vector2(0, 6), 4.5, Color(0.9, 0.15, 0.25))
		draw_string_outline(font, Vector2(70, 18), _name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, Color.WHITE)
		draw_string(font, Vector2(70, 18), _name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.4, 0.15, 0.55))


## Saklanma göstergesi: yeşil kutuda "Gizlisin 7 sn" ve azalan süre çubuğu; görülünce kırmızı "Görüldün!".
class HideIndicator extends Control:
	var _state: String = ""
	var _left: float = 1.0
	var _text: String = ""
	var _time: float = 0.0

	func set_state(s: String, left: float, text: String) -> void:
		_state = s
		_left = left
		_text = text
		queue_redraw()

	func _process(dt: float) -> void:
		_time += dt
		if _state == "seen":
			queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var seen := _state == "seen"
		var bg := Color(0.93, 0.22, 0.28) if seen else Color(0.2, 0.55, 0.35)
		if seen and fmod(_time, 0.4) < 0.15:
			bg = bg.lightened(0.25)
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.set_corner_radius_all(30)
		box.border_color = Color.WHITE
		box.set_border_width_all(4)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(font, Vector2((size.x - w) * 0.5, 38), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		if not seen:
			var bar := Rect2(Vector2(26, size.y - 14), Vector2(size.x - 52, 6))
			draw_rect(bar, Color(1, 1, 1, 0.3))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * _left, bar.size.y)), Color.WHITE)


## Kombonun bitmesine kalan süre: soldan sağa azalan renkli çubuk.
class ComboBar extends Control:
	var _fill: float = 1.0
	var _color: Color = Color.WHITE

	func set_fill(f: float, c: Color) -> void:
		_fill = f
		_color = c
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.2, 0.35, 0.5))
		draw_rect(Rect2(Vector2(size.x * (1.0 - _fill), 0), Vector2(size.x * _fill, size.y)), _color)


## Etkin güçlendirmeler: her biri renkli daire içinde basit bir simge, çevresinde kalan süre halkası.
## Süresi bitmek üzere olan (son 2 sn) yanıp söner.
class PowerIcons extends Control:
	const Balance = preload("res://scripts/data/balance.gd")
	const R: float = 30.0
	const GAP: float = 10.0
	const EDGE := Color(0.17, 0.34, 0.52)
	var _powers: Dictionary = {}
	var _time: float = 0.0

	func set_powers(p: Dictionary) -> void:
		_powers = p
		queue_redraw()

	func _process(dt: float) -> void:
		_time += dt

	func _draw() -> void:
		var i := 0
		for type: String in Balance.POWER_ORDER:
			if not _powers.has(type):
				continue
			var left: float = _powers[type]
			if left < 2.0 and fmod(left, 0.3) < 0.12:
				i += 1
				continue
			var c := Vector2(R + i * (2.0 * R + GAP), R)
			var col: Color = Balance.POWERS[type]["color"]
			var total: float = Balance.POWERS[type]["time"]
			draw_circle(c, R, Color(1, 1, 1, 0.9))
			draw_circle(c, R - 5.0, col)
			# kalan süre halkası
			draw_arc(c, R - 2.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(left / total, 0.0, 1.0), 32, EDGE, 5.0, true)
			_draw_glyph(type, c, R - 9.0)
			i += 1

	func _draw_glyph(type: String, c: Vector2, r: float) -> void:
		var w := Color.WHITE
		match type:
			"uclu":
				for k in 3:
					var a := (k - 1) * 0.6
					draw_circle(c + Vector2(sin(a), -cos(a) * 0.5 + 0.2) * r * 0.62, r * 0.27, w)
			"buz":
				var pts := PackedVector2Array([c + Vector2(0, -r * 0.7), c + Vector2(r * 0.6, 0), c + Vector2(0, r * 0.7), c + Vector2(-r * 0.6, 0)])
				draw_colored_polygon(pts, w)
			"kalkan":
				var pts := PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, -r * 0.55),
					c + Vector2(r * 0.5, r * 0.1), c + Vector2(0, r * 0.7), c + Vector2(-r * 0.5, r * 0.1)])
				draw_colored_polygon(pts, w)
			"miknatis":
				draw_arc(c + Vector2(0, r * 0.05), r * 0.45, 0.0, PI, 16, w, r * 0.28)
				draw_rect(Rect2(c + Vector2(-r * 0.59, -r * 0.55), Vector2(r * 0.28, r * 0.6)), w)
				draw_rect(Rect2(c + Vector2(r * 0.31, -r * 0.55), Vector2(r * 0.28, r * 0.6)), w)
			"yagmur":
				draw_circle(c + Vector2(-r * 0.3, -r * 0.15), r * 0.32, w)
				draw_circle(c + Vector2(r * 0.1, -r * 0.3), r * 0.38, w)
				draw_circle(c + Vector2(r * 0.4, -r * 0.08), r * 0.28, w)
				for k in 3:
					draw_circle(c + Vector2((k - 1) * r * 0.35, r * 0.45), r * 0.1, w)


## Kalp sırası. Dolu kalp kırmızı, kaybedilen kalp açık gri. Kalp gidince son kalp sallanır.
class HeartsBar extends Control:
	const SIZE: float = 46.0
	const GAP: float = 6.0
	var _hearts: int = 0
	var _max: int = 0
	var _pop: float = 0.0
	var _lost_index: int = -1
	var _time: float = 0.0

	func set_hearts(hearts: int, max_hearts: int) -> void:
		if hearts < _hearts:
			_lost_index = hearts
		_hearts = hearts
		_max = max_hearts
		custom_minimum_size = Vector2(max_hearts * (SIZE + GAP), SIZE)
		queue_redraw()

	func pop() -> void:
		_pop = 1.0

	func _process(dt: float) -> void:
		_time += dt
		if _pop > 0.0 or _hearts == 1:
			_pop = maxf(0.0, _pop - dt * 2.5)
			queue_redraw()

	func _draw() -> void:
		for i in _max:
			var c := Vector2(i * (SIZE + GAP) + SIZE * 0.5, SIZE * 0.5)
			var s := SIZE * 0.5
			var full := i < _hearts
			if i == _lost_index and _pop > 0.0:
				c.x += sin(_time * 60.0) * 6.0 * _pop
				s *= 1.0 + 0.3 * _pop
			if full and _hearts == 1:
				s *= 1.0 + 0.1 * sin(_time * 8.0)   # tek kalp: nabız
			_draw_heart(c, s, Color(0.93, 0.22, 0.30) if full else Color(0.84, 0.88, 0.95))

	func _draw_heart(c: Vector2, s: float, fill: Color) -> void:
		var pts := PackedVector2Array()
		for k in 32:
			var t := TAU * k / 32.0
			var x := 16.0 * pow(sin(t), 3)
			var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
			pts.append(c + Vector2(x, -y) * s / 17.0)
		draw_colored_polygon(pts, fill)
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Color(0.17, 0.34, 0.52), 3.5, true)
		draw_circle(c + Vector2(-s * 0.38, -s * 0.3), s * 0.13, Color(1, 1, 1, 0.75 if fill.r > 0.9 else 0.0))
