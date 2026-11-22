extends SceneTree
## Görüntüsüz kural testleri. Çalıştırma (proje klasöründe):
##   & "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/test_core.gd
## Her şey doğruysa en sonda "SONUÇ: BAŞARILI" yazar.

const Balance = preload("res://scripts/data/balance.gd")
const World = preload("res://scripts/core/world.gd")
const Obstacle = preload("res://scripts/core/obstacle.gd")
const Player = preload("res://scripts/core/player.gd")
const GameSim = preload("res://scripts/core/game_sim.gd")
const Pile = preload("res://scripts/core/pile.gd")
const Haylaz = preload("res://scripts/core/haylaz.gd")
const Snowball = preload("res://scripts/core/snowball.gd")
const Power = preload("res://scripts/core/power.gd")
const Bush = preload("res://scripts/core/bush.gd")

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
	_test_throw_basics()
	_test_ball_flight()
	_test_auto_aim_and_hits()
	_test_haylaz_behaviors()
	_test_hearts()
	_test_storms()
	_test_score_combo()
	_test_powers()
	_test_kral()
	_test_hiding()
	_test_piles()
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


## Engelsiz, yığınsız, fırtınasız bir oyun (kuralları yalın denemek için).
func _bare_sim(char_id: String = "pamuk") -> GameSim:
	var sim := GameSim.new()
	sim.new_game(1, char_id)
	sim.storms_enabled = false
	sim.world.obstacles = []
	sim.world.bushes = []
	sim.piles = []
	sim.take_events()
	return sim


## Kardan çıkışı bitmiş bir Haylaz ekler.
func _add_haylaz(sim: GameSim, type: String, pos: Vector2) -> Haylaz:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var h := Haylaz.new(900 + sim.haylazlar.size(), type, pos, 1, rng)
	h.spawn_left = 0.0
	sim.haylazlar.append(h)
	return h


func _count(events: Array, type: String) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type).size()


func _test_throw_basics() -> void:
	print("Atış: kartopu sayısı ve bekleme süresi")
	var sim := _bare_sim("pamuk")
	_check(sim.player.ammo == 10, "Pamuk 10 kartopuyla başlar")
	var used := sim.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.RIGHT})
	_check(used and sim.player.ammo == 9 and sim.balls.size() == 1, "ilk atış")
	_check(_count(sim.take_events(), "throw") == 1, "atış olayı")
	_check(sim.player.facing.is_equal_approx(Vector2.RIGHT), "atış yönüne döner")
	# bekleme süresi (0,26 sn) dolmadan ikinci atış olmaz
	used = sim.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.RIGHT})
	_check(not used and sim.player.ammo == 9, "bekleme süresinde atış yok")
	for i in 15:
		sim.step(DT, Vector2.ZERO)
	used = sim.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.RIGHT})
	_check(used and sim.player.ammo == 8, "bekleme bitince atış")
	# kartopu bitince "empty" olayı, atış yok
	sim.player.ammo = 0
	for i in 20:
		sim.step(DT, Vector2.ZERO)
	sim.take_events()
	var balls_before := sim.balls.size()
	used = sim.step(DT, Vector2.ZERO, {"auto": true})
	var ev := sim.take_events()
	_check(used and _count(ev, "empty") == 1 and _count(ev, "throw") == 0, "kartopu yokken uyarı")
	_check(sim.balls.size() <= balls_before, "kartopu yokken yeni kartopu çıkmaz")
	# atış yönü yürürken kısa süre korunur
	var sim2 := _bare_sim("pamuk")
	sim2.step(DT, Vector2.DOWN, {"auto": false, "dir": Vector2.RIGHT})
	sim2.step(DT, Vector2.DOWN)
	_check(sim2.player.facing.is_equal_approx(Vector2.RIGHT), "atıştan hemen sonra yürüse de atış yönüne bakar")
	for i in 30:
		sim2.step(DT, Vector2.DOWN)
	_check(sim2.player.facing.is_equal_approx(Vector2.DOWN), "sonra yürüdüğü yöne döner")


func _test_ball_flight() -> void:
	print("Kartopu uçuşu")
	# boş alanda menzil sonunda yere düşer
	var sim := _bare_sim("keskin")
	sim.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.UP})
	var landed := 0
	var land_pos := Vector2.ZERO
	for i in 120:
		sim.step(DT, Vector2.ZERO)
		for e: Dictionary in sim.take_events():
			if e["type"] == "land":
				landed += 1
				land_pos = e["pos"]
	_check(landed == 1, "bir kez yere düşer")
	var start_y := -0.5 * 0.8
	_check(absf((start_y - land_pos.y) - Balance.BALL_RANGE) < 0.4, "menzil ~14 m (gitti: %.2f)" % (start_y - land_pos.y))
	_check(sim.balls.is_empty(), "düşen kartopu silinir")
	# engele çarpınca durur
	var sim2 := _bare_sim("pamuk")
	sim2.world.obstacles = [Obstacle.new("rock", Vector2(5, 0), Vector2(5, 0), 0.5)]
	sim2.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.RIGHT})
	var splat := {}
	for i in 60:
		sim2.step(DT, Vector2.ZERO)
		for e: Dictionary in sim2.take_events():
			if e["type"] == "splat":
				splat = e
	_check(not splat.is_empty(), "kayaya çarpınca 'splat'")
	if not splat.is_empty():
		var hit: Vector2 = splat["pos"]
		_check(hit.x < 5.0 - 0.5 + 0.01 and hit.x > 5.0 - 0.5 - 0.16 - 0.25, "kayanın önünde durur (x = %.2f)" % hit.x)
	# nişan çizgisi için ışın: engelin önünde biter, boşlukta menzil kadar gider
	var w := _empty_world()
	w.obstacles = [Obstacle.new("tree", Vector2(6, 0), Vector2(6, 0), 0.6)]
	var hit_d := w.cast(Vector2.ZERO, Vector2.RIGHT, 0.16, 14.0)
	_check(absf(hit_d - (6.0 - 0.6 - 0.16)) < 0.15, "ışın ağacın önünde biter (%.2f)" % hit_d)
	_check(absf(w.cast(Vector2.ZERO, Vector2.UP, 0.16, 14.0) - 14.0) < 0.01, "boşlukta menzil kadar gider")
	_check(w.cast(Vector2(w.half - 2.0, 0), Vector2.RIGHT, 0.16, 14.0) < 2.05, "çitte biter")
	# çite çarpınca durur
	var sim3 := _bare_sim("pamuk")
	sim3.player.pos = Vector2(sim3.world.half - 3.0, 0)
	sim3.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.RIGHT})
	var fence_hit := false
	for i in 60:
		sim3.step(DT, Vector2.ZERO)
		for e: Dictionary in sim3.take_events():
			if e["type"] == "splat":
				var p: Vector2 = e["pos"]
				fence_hit = absf(p.x - sim3.world.half) < 0.01
	_check(fence_hit, "çite çarpar")


func _test_auto_aim_and_hits() -> void:
	print("Otomatik nişan ve Haylazı vurma")
	var sim := _bare_sim("pamuk")
	var near := _add_haylaz(sim, "atici", Vector2(0, -6))
	var far := _add_haylaz(sim, "atici", Vector2(9, 0))
	near.throw_timer = 99.0
	far.throw_timer = 99.0
	near.speed = 0.0   # hareketsiz hedef: isabet sayısı rastgele yan kaymaya bağlı olmasın
	_check(sim.auto_aim_dir().y < -0.95, "en yakın Haylaza nişan alır")
	# iki isabet: önce "hit", sonra "down"
	var hits := 0
	var downs := 0
	for k in 2:
		near.pos = Vector2(0, -6)
		sim.player.cooldown_left = 0.0
		sim.step(DT, Vector2.ZERO, {"auto": true})
		for i in 40:
			sim.step(DT, Vector2.ZERO)
			for e: Dictionary in sim.take_events():
				if e["type"] == "haylaz_hit" and e["haylaz"] == near:
					hits += 1
				if e["type"] == "haylaz_down" and e["haylaz"] == near:
					downs += 1
	_check(hits == 1 and downs == 1, "atıcı 2 isabette dağılır (hit %d, down %d)" % [hits, downs])
	_check(not sim.haylazlar.has(near) and sim.kills == 1, "dağılan Haylaz listeden çıkar, sayılır")
	# kardan çıkarken vurulamaz ve nişan alınmaz
	var sim2 := _bare_sim("pamuk")
	var fresh := _add_haylaz(sim2, "atici", Vector2(0, -6))
	fresh.spawn_left = 5.0
	sim2.player.facing = Vector2.LEFT
	_check(sim2.auto_aim_dir().is_equal_approx(Vector2.LEFT), "kardan çıkan Haylaza nişan alınmaz")
	sim2.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.UP})
	for i in 40:
		sim2.step(DT, Vector2.ZERO)
	_check(fresh.hp == fresh.max_hp, "kardan çıkarken vurulamaz")
	# hareket eden hedefe önden nişan
	var dir := GameSim.aim_at(Vector2.ZERO, Vector2(0, -10), Vector2(3, 0), 13.5)
	_check(dir.x > 0.1, "hareket eden hedefin önüne nişan alır")
	# havada çarpışan kartopları
	var sim3 := _bare_sim("pamuk")
	var enemy_ball := Snowball.new(Vector2(0, -6), Vector2(0, 8), 0.175, 1, 16.0)
	enemy_ball.owner_id = 5
	sim3.balls.append(enemy_ball)
	sim3.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.UP})
	var clash := 0
	for i in 40:
		sim3.step(DT, Vector2.ZERO)
		clash += _count(sim3.take_events(), "ball_clash")
	_check(clash == 1 and sim3.player.hearts == sim3.player.max_hearts, "havada çarpışan kartopları dağılır, oyuncu üşümez")


func _test_haylaz_behaviors() -> void:
	print("Haylaz davranışları")
	# atıcı: oyuncudan 5,25–8,25 m arasında durur ve kartopu atar
	var sim := _bare_sim("kocabuz")
	sim.player.hearts = 99
	var a := _add_haylaz(sim, "atici", Vector2(0, -13))
	var throws := 0
	for i in 60 * 10:
		sim.step(DT, Vector2.ZERO)
		throws += _count(sim.take_events(), "enemy_throw")
	var d := a.pos.distance_to(sim.player.pos)
	_check(d > Balance.ATICI_NEAR - 0.6 and d < Balance.ATICI_FAR + 0.6, "atıcı mesafesini korur (%.2f m)" % d)
	_check(throws >= 3, "atıcı kartopu atar (%d)" % throws)
	# koşucu: üstüne koşar, değince üşütür, sersemler ve geri seker
	var sim2 := _bare_sim("pamuk")
	var k := _add_haylaz(sim2, "kosucu", Vector2(0, -8))
	var hurt_at := -1
	for i in 60 * 5:
		sim2.step(DT, Vector2.ZERO)
		if _count(sim2.take_events(), "player_hurt") > 0 and hurt_at < 0:
			hurt_at = i
			break
	_check(hurt_at > 0, "koşucu değince oyuncu üşür")
	_check(sim2.player.hearts == sim2.player.max_hearts - 1, "bir kalp gider")
	_check(k.stun > 0.0 and k.pos.distance_to(sim2.player.pos) > k.radius + sim2.player.radius, "koşucu sersemler ve geri seker")
	# koca: 3'lü yelpaze
	var sim3 := _bare_sim("pamuk")
	sim3.player.hearts = 99
	_add_haylaz(sim3, "koca", Vector2(0, -12))
	var koca_throws := 0
	for i in 60 * 4:
		sim3.step(DT, Vector2.ZERO)
		koca_throws += _count(sim3.take_events(), "enemy_throw")
	_check(koca_throws >= 3 and koca_throws % 3 == 0, "koca 3'lü atar (%d)" % koca_throws)
	# engelin arkasında takılmaz: duvarın arkasından dolaşıp yaklaşır
	var sim4 := _bare_sim("pamuk")
	sim4.player.hearts = 99
	sim4.world.obstacles = [Obstacle.new("wall", Vector2(-1.5, -5), Vector2(1.5, -5), 0.35)]
	var kk := _add_haylaz(sim4, "kosucu", Vector2(0, -8))
	var reached := false
	for i in 60 * 6:
		sim4.step(DT, Vector2.ZERO)
		if _count(sim4.take_events(), "player_hurt") > 0:
			reached = true
			break
	_check(reached, "koşucu duvarın arkasından dolaşıp ulaşır")
	# Haylazlar birbirinin içine girmez
	var sim5 := _bare_sim("pamuk")
	sim5.player.hearts = 99
	for i in 5:
		_add_haylaz(sim5, "koca", Vector2(i * 0.2, -10))
	for i in 120:
		sim5.step(DT, Vector2.ZERO)
	var overlap := 0.0
	for i in sim5.haylazlar.size():
		for j in range(i + 1, sim5.haylazlar.size()):
			var h1: Haylaz = sim5.haylazlar[i]
			var h2: Haylaz = sim5.haylazlar[j]
			overlap = maxf(overlap, h1.radius + h2.radius - h1.pos.distance_to(h2.pos))
	_check(overlap < 0.2, "Haylazlar iç içe girmez (en fazla %.2f m)" % overlap)


func _test_hearts() -> void:
	print("Can, dokunulmazlık, oyun sonu")
	var sim := _bare_sim("pamuk")
	_check(sim.player.hearts == 5, "Pamuk 5 kalple başlar")
	sim._hurt_player()
	sim._hurt_player()
	_check(sim.player.hearts == 4, "dokunulmazken ikinci kez üşümez")
	for i in 70:
		sim.step(DT, Vector2.ZERO)
	sim._hurt_player()
	_check(sim.player.hearts == 3, "dokunulmazlık bitince yine üşür")
	# dokunulmazken Haylaz kartopu içinden geçer
	var b := Snowball.new(Vector2(0, -3), Vector2(0, 8), 0.175, 1, 16.0)
	b.owner_id = 5
	sim.balls.append(b)
	for i in 50:
		sim.step(DT, Vector2.ZERO)
	_check(sim.player.hearts == 3, "dokunulmazken kartopu içinden geçer")
	# dokunulmazlık bitince kartopu üşütür
	var b2 := Snowball.new(Vector2(0, -3), Vector2(0, 8), 0.175, 1, 16.0)
	b2.owner_id = 5
	sim.balls.append(b2)
	for i in 50:
		sim.step(DT, Vector2.ZERO)
	_check(sim.player.hearts == 2, "Haylaz kartopu üşütür")
	# son kalp: oyun biter
	sim.player.hearts = 1
	sim.player.invulnerable = 0.0
	sim.take_events()
	sim._hurt_player()
	var ev := sim.take_events()
	_check(sim.game_over and _count(ev, "game_over") == 1, "kalpler bitince oyun biter")
	var p := sim.player.pos
	sim.step(DT, Vector2.RIGHT)
	_check(sim.player.pos == p, "oyun bitince oyuncu hareket etmez")


func _test_storms() -> void:
	print("Fırtınalar")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var l1 := GameSim.storm_list(1, rng)
	_check(l1.size() == 4 and l1.count("atici") == 4, "1. fırtına: 4 atıcı")
	var koca_seen := false
	var early_ok := true
	for i in 50:
		var l2 := GameSim.storm_list(2, rng)
		if l2.size() != 6 or l2.has("koca"):
			early_ok = false
		var l6 := GameSim.storm_list(6, rng)
		if l6.size() != 12:
			early_ok = false
		koca_seen = koca_seen or l6.has("koca")
	_check(early_ok, "2. fırtınada 6 Haylaz, koca yok; 6. fırtınada 12")
	_check(koca_seen, "3. fırtınadan sonra koca gelir")
	_check(Balance.haylaz_hp("koca", 1) == 6 and Balance.haylaz_hp("koca", 7) == 9, "6 fırtınada bir dayanıklılık ×1,5")
	_check(absf(Balance.haylaz_speed_mul(20) - 1.4) < 0.001, "hız artışı en fazla %40")

	var sim := GameSim.new()
	sim.new_game(11, "pamuk")
	sim.player.hearts = 99
	sim.player.max_hearts = 99
	var started := {}
	for i in 90:
		sim.step(DT, Vector2.ZERO)
		for e: Dictionary in sim.take_events():
			if e["type"] == "storm_start":
				started = e
	_check(not started.is_empty() and started["storm"] == 1 and started["count"] == 4, "1,3 sn sonra 1. fırtına başlar, 4 Haylaz")
	for i in 240:
		sim.step(DT, Vector2.ZERO)
	_check(sim.haylazlar.size() == 4, "4 Haylaz sahada (%d)" % sim.haylazlar.size())
	# hepsi dağılınca fırtına diner, kalp gelir
	sim.player.max_hearts = 5
	sim.player.hearts = 4
	for h: Haylaz in sim.haylazlar:
		h.alive = false
	sim.haylazlar.clear()
	var ended := {}
	for i in 5:
		sim.step(DT, Vector2.ZERO)
		for e: Dictionary in sim.take_events():
			if e["type"] == "storm_end":
				ended = e
	_check(not ended.is_empty() and ended["healed"] and sim.player.hearts == 5, "fırtına dinince +1 kalp")
	var next := {}
	for i in 60 * 4:
		sim.step(DT, Vector2.ZERO)
		for e: Dictionary in sim.take_events():
			if e["type"] == "storm_start":
				next = e
	_check(not next.is_empty() and next["storm"] == 2, "3,5 sn moladan sonra 2. fırtına")
	# belirme uzaklığı ve aynı anda en fazla 6 + fırtına
	var spawn_ok := true
	var max_alive := 0
	var sim2 := GameSim.new()
	sim2.new_game(12, "pamuk")
	sim2.player.hearts = 999
	sim2.player.max_hearts = 999
	sim2.storm = 8   # 9. fırtına: 17 Haylaz (Kar Kralı fırtınası değil; kralın çağırdıkları yanında belirir)
	for i in 60 * 30:
		sim2.step(DT, Vector2.ZERO)
		for e: Dictionary in sim2.take_events():
			if e["type"] == "haylaz_spawn":
				var h: Haylaz = e["haylaz"]
				if h.pos.distance_to(sim2.player.pos) < Balance.HAYLAZ_SPAWN_MIN_DIST - 0.01:
					spawn_ok = false
		max_alive = maxi(max_alive, sim2.haylazlar.size())
	_check(spawn_ok, "Haylazlar oyuncudan en az 10,75 m uzakta belirir")
	_check(max_alive <= Balance.STORM_MAX_ALIVE_BASE + 9 and max_alive >= 10, "aynı anda en fazla 15 (en fazla %d oldu)" % max_alive)


func _test_score_combo() -> void:
	print("Puan ve kombo")
	var sim := _bare_sim("pamuk")
	sim._rng.seed = 1
	# 7 koşucuyu art arda dağıt: çarpan 1,1,2,2,2,3,3 → 75 × (1+1+2+2+2+3+3)
	var expected := 0
	for i in 7:
		var h := _add_haylaz(sim, "kosucu", Vector2(0, -20))
		sim._haylaz_down(h, Vector2.UP)
		expected += 75 * sim.combo_mult()
	_check(sim.score == expected and sim.score == 75 * 14, "kombo çarpanı (puan %d)" % sim.score)
	_check(sim.combo_mult() == 3, "7 dağıtmada çarpan 3")
	for i in 20:
		var h := _add_haylaz(sim, "kosucu", Vector2(0, -20))
		sim._haylaz_down(h, Vector2.UP)
	_check(sim.combo_mult() == Balance.COMBO_MAX, "çarpan en fazla 5")
	# süre dolunca kombo biter
	for i in int(Balance.COMBO_WINDOW * 60) + 2:
		sim.step(DT, Vector2.ZERO)
	_check(sim.combo == 0, "2,6 sn içinde dağıtmazsa kombo biter")
	# üşüyünce kombo biter
	sim._haylaz_down(_add_haylaz(sim, "kosucu", Vector2(0, -20)), Vector2.UP)
	sim._hurt_player()
	_check(sim.combo == 0, "üşüyünce kombo biter")
	# fırtına bonusu
	var sim2 := GameSim.new()
	sim2.new_game(5, "pamuk")
	sim2.player.hearts = 99
	sim2.storm = 2
	sim2.in_storm = true
	sim2.storm_queue.clear()
	sim2.haylazlar.clear()
	var before := sim2.score
	sim2.step(DT, Vector2.ZERO)
	_check(sim2.score - before == 100, "2. fırtına bonusu 100")


func _test_powers() -> void:
	print("Güçlendirmeler")
	# yere düşer, 12 sn sonra kaybolur, üstünden geçilince alınır
	var sim := _bare_sim("pamuk")
	sim.powerups = [Power.new("uclu", Vector2(5, 0))]
	for i in 60 * 11:
		sim.step(DT, Vector2.ZERO)
	_check(sim.powerups.size() == 1, "11 sn sonra hâlâ yerde")
	for i in 70:
		sim.step(DT, Vector2.ZERO)
	_check(sim.powerups.is_empty(), "12 sn sonra kaybolur")
	sim.powerups = [Power.new("uclu", Vector2(0, 0.6))]
	sim.step(DT, Vector2.ZERO)
	_check(sim.player.has_power("uclu") and sim.powerups.is_empty(), "üstünden geçince alınır")
	# üçlü atış: 3 kartopu, 1 kartopu harcar
	var ammo := sim.player.ammo
	sim.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.UP})
	_check(sim.balls.size() == 3 and sim.player.ammo == ammo - 1, "üçlü atış 3 kartopu atar, 1 harcar")
	# süre bitince kalkar
	for i in 60 * 10 + 5:
		sim.step(DT, Vector2.ZERO)
	_check(not sim.player.has_power("uclu"), "10 sn sonra biter")

	# Buz Topu: vurulan Haylaz donar, kıpırdamaz
	var sim2 := _bare_sim("kocabuz")   # güç 2: koca hemen dağılmasın diye koca kullan
	sim2.player.powers["buz"] = 9.0
	var koca := _add_haylaz(sim2, "koca", Vector2(0, -6))
	koca.throw_timer = 99.0
	sim2.step(DT, Vector2.ZERO, {"auto": true})
	var froze := false
	for i in 40:
		sim2.step(DT, Vector2.ZERO)
		froze = froze or _count(sim2.take_events(), "freeze") > 0
	_check(froze and koca.frozen > 0.0, "Buz Topu'yla vurulan donar")
	var p := koca.pos
	for i in 60:
		sim2.step(DT, Vector2.ZERO)
	_check(koca.pos == p, "donmuş Haylaz kıpırdamaz")

	# Buz Küresi: +1 kalp; kalpler doluysa +200 puan
	var sim3 := _bare_sim("pamuk")
	sim3.player.hearts = 3
	sim3._apply_power("kure", Vector2.ZERO)
	_check(sim3.player.hearts == 4, "Buz Küresi +1 kalp")
	sim3.player.hearts = sim3.player.max_hearts
	var s := sim3.score
	sim3._apply_power("kure", Vector2.ZERO)
	_check(sim3.score - s == Balance.ORB_FULL_POINTS, "kalpler doluyken +200 puan")

	# Kalkan: üşümez, kartoplarını durdurur
	var sim4 := _bare_sim("pamuk")
	sim4.player.powers["kalkan"] = 10.0
	var b := Snowball.new(Vector2(0, -3), Vector2(0, 8), 0.175, 1, 16.0)
	b.owner_id = 5
	sim4.balls.append(b)
	var blocked := 0
	for i in 40:
		sim4.step(DT, Vector2.ZERO)
		blocked += _count(sim4.take_events(), "shield_block")
	sim4._hurt_player()
	_check(blocked == 1 and sim4.player.hearts == sim4.player.max_hearts, "kalkan kartopunu durdurur, üşütmez")

	# Kar Mıknatısı: 7 m içindeki yığın gelir, uzaktaki gelmez
	var sim5 := _bare_sim("pamuk")
	sim5.player.ammo = 0
	sim5.player.powers["miknatis"] = 12.0
	sim5.piles = [Pile.new(Vector2(6, 0), 4), Pile.new(Vector2(0, 12), 4)]
	for i in 60:
		sim5.step(DT, Vector2.ZERO)
	_check(sim5.player.ammo == 4, "mıknatıs yakındaki yığını çeker (%d)" % sim5.player.ammo)
	_check(sim5.piles.size() == 1 and sim5.piles[0].pos.is_equal_approx(Vector2(0, 12)), "uzaktaki yığın yerinde kalır")

	# Kartopu Yağmuru: kartopu harcamaz, daha hızlı atar, bitince kartopu dolu
	var sim6 := _bare_sim("pamuk")
	sim6.player.ammo = 2
	sim6._apply_power("yagmur", Vector2.ZERO)
	_check(sim6.player.ammo == sim6.player.capacity, "alınca kartopu dolar")
	var throws := 0
	for i in 60:
		sim6.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.UP})
		throws += _count(sim6.take_events(), "throw")
	_check(sim6.player.ammo == sim6.player.capacity, "kartopu harcamaz")
	_check(throws >= 6, "%%40 daha seri atar (1 sn'de %d atış)" % throws)
	sim6.player.ammo = 0
	for i in 60 * 7:
		sim6.step(DT, Vector2.ZERO)
	_check(not sim6.player.has_power("yagmur") and sim6.player.ammo == sim6.player.capacity, "bitince kartopu dolu")

	# düşme: tek kalpte güçlendirmelerin çoğu Buz Küresi
	var sim7 := _bare_sim("pamuk")
	sim7.player.hearts = 1
	var orbs := 0
	for i in 400:
		sim7._drop_power(Vector2.ZERO)
	for w: Power in sim7.powerups:
		if w.type == "kure":
			orbs += 1
	_check(orbs > 400 * 0.5, "tek kalpte Buz Küresi daha sık (%d/400)" % orbs)


func _test_kral() -> void:
	print("Kar Kralı")
	var rng := RandomNumberGenerator.new()
	var l5 := GameSim.storm_list(5, rng)
	var l10 := GameSim.storm_list(10, rng)
	_check(l5 == ["kral", "atici", "atici"], "5. fırtına: Kar Kralı + 2 atıcı")
	_check(l10.size() == 5 and l10[0] == "kral" and l10.count("atici") == 4, "10. fırtına: Kar Kralı + 4 atıcı")
	_check(Balance.haylaz_hp("kral", 5) == 50 and Balance.haylaz_hp("kral", 10) == 70, "dayanıklılık 30 + fırtına × 4")

	# saldırı sırası: halka (14) → oyuncuya 5'li → 2 koşucu çağırma
	var sim := _bare_sim("pamuk")
	sim.player.hearts = 99
	var k := _add_haylaz(sim, "kral", Vector2(0, -5.5))
	var throws: Array = []
	var summons := 0
	for i in 60 * 8:
		sim.step(DT, Vector2.ZERO)
		for e: Dictionary in sim.take_events():
			if e["type"] == "enemy_throw" and e["haylaz"] == k:
				throws.append(e)
			if e["type"] == "kral_summon":
				summons += 1
	_check(throws.size() >= Balance.KRAL_RING + Balance.KRAL_AIMED, "halka ve 5'li atış (%d kartopu)" % throws.size())
	_check(summons >= 1, "koşucu çağırır")
	var kosucu := sim.haylazlar.filter(func(h: Haylaz) -> bool: return h.type == "kosucu").size()
	_check(kosucu >= 1, "çağrılan koşucular sahada (%d)" % kosucu)

	# değince oyuncuyu üşütür ve iter
	var sim2 := _bare_sim("pamuk")
	var k2 := _add_haylaz(sim2, "kral", Vector2(0, -1.6))
	k2.throw_timer = 99.0
	var before := sim2.player.pos
	sim2.step(DT, Vector2.ZERO)
	_check(sim2.player.hearts == sim2.player.max_hearts - 1, "değince üşütür")
	_check(sim2.player.pos.distance_to(before) > 0.8, "oyuncuyu iter (%.2f m)" % sim2.player.pos.distance_to(before))

	# dağılınca 2 güçlendirme ve 6'lık yığın, Buz Topu kısa dondurur
	var sim3 := _bare_sim("pamuk")
	var k3 := _add_haylaz(sim3, "kral", Vector2(0, -8))
	sim3._haylaz_down(k3, Vector2.UP)
	var six := sim3.piles.filter(func(p: Pile) -> bool: return p.amount == 6).size()
	_check(sim3.powerups.size() == 2 and six == 1, "2 güçlendirme ve 6'lık yığın bırakır")
	_check(sim3.score == 1500, "1500 puan")
	var sim4 := _bare_sim("pamuk")
	sim4.player.powers["buz"] = 9.0
	var k4 := _add_haylaz(sim4, "kral", Vector2(0, -6))
	k4.throw_timer = 99.0
	sim4.step(DT, Vector2.ZERO, {"auto": true})
	for i in 40:
		sim4.step(DT, Vector2.ZERO)
		if k4.frozen > 0.0:
			break
	_check(k4.frozen > 0.0 and k4.frozen <= Balance.KRAL_FREEZE_TIME, "Buz Topu Kar Kralı'nı 0,6 sn dondurur")


func _hide_sim() -> GameSim:
	var sim := _bare_sim("pamuk")
	sim.world.bushes = [Bush.new(Vector2(0, 0), 1.1)]
	sim.player.pos = Vector2.ZERO
	sim.player.hearts = 99
	sim.player.max_hearts = 99
	return sim


func _test_hiding() -> void:
	print("Çalılıkta saklanma")
	var sim := _hide_sim()
	sim.step(DT, Vector2.ZERO)
	_check(sim.hidden and _count(sim.take_events(), "hidden") == 1, "çalılıkta gizlenir")
	# Haylaz kartopları içinden geçer
	var b := Snowball.new(Vector2(0, -3), Vector2(0, 8), 0.175, 1, 16.0)
	b.owner_id = 5
	sim.balls.append(b)
	for i in 40:
		sim.step(DT, Vector2.ZERO)
	_check(sim.player.hearts == 99, "gizliyken kartopu üşütmez")
	# atıcı atmaz, uzağa arar; koşucu çalıya giremez, üşütmez
	var a := _add_haylaz(sim, "atici", Vector2(0, -7))
	a.throw_timer = 0.0
	var k := _add_haylaz(sim, "kosucu", Vector2(5, 0))
	var thrown := 0
	var closest := 99.0
	for i in 60 * 5:
		sim.step(DT, Vector2.ZERO)
		thrown += _count(sim.take_events(), "enemy_throw")
		closest = minf(closest, k.pos.length())
		if i == 60 * 4:
			sim.world.bushes[0].use = 0.0   # 10 sn sınırına takılmasın
	_check(thrown == 0, "gizliyken Haylazlar atış yapmaz")
	_check(sim.player.hearts == 99, "gizliyken koşucu üşütmez")
	_check(closest >= 1.1 + k.radius, "koşucu çalıya giremez (en yakın %.2f m)" % closest)
	_check(a.pos.length() > 6.0, "Haylazlar uzaklaşıp arar (atıcı %.1f m)" % a.pos.length())
	# atış yapınca 1,5 sn görünür
	var sim2 := _hide_sim()
	sim2.step(DT, Vector2.ZERO)
	sim2.step(DT, Vector2.ZERO, {"auto": false, "dir": Vector2.UP})
	sim2.step(DT, Vector2.ZERO)
	_check(not sim2.hidden, "atınca görünür olur")
	for i in 95:
		sim2.step(DT, Vector2.ZERO)
	_check(sim2.hidden, "1,5 sn sonra yine gizli")
	# 10 sn sınırı, 10 sn bekleme, dışarıda yarı hızda geri dolma
	var sim3 := _hide_sim()
	var expired := 0
	for i in 60 * 10 + 5:
		sim3.step(DT, Vector2.ZERO)
		expired += _count(sim3.take_events(), "hide_expired")
	var bush = sim3.world.bushes[0]
	_check(expired == 1 and not sim3.hidden and bush.cool > 0.0, "10 sn sonra gizlilik biter, çalı beklemeye geçer")
	for i in 60 * 5:
		sim3.step(DT, Vector2.ZERO)
	_check(not sim3.hidden, "beklemedeki çalıda saklanılmaz")
	for i in 60 * 6:
		sim3.step(DT, Vector2.ZERO)
	_check(sim3.hidden, "bekleme bitince yine saklanılır")
	var sim4 := _hide_sim()
	for i in 60 * 4:
		sim4.step(DT, Vector2.ZERO)
	sim4.player.pos = Vector2(5, 0)
	for i in 60 * 2:
		sim4.step(DT, Vector2.ZERO)
	_check(absf(sim4.world.bushes[0].use - 3.0) < 0.1, "dışarıda yarı hızda geri dolar (%.2f)" % sim4.world.bushes[0].use)


func _test_piles() -> void:
	print("Kar yığınları")
	var sim := GameSim.new()
	sim.new_game(42, "pamuk")
	_check(sim.piles.size() == Balance.PILE_INITIAL, "başta 3 yığın (%d)" % sim.piles.size())
	for p in sim.piles:
		var d: float = p.pos.distance_to(Vector2.ZERO)
		_check(d >= Balance.PILE_INITIAL_DIST.x - 0.01 and d <= Balance.PILE_INITIAL_DIST.y + 0.01, "ilk yığınlar oyuncunun yakınında")
	# zamanla 7'ye kadar çıkar, fazlası olmaz
	for i in 60 * 40:
		sim.step(DT, Vector2.ZERO)
	_check(sim.piles.size() == Balance.PILE_MAX, "en fazla 7 yığın (%d)" % sim.piles.size())
	var gaps_ok := true
	for i in sim.piles.size():
		for j in range(i + 1, sim.piles.size()):
			if sim.piles[i].pos.distance_to(sim.piles[j].pos) < Balance.PILE_MIN_GAP - 0.01:
				gaps_ok = false
		for ob: Obstacle in sim.world.obstacles:
			if ob.edge_distance(sim.piles[i].pos) < sim.piles[i].radius():
				gaps_ok = false
	_check(gaps_ok, "yığınlar birbirinden ve engellerden uzak")

	# toplama: kapasiteyi aşmaz, yığın küçülür
	var sim2 := _bare_sim("pamuk")
	sim2.player.ammo = 8
	sim2.piles = [Pile.new(Vector2(0, 0.3), 5)]
	sim2.step(DT, Vector2.ZERO)
	var ev := sim2.take_events()
	_check(sim2.player.ammo == 10, "kapasiteye kadar alır (%d)" % sim2.player.ammo)
	_check(sim2.piles.size() == 1 and sim2.piles[0].amount == 3, "yığında 3 kalır")
	_check(_count(ev, "pickup") == 1, "toplama olayı")
	sim2.player.ammo = 0
	sim2.step(DT, Vector2.ZERO)
	_check(sim2.player.ammo == 3 and sim2.piles.is_empty(), "biten yığın kaybolur")
	# uzaktaki yığına dokunmaz
	var sim3 := _bare_sim("pamuk")
	sim3.player.ammo = 0
	sim3.piles = [Pile.new(Vector2(3, 0), 4)]
	sim3.step(DT, Vector2.ZERO)
	_check(sim3.player.ammo == 0, "uzaktaki yığından alınmaz")
