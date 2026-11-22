extends RefCounted
## Haritadaki kar yığını: üstünden geçen oyuncu kartopu toplar.

const Balance = preload("res://scripts/data/balance.gd")

var pos: Vector2
var amount: int


func _init(p_pos: Vector2, p_amount: int) -> void:
	pos = p_pos
	amount = p_amount


func radius() -> float:
	return Balance.pile_radius(amount)
