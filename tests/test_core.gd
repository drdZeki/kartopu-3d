extends SceneTree
## Görüntüsüz kural testleri. Çalıştırma (proje klasöründe):
##   & "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/test_core.gd
## Her şey doğruysa en sonda "SONUÇ: BAŞARILI" yazar.

const Balance = preload("res://scripts/data/balance.gd")
const World = preload("res://scripts/core/world.gd")
const Obstacle = preload("res://scripts/core/obstacle.gd")
const Player = preload("res://scripts/core/player.gd")
const GameSim = preload("res://scripts/core/game_sim.gd")

const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _fails: int = 0
var _checks: int = 0


func _init() -> void:
	_test_closest_point()
	_test_generation()
	_test_open_field_speed()
	_test_blocked_by_tree()
	_test_slides_along_wall()
	_test_fence()
	_test_random_walks()
	_test_character_change()
	print("")
	print("%d kontrol yapıldı." % _checks)
	print("SONUÇ: " + ("BAŞARILI" if _fails == 0 else "%d HATA" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  HATA: " + what)


func _empty_world() -> World:
	var w := World.new()
	w.obstacles = []
	w.bushes = []
	return w


# ---------- Testler ----------

func _test_closest_point() -> void:
	print("Kapsül en yakın nokta")
	var wall := Obstacle.new("wall", Vector2(-1, 0), Vector2(1, 0), 0.35)
	_check(wall.closest_point(Vector2(0, 2)).is_equal_approx(Vector2(0, 0)), "orta nokta")
	_check(wall.closest_point(Vector2(5, 1)).is_equal_approx(Vector2(1, 0)), "uç nokta")
	_check(absf(wall.edge_distance(Vector2(0, 1)) - 0.65) < EPS, "kenar uzaklığı")
	var tree := Obstacle.new("tree", Vector2(3, 3), Vector2(3, 3), 0.6)
	_check(tree.closest_point(Vector2(9, 9)).is_equal_approx(Vector2(3, 3)), "daire merkez")


func _test_generation() -> void:
	print("Harita yerleşimi (200 farklı harita)")
	var short_obstacles := 0
	for s in 200:
		var w := World.new()
		w.generate(s)
		if w.obstacles.size() < Balance.OBSTACLE_COUNT:
			short_obstacles += 1
		_check(w.obstacles.size() >= Balance.OBSTACLE_COUNT - 2, "harita %d: engel sayısı %d" % [s, w.obstacles.size()])
		_check(w.bushes.size() == Balance.BUSH_COUNT, "harita %d: çalılık sayısı %d" % [s, w.bushes.size()])
		for i in w.obstacles.size():
			var o: Obstacle = w.obstacles[i]
			_check(o.center().length() >= Balance.OBSTACLE_CENTER_CLEAR, "harita %d: engel ortaya çok yakın" % s)
			_check(absf(o.center().x) <= w.half - Balance.OBSTACLE_EDGE_MARGIN + EPS, "harita %d: engel kenarda" % s)
			for j in range(i + 1, w.obstacles.size()):
				var o2: Obstacle = w.obstacles[j]
				var gap := o.center().distance_to(o2.center()) - o.bound_radius() - o2.bound_radius()
				_check(gap >= Balance.OBSTACLE_GAP - EPS, "harita %d: iki engel çok yakın (%.2f)" % [s, gap])
		for i in w.bushes.size():
			var b = w.bushes[i]
			_check(b.pos.length() >= Balance.BUSH_CENTER_CLEAR, "harita %d: çalılık ortaya çok yakın" % s)
			for o: Obstacle in w.obstacles:
				_check(o.edge_distance(b.pos) >= Balance.BUSH_RADIUS + Balance.BUSH_OBSTACLE_GAP - EPS, "harita %d: çalılık engele çok yakın" % s)
			for j in range(i + 1, w.bushes.size()):
				_check(b.pos.distance_to(w.bushes[j].pos) >= Balance.BUSH_GAP - EPS, "harita %d: iki çalılık çok yakın" % s)
		# oyuncu ortada başlıyor: orası boş olmalı
		_check(w.is_free(Vector2.ZERO, Balance.PLAYER_BASE_RADIUS * 1.2), "harita %d: başlangıç noktası dolu" % s)
		# aynı tohum aynı haritayı vermeli
		var w2 := World.new()
		w2.generate(s)
		_check(w2.obstacles.size() == w.obstacles.size() and (w.obstacles.is_empty() or w2.obstacles[0].a == w.obstacles[0].a), "harita %d: aynı tohum farklı harita" % s)
	print("  20'den az engelli harita: %d / 200" % short_obstacles)


func _test_open_field_speed() -> void:
	print("Boş alanda hız")
	for c: Dictionary in Balance.CHARACTERS:
		var w := _empty_world()
		var p := Player.new()
		p.setup(c["id"])
		for i in 60:
			p.step(DT, Vector2.RIGHT, w)
		var expected: float = c["speed"]
		_check(absf(p.pos.x - expected) < 0.01, "%s 1 sn'de %.2f m gitmeli, %.2f gitti" % [c["id"], expected, p.pos.x])
		_check(absf(p.walk_ratio() - 1.0) < 0.01, "%s tam hızda yürüme oranı 1 olmalı" % c["id"])
	# yarım joystick = yarım hız
	var w2 := _empty_world()
	var p2 := Player.new()
	p2.setup("pamuk")
	for i in 60:
		p2.step(DT, Vector2(0, 0.5), w2)
	_check(absf(p2.pos.y - 2.55) < 0.01, "yarım joystick yarım hız")
	_check(p2.facing.is_equal_approx(Vector2(0, 1)), "baktığı yön")


func _test_blocked_by_tree() -> void:
	print("Ağaca çarpma")
	var w := _empty_world()
	w.obstacles = [Obstacle.new("tree", Vector2(3, 0), Vector2(3, 0), 0.6)]
	var p := Player.new()
	p.setup("pamuk")
	for i in 120:
		p.step(DT, Vector2.RIGHT, w)
	_check(absf(p.pos.x - (3.0 - 0.6 - 0.5)) < 0.01, "ağacın önünde durmalı, x = %.3f" % p.pos.x)
	_check(p.walk_ratio() < 0.05, "dayanınca yürüme oranı ~0 olmalı")


func _test_slides_along_wall() -> void:
	print("Duvar boyunca kayma")
	var w := _empty_world()
	# uzun duvar: kardan adam 1 sn içinde ucuna varıp dolanamasın
	w.obstacles = [Obstacle.new("wall", Vector2(2, -3), Vector2(2, 12), 0.35)]
	var p := Player.new()
	p.setup("pamuk")
	for i in 60:
		p.step(DT, Vector2(1, 1).normalized(), w)
	_check(p.pos.x <= 2.0 - 0.35 - 0.5 + EPS, "duvarın içine girmemeli")
	_check(p.pos.y > 3.0, "duvar boyunca kaymaya devam etmeli, y = %.2f" % p.pos.y)


func _test_fence() -> void:
	print("Çit")
	var w := _empty_world()
	var p := Player.new()
	p.setup("kocabuz")
	for i in 600:
		p.step(DT, Vector2(-1, -1).normalized(), w)
	var limit := w.half - p.radius
	_check(absf(p.pos.x + limit) < EPS and absf(p.pos.y + limit) < EPS, "köşede çitin içinde kalmalı")


func _test_random_walks() -> void:
	print("Rastgele yürüyüşler (50 harita × 1200 adım)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var worst := 0.0
	for s in 50:
		var sim := GameSim.new()
		sim.new_game(1000 + s, Balance.CHARACTERS[s % 4]["id"])
		var move := Vector2.ZERO
		for i in 1200:
			if i % 30 == 0:
				move = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(0.3, 1.0)
			sim.step(DT, move)
			var pl := sim.player
			for o: Obstacle in sim.world.obstacles:
				var overlap := pl.radius - o.edge_distance(pl.pos)
				worst = maxf(worst, overlap)
			_check(absf(pl.pos.x) <= sim.world.half - pl.radius + EPS and absf(pl.pos.y) <= sim.world.half - pl.radius + EPS, "harita %d: çitin dışına çıktı" % s)
	_check(worst < 0.01, "engelin içine en fazla %.4f m girdi" % worst)


func _test_character_change() -> void:
	print("Karakter değiştirme")
	var sim := GameSim.new()
	sim.new_game(7, "pamuk")
	sim.step(DT, Vector2.RIGHT)
	sim.change_character("kocabuz")
	_check(sim.player.char_id == "kocabuz", "kimlik")
	_check(absf(sim.player.radius - 0.6) < EPS, "Koca Buz yarıçapı 0,6")
	_check(absf(sim.player.speed - 4.0) < EPS, "Koca Buz hızı 4,0")
	_check(Balance.character("yok")["id"] == "pamuk", "bilinmeyen kimlik ilk karakteri verir")
