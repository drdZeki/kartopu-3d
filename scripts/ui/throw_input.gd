extends Control
## Ekranın sağ yarısındaki atış kontrolü (SPEC §13):
##   kısa dokunuş         → otomatik nişanlı tek atış
##   sürükle ve bırak     → sürüklenen yöne atış (sürüklerken yerde nişan çizgisi)
##   basılı tut           → otomatik nişanlı seri atış
## Bilgisayarda fare dokunma gibi çalışır.

const Balance = preload("res://scripts/data/balance.gd")

const RING := Color(1, 1, 1, 0.55)
const RING_EDGE := Color(0.17, 0.34, 0.52, 0.6)

var _index: int = -1
var _start: Vector2
var _current: Vector2
var _held: float = 0.0
var _dragging: bool = false
var _queue: Array = []          # bırakılınca oluşan atış istekleri

const TOP_BAND: float = 0.13


## Ayarlar kapanınca: yarım kalan dokunuş ve bekleyen istekler silinir.
func reset() -> void:
	_index = -1
	_dragging = false
	_queue.clear()
	queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var vp := get_viewport_rect().size
			# üst şerit bilgi alanı (kalpler, sayaç, ayarlar düğmesi): oraya dokunmak atış sayılmaz
			if _index == -1 and touch.position.x >= vp.x * 0.5 and touch.position.y > vp.y * TOP_BAND:
				_index = touch.index
				_start = touch.position
				_current = touch.position
				_held = 0.0
				_dragging = false
		elif touch.index == _index:
			if _dragging:
				_queue.append({"auto": false, "dir": drag_dir()})
			elif _held < Balance.THROW_HOLD_TIME:
				_queue.append({"auto": true})
			_index = -1
			_dragging = false
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _index:
			_current = drag.position
			if _start.distance_to(_current) > _drag_threshold():
				_dragging = true
			queue_redraw()


func _process(dt: float) -> void:
	if _index != -1:
		_held += dt


func _drag_threshold() -> float:
	var s := get_viewport_rect().size
	return minf(s.x, s.y) * Balance.THROW_DRAG_RATIO


## Bırakılınca oluşan bir atış isteği (yoksa boş sözlük).
func take_request() -> Dictionary:
	return _queue.pop_front() if not _queue.is_empty() else {}


## Parmak basılı ve sürüklenmiyor: seri atış.
func is_auto_holding() -> bool:
	return _index != -1 and not _dragging and _held >= Balance.THROW_HOLD_TIME


## Sürükleniyorsa yerdeki atış yönü (ekranın yukarısı kuzey = -y); değilse sıfır.
func drag_dir() -> Vector2:
	if _index == -1 or not _dragging:
		return Vector2.ZERO
	return (_current - _start).normalized()


func _draw() -> void:
	if _index == -1:
		return
	var r := _drag_threshold() * 1.6
	draw_circle(_start, r, RING)
	draw_arc(_start, r, 0.0, TAU, 32, RING_EDGE, 3.0, true)
	if _dragging:
		var d := _current - _start
		var tip := _start + d.limit_length(r * 2.5)
		draw_line(_start, tip, RING_EDGE, 6.0, true)
		draw_circle(tip, r * 0.45, Color(1, 1, 1, 0.85))
		draw_arc(tip, r * 0.45, 0.0, TAU, 24, RING_EDGE, 3.0, true)
