extends RefCounted
## Haritadaki tek bir engel (ağaç, kaya, kar duvarı).
## Kural tarafında her engel bir "kapsül"dür: a–b doğru parçası ve onun çevresindeki yarıçap.
## Ağaç ve kayada a == b olur, yani düz bir daire. Kar duvarında a ile b duvarın iki ucudur.

var kind: String
var a: Vector2
var b: Vector2
var radius: float


func _init(p_kind: String, p_a: Vector2, p_b: Vector2, p_radius: float) -> void:
	kind = p_kind
	a = p_a
	b = p_b
	radius = p_radius


func center() -> Vector2:
	return (a + b) * 0.5


## Engelin tamamını içine alan dairenin yarıçapı (yerleştirme kontrolleri için).
func bound_radius() -> float:
	return a.distance_to(b) * 0.5 + radius


## a–b doğru parçası üzerinde p noktasına en yakın nokta.
func closest_point(p: Vector2) -> Vector2:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.000001:
		return a
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


## p noktasının engelin kenarına uzaklığı. Nokta engelin içindeyse eksi çıkar.
func edge_distance(p: Vector2) -> float:
	return p.distance_to(closest_point(p)) - radius
