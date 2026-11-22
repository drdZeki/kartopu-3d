extends Control
## Ayarlar penceresi (SPEC §17a). Açıkken oyun durur.
## Görüntü kalitesi (Otomatik / Yüksek / Orta / Düşük) ve tek tek: gölgeler, kenar çizgileri,
## zemin ayrıntısı, ekran efektleri, kar izleri, orman, çözünürlük, kare hızı; joystick; dil.
## Büyük, dokunması kolay düğmeler. Seçili düğme turuncu.

signal closed
signal new_game
signal changed        # bir ayar değişti: main.gd hemen uygular

const Settings = preload("res://scripts/ui/settings.gd")
const TEXT := Color(0.17, 0.34, 0.52)
const ORANGE := Color(1.0, 0.6, 0.18)
const GREEN := Color(0.25, 0.68, 0.42)

var _panel: PanelContainer
var _list: VBoxContainer
var _age: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.22, 0.42, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.97)
	box.border_color = TEXT
	box.set_border_width_all(5)
	box.set_corner_radius_all(36)
	box.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	visible = false


func open() -> void:
	_rebuild()
	visible = true
	_age = 0.0


func close() -> void:
	visible = false
	closed.emit()


func _process(dt: float) -> void:
	if not visible:
		return
	_age += dt
	var vp := get_viewport_rect().size
	_panel.size = Vector2(vp.x - 48.0, minf(vp.y - 140.0, 1120.0))
	_panel.position = (vp - _panel.size) * 0.5
	(_panel.get_child(0) as Control).custom_minimum_size = _panel.size - Vector2(48, 48)
	var k := clampf(_age / 0.25, 0.0, 1.0)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * (0.85 + 0.15 * k)
	modulate.a = k


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE or key.physical_keycode == KEY_P:
			close()
			get_viewport().set_input_as_handled()


# ---------- İçerik ----------

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(_label(tr("SET_TITLE"), 58, TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	_list.add_child(_label(tr("SET_QUALITY"), 34, TEXT))
	_list.add_child(_label(tr("SET_QUALITY_HINT"), 24, Color(0.4, 0.5, 0.62)))
	var q_opts := [["Q_AUTO", "otomatik"], ["Q_HIGH", "yuksek"], ["Q_MID", "orta"], ["Q_LOW", "dusuk"]]
	_list.add_child(_choice(q_opts, Settings.quality, func(v) -> void:
		Settings.set_quality(v)
		_after_change()))
	if Settings.quality == "ozel":
		_list.add_child(_label(tr("Q_CUSTOM"), 24, ORANGE))

	_list.add_child(_separator())
	_toggle_row("SET_SHADOWS", "shadows")
	_toggle_row("SET_OUTLINES", "outlines")
	_toggle_row("SET_GROUND", "ground_detail")
	_toggle_row("SET_EFFECTS", "effects")
	_toggle_row("SET_FOOTPRINTS", "footprints")
	_list.add_child(_label(tr("SET_FOREST"), 30, TEXT))
	_list.add_child(_choice([["FOREST_FULL", 1.0], ["FOREST_HALF", 0.5], ["FOREST_LOW", 0.25]],
		Settings.get_f("forest"), func(v) -> void:
			Settings.set_value("forest", v)
			_after_change()))
	_list.add_child(_label(tr("SET_SCALE"), 30, TEXT))
	_list.add_child(_choice([["%100", 1.0], ["%75", 0.75], ["%60", 0.6]],
		Settings.get_f("render_scale"), func(v) -> void:
			Settings.set_value("render_scale", v)
			_after_change()))
	_list.add_child(_label(tr("SET_FPS"), 30, TEXT))
	_list.add_child(_choice([["FPS_60", false], ["FPS_30", true]], Settings.fps30, func(v) -> void:
		Settings.fps30 = v
		Settings.save()
		_after_change()))

	_list.add_child(_separator())
	_list.add_child(_label(tr("SET_JOY"), 30, TEXT))
	_list.add_child(_choice([["JOY_S", "sabit"], ["JOY_F", "serbest"]], Settings.joy, func(v) -> void:
		Settings.joy = v
		Settings.save()
		_after_change()))
	_list.add_child(_label(tr("SET_LANG"), 30, TEXT))
	var cur_lang := Settings.lang if Settings.lang != "" else ("tr" if TranslationServer.get_locale().begins_with("tr") else "en")
	_list.add_child(_choice([["Türkçe", "tr"], ["English", "en"]], cur_lang, func(v) -> void:
		Settings.lang = v
		Settings.save()
		TranslationServer.set_locale(v)
		_after_change()))

	_list.add_child(_separator())
	_list.add_child(_big_button(tr("SET_RESUME"), ORANGE, close))
	_list.add_child(_big_button(tr("SET_NEW"), Color(0.35, 0.6, 0.95), func() -> void:
		visible = false
		new_game.emit()))


func _after_change() -> void:
	changed.emit()
	_rebuild.call_deferred()


func _toggle_row(text_key: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_child(_label(tr(text_key), 30, TEXT))
	(row.get_child(0) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := Settings.get_b(key)
	var btn := _button(tr("ON") if on else tr("OFF"), GREEN if on else Color(0.78, 0.8, 0.86), on)
	btn.custom_minimum_size = Vector2(170, 70)
	btn.pressed.connect(func() -> void:
		Settings.set_value(key, not Settings.get_b(key))
		_after_change())
	row.add_child(btn)
	_list.add_child(row)


## Seçenek düğmeleri: options = [[metin ya da çeviri anahtarı, değer], ...]
func _choice(options: Array, current, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for o: Array in options:
		var selected: bool = o[1] == current
		var btn := _button(tr(o[0]), ORANGE if selected else Color(0.9, 0.94, 1.0), selected)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 70
		var v = o[1]
		btn.pressed.connect(func() -> void: on_pick.call(v))
		row.add_child(btn)
	return row


func _button(text: String, bg: Color, light_text: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 26)
	var fg := Color.WHITE if light_text else TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, fg)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.08) if state == "hover" else bg
		sb.border_color = TEXT
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(22)
		sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override(state, sb)
	return btn


func _big_button(text: String, bg: Color, action: Callable) -> Button:
	var btn := _button(text, bg, true)
	btn.add_theme_font_size_override("font_size", 40)
	btn.custom_minimum_size.y = 96
	btn.pressed.connect(action)
	return btn


func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _separator() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 18)
	return s
