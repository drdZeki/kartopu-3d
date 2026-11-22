extends Control
## Ekranın sol yarısındaki joystick (SPEC §13).
## Sabit mod: joystick sol altta durur, sol yarıda neresine dokunulursa yön bu merkeze göre.
## Serbest mod: joystick parmağın değdiği yerde açılır, parmak dışarı çıkınca peşinden gelir.
## Bilgisayarda fare de dokunma gibi çalışır (project.godot: emulate_touch_from_mouse).

const Balance = preload("res://scripts/data/balance.gd")

const BASE_COLOR := Color(1, 1, 1, 0.28)
const RING_COLOR := Color(0.17, 0.34, 0.52, 0.55)
const KNOB_COLOR := Color(1, 1, 1, 0.9)

var mode: String = "sabit"          # "sabit" ya da "serbest"
var vector: Vector2 = Vector2.ZERO  # yürüme yönü, uzunluğu 0–1

var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)


func is_active() -> bool:
	return _touch_index != -1


func set_mode(m: String) -> void:
	mode = m
	release()


func release() -> void:
	_touch_index = -1
	vector = Vector2.ZERO
	_knob = Vector2.ZERO
	queue_redraw()


func _radius() -> float:
	var s := get_viewport_rect().size
	return minf(s.x, s.y) * Balance.JOY_RADIUS_RATIO   # kısa kenara göre (dikey ekranda genişlik)


func _fixed_center() -> Vector2:
	var r := _radius()
	return Vector2(r * 1.7, get_viewport_rect().size.y - r * 1.7)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1 and touch.position.x < get_viewport_rect().size.x * 0.5:
				_touch_index = touch.index
				_center = touch.position if mode == "serbest" else _fixed_center()
				_update(touch.position)
		elif touch.index == _touch_index:
			release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update(drag.position)


func _update(p: Vector2) -> void:
	var r := _radius()
	var d := p - _center
	if mode == "serbest" and d.length() > r:
		# parmak dışarı çıktı: joystick peşinden gelir
		_center = p - d.normalized() * r
		d = p - _center
	var dist := minf(d.length(), r)
	var dir := d.normalized() if d.length() > 0.001 else Vector2.ZERO
	_knob = dir * dist
	var t := dist / r
	if t <= Balance.JOY_DEADZONE:
		vector = Vector2.ZERO
	else:
		vector = dir * clampf((t - Balance.JOY_DEADZONE) / (1.0 - Balance.JOY_DEADZONE), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var r := _radius()
	var c: Vector2
	if is_active():
		c = _center
	elif mode == "sabit":
		c = _fixed_center()
	else:
		return  # serbest modda dokunulmadıkça görünmez
	draw_circle(c, r, BASE_COLOR)
	draw_arc(c, r, 0.0, TAU, 48, RING_COLOR, 4.0, true)
	draw_circle(c + _knob, r * 0.42, KNOB_COLOR)
	draw_arc(c + _knob, r * 0.42, 0.0, TAU, 32, RING_COLOR, 3.0, true)
