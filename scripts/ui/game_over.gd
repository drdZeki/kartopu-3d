extends Control
## "Dondun!" ekranı (SPEC §3): kalpler bitince çıkar. Ulaşılan fırtına, dağıtılan Haylaz sayısı
## ve "Tekrar oyna" düğmesi. (Skor, rekor, para 5. ve 7. adımda eklenecek.)

signal restart

const TEXT := Color(0.17, 0.34, 0.52)
const ICE := Color(0.33, 0.62, 0.95)

var _panel: PanelContainer
var _stats: Label
var _age: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.22, 0.42, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.96)
	box.border_color = TEXT
	box.set_border_width_all(5)
	box.set_corner_radius_all(40)
	box.set_content_margin_all(34)
	box.shadow_color = Color(0.05, 0.1, 0.3, 0.35)
	box.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(col)

	col.add_child(_label(tr("GO_TITLE"), 96, ICE, 16))
	col.add_child(_label(tr("GO_SUB"), 36, TEXT, 0))
	_stats = _label("", 34, TEXT, 0)
	col.add_child(_stats)

	var btn := Button.new()
	btn.text = tr("GO_AGAIN")
	btn.add_theme_font_size_override("font_size", 46)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color(0.6, 0.3, 0.05))
	btn.add_theme_constant_override("outline_size", 8)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.6, 0.18) if state != "pressed" else Color(0.92, 0.5, 0.12)
		if state == "hover":
			sb.bg_color = Color(1.0, 0.68, 0.28)
		sb.border_color = Color(0.75, 0.4, 0.08)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(36)
		sb.content_margin_left = 40
		sb.content_margin_right = 40
		sb.content_margin_top = 14
		sb.content_margin_bottom = 18
		btn.add_theme_stylebox_override(state, sb)
	btn.pressed.connect(func() -> void: restart.emit())
	col.add_child(btn)
	visible = false


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.85, 0.94, 1.0))
		l.add_theme_constant_override("outline_size", outline)
	return l


func open(storm: int, kills: int, score: int) -> void:
	_stats.text = (tr("GO_SCORE") % score) + "\n" + (tr("GO_STORM") % storm) + "\n" + (tr("GO_KILLS") % kills)
	visible = true
	_age = 0.0


func close() -> void:
	visible = false


func _process(dt: float) -> void:
	if not visible:
		return
	_age += dt
	var vp := get_viewport_rect().size
	_panel.reset_size()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.position = (vp - _panel.size) * 0.5
	# zıplayarak açılır
	var k := clampf(_age / 0.4, 0.0, 1.0)
	_panel.scale = Vector2.ONE * (0.5 + 0.5 * k + 0.12 * sin(k * PI))
	modulate.a = k
