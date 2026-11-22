extends Control
## Ekran dışındaki Haylazları ekran kenarında kırmızı oklarla gösterir (SPEC §4).
## Ok, Haylazın bulunduğu yöne bakar; Haylaz yakınlaştıkça biraz büyür.

const COLOR := Color(0.92, 0.22, 0.26)
const EDGE := Color(1, 1, 1)
const INSET: float = 42.0

var _items: Array = []        # [yön (ekranda), uzaklık (m)]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## items: her biri [ekrandaki yön (Vector2), oyuncuya uzaklık (m)].
func set_items(items: Array) -> void:
	_items = items
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var c := vp * 0.5
	var half := c - Vector2.ONE * INSET
	for it: Array in _items:
		var dir: Vector2 = it[0]
		var dist: float = it[1]
		if dir.length_squared() < 0.0001:
			continue
		dir = dir.normalized()
		# ekranın ortasından yön boyunca kenara kadar
		var tx := half.x / absf(dir.x) if absf(dir.x) > 0.0001 else INF
		var ty := half.y / absf(dir.y) if absf(dir.y) > 0.0001 else INF
		var p := c + dir * minf(tx, ty)
		var s := lerpf(26.0, 16.0, clampf((dist - 10.0) / 15.0, 0.0, 1.0))
		var side := dir.orthogonal()
		var pts := PackedVector2Array([p + dir * s, p - dir * s * 0.7 + side * s * 0.8, p - dir * s * 0.35, p - dir * s * 0.7 - side * s * 0.8])
		draw_colored_polygon(pts, COLOR)
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, EDGE, 3.0, true)
