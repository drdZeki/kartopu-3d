extends RefCounted
## Karlı çalılık: engel değildir, içinden geçilir. İçinde saklanılır (6. adımda).

var pos: Vector2
var radius: float
var use: float = 0.0     # bu çalılıkta harcanan gizlenme süresi
var cool: float = 0.0    # süre dolduysa kalan bekleme (bu sürede saklanılmaz)


func _init(p_pos: Vector2, p_radius: float) -> void:
	pos = p_pos
	radius = p_radius


func contains(p: Vector2) -> bool:
	return p.distance_to(pos) < radius
