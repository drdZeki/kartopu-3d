extends RefCounted
## Yerde duran bir güçlendirme (SPEC §9). Oyuncu üstünden geçince alır.

const Balance = preload("res://scripts/data/balance.gd")

var type: String
var pos: Vector2
var life: float = Balance.POWER_LIFE


func _init(p_type: String, p_pos: Vector2) -> void:
	type = p_type
	pos = p_pos
