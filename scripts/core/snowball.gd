extends RefCounted
## Uçan bir kartopu (kural tarafı). Yer düzleminde düz gider; yükseklik ve yay sadece görüntüde.

var pos: Vector2
var prev_pos: Vector2           # bir önceki adımdaki konum (görüntü arayı yumuşatır)
var vel: Vector2
var radius: float
var power: int
var max_range: float
var traveled: float = 0.0
var owner_id: int = 0           # 0 = oyuncu (ileride Haylazlar ve online oyuncular)
var alive: bool = true
var freeze: bool = false        # Buz Topu güçlendirmesiyle atıldı: vurduğu Haylazı dondurur


func _init(p_pos: Vector2, p_vel: Vector2, p_radius: float, p_power: int, p_range: float) -> void:
	pos = p_pos
	prev_pos = p_pos
	vel = p_vel
	radius = p_radius
	power = p_power
	max_range = p_range


## Menzilin ne kadarını gitti (0–1).
func progress() -> float:
	return clampf(traveled / max_range, 0.0, 1.0)
