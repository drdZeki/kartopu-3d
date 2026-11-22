extends RefCounted
## Klavye tuşları (bilgisayarda test için). Tuşlar fiziksel konuma göre tanınır,
## böylece Türkçe Q ve F klavyede de WASD aynı yerdedir.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
}


static func ensure_actions() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


## Klavyeden gelen yürüme yönü. Ekranın yukarısı = kuzey = -y.
static func keyboard_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
