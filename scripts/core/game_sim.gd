extends RefCounted
## Oyunun tüm kural durumu ve adım adım ilerleyişi.
## Görüntüden bağımsızdır: aynı kod ileride online modda sunucuda da çalışabilsin.
## Sabit adımla (saniyede 60 kez) ilerletilir.
## Görüntünün bilmesi gereken anlık olaylar `events` listesine yazılır; görüntü her adımdan sonra
## take_events() ile alır. Olaylar:
##   throw, enemy_throw, splat, land, ball_clash, pickup, empty, pile_spawn,
##   haylaz_spawn, haylaz_hit, haylaz_down, player_hurt, storm_start, storm_end, game_over,
##   score (puan kazanıldı), combo (kombo çarpanı arttı), power_spawn, power_pickup, power_end,
##   shield_block (kalkan bir kartopunu durdurdu), freeze (Haylaz dondu)

const Balance = preload("res://scripts/data/balance.gd")
const World = preload("res://scripts/core/world.gd")
const Player = preload("res://scripts/core/player.gd")
const Obstacle = preload("res://scripts/core/obstacle.gd")
const Snowball = preload("res://scripts/core/snowball.gd")
const Pile = preload("res://scripts/core/pile.gd")
const Haylaz = preload("res://scripts/core/haylaz.gd")
const Power = preload("res://scripts/core/power.gd")

var world: World
var player: Player
var time: float = 0.0
var balls: Array = []        # Snowball listesi (oyuncunun ve Haylazların)
var piles: Array = []        # Pile listesi
var haylazlar: Array = []    # Haylaz listesi
var events: Array = []

var storms_enabled: bool = true   # testlerde kapatılabilir
var storm: int = 0                # kaçıncı fırtına (0 = henüz başlamadı)
var in_storm: bool = false
var storm_queue: Array = []       # bu fırtınada sırada bekleyen Haylaz türleri
var kills: int = 0                # dağıtılan Haylaz sayısı
var game_over: bool = false
var score: int = 0
var combo: int = 0                # art arda dağıtılan Haylaz
var combo_timer: float = 0.0
var powerups: Array = []          # yerdeki güçlendirmeler (Power listesi)

var _rng := RandomNumberGenerator.new()
var _pile_timer: float = 0.0
var _break_timer: float = 0.0
var _spawn_timer: float = 0.0
var _next_id: int = 1


func new_game(p_seed: int, char_id: String) -> void:
	time = 0.0
	world = World.new()
	world.generate(p_seed)
	player = Player.new()
	player.setup(char_id)
	player.pos = Vector2.ZERO
	player.prev_pos = Vector2.ZERO
	_rng.seed = p_seed + 99
	balls.clear()
	piles.clear()
	haylazlar.clear()
	events.clear()
	storm = 0
	in_storm = false
	storm_queue.clear()
	kills = 0
	game_over = false
	score = 0
	combo = 0
	combo_timer = 0.0
	powerups.clear()
	hidden = false
	hide_bush = null
	_break_timer = Balance.STORM_FIRST_BREAK
	for i in Balance.PILE_INITIAL:
		_spawn_pile(true)
	_pile_timer = Balance.PILE_INTERVAL


## Oyuncuyu olduğu yerde başka bir karaktere çevirir (geliştirme sırasında deneme için).
func change_character(char_id: String) -> void:
	var p := player.pos
	var f := player.facing
	player.setup(char_id)
	player.pos = world.resolve_circle(p, player.radius)
	player.prev_pos = player.pos
	player.facing = f


## Bir adım. throw_req boş değilse atış istenir: {"auto": true} otomatik nişan,
## {"auto": false, "dir": Vector2} verilen yöne. Dönüş: istek kullanıldı mı
## (atıldı ya da kartopu bitti); bekleme süresi dolmadıysa false.
func step(dt: float, move: Vector2, throw_req: Dictionary = {}) -> bool:
	time += dt
	if game_over:
		player.prev_pos = player.pos
		_step_balls(dt)
		return false
	player.step(dt, move, world)
	_step_hiding(dt)
	var used := false
	if not throw_req.is_empty():
		used = _try_throw(throw_req)
	if storms_enabled:
		_step_storm(dt)
	_step_haylazlar(dt)
	_step_balls(dt)
	_step_piles(dt)
	_step_powers(dt)
	if combo_timer > 0.0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo = 0
	return used


## Şu anki kombo çarpanı (1–5).
func combo_mult() -> int:
	return mini(Balance.COMBO_MAX, 1 + combo / Balance.COMBO_STEP)


func take_events() -> Array:
	var e := events
	events = []
	return e


## Ekranda kalan / gelecek Haylaz sayısı (bu fırtınada).
func storm_remaining() -> int:
	return haylazlar.size() + storm_queue.size()


# ---------- Atış ----------

func _try_throw(req: Dictionary) -> bool:
	if not player.ready_to_throw():
		return false
	if player.ammo <= 0 and not player.unlimited():
		events.append({"type": "empty"})
		return true
	var dir: Vector2
	if req.get("auto", true):
		dir = auto_aim_dir()
	else:
		dir = req.get("dir", player.facing)
	if dir.length_squared() < 0.0001:
		dir = player.facing
	dir = dir.normalized()
	player.on_throw(dir)
	var start := player.pos + dir * player.radius * 0.8
	var angles := [0.0]
	if player.has_power("uclu"):
		angles = [-Balance.TRIPLE_ANGLE, 0.0, Balance.TRIPLE_ANGLE]
	for a: float in angles:
		var d := dir.rotated(a)
		var b := Snowball.new(start, d * player.ball_speed, player.ball_radius, player.power, Balance.BALL_RANGE)
		b.freeze = player.has_power("buz")
		balls.append(b)
	events.append({"type": "throw", "pos": start, "dir": dir})
	return true


## Otomatik nişan: menzildeki en yakın Haylaza, hareketini hesaba katarak.
## Haylaz yoksa oyuncunun baktığı yön.
func auto_aim_dir() -> Vector2:
	var h := nearest_haylaz(player.pos, Balance.AUTO_AIM_RANGE)
	if h == null:
		return player.facing
	return aim_at(player.pos, h.pos, h.vel, player.ball_speed)


func nearest_haylaz(from: Vector2, max_dist: float) -> Haylaz:
	var best: Haylaz = null
	var best_d := max_dist
	for h: Haylaz in haylazlar:
		if not h.is_active():
			continue
		var d := from.distance_to(h.pos)
		if d < best_d:
			best_d = d
			best = h
	return best


## Hareket eden bir hedefe isabet etmek için atış yönü (hedefin gideceği yeri hesaba katar).
static func aim_at(from: Vector2, target: Vector2, target_vel: Vector2, ball_speed: float) -> Vector2:
	var p := target
	for i in 3:
		var t := from.distance_to(p) / ball_speed
		p = target + target_vel * t
	var d := p - from
	return d.normalized() if d.length_squared() > 0.0001 else Vector2.DOWN


# ---------- Kartopları ----------

func _step_balls(dt: float) -> void:
	for b: Snowball in balls:
		if not b.alive:
			continue
		b.prev_pos = b.pos
		var move := b.vel * dt
		b.pos += move
		b.traveled += move.length()
		for ob: Obstacle in world.obstacles:
			if ob.edge_distance(b.pos) < b.radius:
				b.alive = false
				events.append({"type": "splat", "pos": b.pos, "t": b.progress()})
				break
		if not b.alive:
			continue
		if b.owner_id == 0:
			_player_ball_hits(b)
		elif not game_over:
			_enemy_ball_hits(b)
		if not b.alive:
			continue
		if absf(b.pos.x) > world.half or absf(b.pos.y) > world.half:
			b.alive = false
			events.append({"type": "splat", "pos": world.clamp_inside(b.pos, 0.0), "t": b.progress()})
		elif b.traveled >= b.max_range:
			b.alive = false
			events.append({"type": "land", "pos": b.pos})
	balls = balls.filter(func(b: Snowball) -> bool: return b.alive)
	haylazlar = haylazlar.filter(func(h: Haylaz) -> bool: return h.alive)


func _player_ball_hits(b: Snowball) -> void:
	for h: Haylaz in haylazlar:
		if not h.is_active():
			continue
		if b.pos.distance_to(h.pos) < h.radius * Balance.HAYLAZ_HIT_FACTOR + b.radius:
			b.alive = false
			h.hp -= b.power
			var knock: float = Balance.HAYLAZ_KNOCKBACK[h.type]
			h.pos = world.resolve_circle(h.pos + b.vel.normalized() * knock, h.radius)
			if h.hp <= 0:
				_haylaz_down(h, b.vel.normalized())
			else:
				events.append({"type": "haylaz_hit", "haylaz": h, "pos": b.pos, "t": b.progress()})
				if b.freeze:
					h.frozen = Balance.KRAL_FREEZE_TIME if h.type == "kral" else Balance.FREEZE_TIME
					events.append({"type": "freeze", "haylaz": h})
			return
	# havada Haylaz kartopuna çarparsa ikisi de dağılır
	for o: Snowball in balls:
		if o.alive and o.owner_id != 0 and b.pos.distance_to(o.pos) < b.radius + o.radius:
			b.alive = false
			o.alive = false
			events.append({"type": "ball_clash", "pos": b.pos, "t": b.progress()})
			_add_score(Balance.CLASH_POINTS, b.pos, 1)
			return


## Haylaz dağıldı: puan × kombo, belki güçlendirme ya da küçük kar yığını düşer.
func _haylaz_down(h: Haylaz, dir: Vector2) -> void:
	h.alive = false
	kills += 1
	var old_mult := combo_mult()
	combo += 1
	combo_timer = Balance.COMBO_WINDOW
	var mult := combo_mult()
	var base_points: int = h.data["points"]
	events.append({"type": "haylaz_down", "haylaz": h, "pos": h.pos, "dir": dir})
	_add_score(base_points * mult, h.pos, mult)
	if mult > old_mult:
		events.append({"type": "combo", "mult": mult, "pos": h.pos})
	if h.type == "kral":
		# Kar Kralı: 2 güçlendirme ve 6'lık kar yığını bırakır
		for i in Balance.KRAL_POWER_DROPS:
			_drop_power(h.pos + Vector2(-0.8 + i * 1.6, 0))
		var p := world.resolve_circle(h.pos + Vector2(0, 1.0), Balance.pile_radius(Balance.KRAL_PILE))
		piles.append(Pile.new(p, Balance.KRAL_PILE))
		events.append({"type": "pile_spawn", "pos": p})
	elif _rng.randf() < Balance.POWER_DROP_CHANCE:
		_drop_power(h.pos)
	elif _rng.randf() < Balance.SMALL_PILE_CHANCE:
		var p := world.resolve_circle(h.pos, Balance.pile_radius(Balance.SMALL_PILE_AMOUNT))
		piles.append(Pile.new(p, Balance.SMALL_PILE_AMOUNT))
		events.append({"type": "pile_spawn", "pos": p})


func _add_score(points: int, pos: Vector2, mult: int) -> void:
	score += points
	events.append({"type": "score", "points": points, "pos": pos, "mult": mult})


func _enemy_ball_hits(b: Snowball) -> void:
	if hidden:
		return   # çalılıkta gizliyken Haylaz kartopları içinden etkisiz geçer
	var d := b.pos.distance_to(player.pos)
	if player.has_power("kalkan") and d < player.radius * Balance.SHIELD_FACTOR:
		b.alive = false
		events.append({"type": "shield_block", "pos": b.pos, "t": b.progress()})
		return
	if player.invulnerable > 0.0:
		return   # dokunulmazken kartopları içinden geçer
	if d < player.radius * Balance.PLAYER_HIT_FACTOR + b.radius:
		b.alive = false
		events.append({"type": "splat", "pos": b.pos, "t": b.progress()})
		_hurt_player()


func _enemy_throw(h: Haylaz, dir: Vector2, speed: float, radius: float) -> void:
	var start := h.pos + dir * h.radius
	var b := Snowball.new(start, dir * speed, radius, 1, Balance.ENEMY_BALL_RANGE)
	b.owner_id = h.id
	balls.append(b)
	events.append({"type": "enemy_throw", "haylaz": h, "dir": dir})


# ---------- Oyuncunun canı ----------

func _hurt_player() -> void:
	if player.invulnerable > 0.0 or game_over or player.has_power("kalkan"):
		return
	player.hearts -= 1
	player.invulnerable = Balance.INVULNERABLE_TIME
	combo = 0
	combo_timer = 0.0
	events.append({"type": "player_hurt", "hearts": player.hearts})
	if player.hearts <= 0:
		game_over = true
		events.append({"type": "game_over", "storm": storm, "kills": kills})


# ---------- Fırtınalar ----------

func _step_storm(dt: float) -> void:
	if not in_storm:
		_break_timer -= dt
		if _break_timer <= 0.0:
			_start_storm()
		return
	_spawn_timer -= dt
	if not storm_queue.is_empty() and _spawn_timer <= 0.0 and haylazlar.size() < Balance.STORM_MAX_ALIVE_BASE + storm:
		_spawn_haylaz(storm_queue.pop_front())
		_spawn_timer = maxf(Balance.STORM_SPAWN_INTERVAL.z, Balance.STORM_SPAWN_INTERVAL.x - storm * Balance.STORM_SPAWN_INTERVAL.y)
	if storm_queue.is_empty() and haylazlar.is_empty():
		in_storm = false
		_break_timer = Balance.STORM_BREAK
		var healed := player.hearts < player.max_hearts
		if healed:
			player.hearts += 1
		var bonus := storm * Balance.STORM_BONUS
		score += bonus
		events.append({"type": "storm_end", "storm": storm, "healed": healed, "bonus": bonus})


func _start_storm() -> void:
	storm += 1
	storm_queue = storm_list(storm, _rng)
	in_storm = true
	_spawn_timer = 0.4
	events.append({"type": "storm_start", "storm": storm, "count": storm_queue.size(),
		"kral": storm % Balance.KRAL_EVERY == 0})


## Fırtınadaki Haylazlar (SPEC §7). Her 5. fırtına Kar Kralı fırtınası:
## 1 Kar Kralı + fırtına / 5 × 2 atıcı.
static func storm_list(n: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if n % Balance.KRAL_EVERY == 0:
		out.append("kral")
		for i in n / Balance.KRAL_EVERY * 2:
			out.append("atici")
		return out
	for i in Balance.storm_count(n):
		var r := rng.randf()
		if n >= 3 and r < 0.12 + n * 0.012:
			out.append("koca")
		elif n >= 2 and r < 0.5:
			out.append("kosucu")
		else:
			out.append("atici")
	return out


func _spawn_haylaz(type: String) -> void:
	var r: float = Balance.HAYLAZ[type]["radius"]
	var limit := world.half - 1.5
	var p := Vector2.ZERO
	var found := false
	for i in Balance.HAYLAZ_SPAWN_TRIES:
		p = Vector2(_rng.randf_range(-limit, limit), _rng.randf_range(-limit, limit))
		if p.distance_to(player.pos) > Balance.HAYLAZ_SPAWN_MIN_DIST and world.is_free(p, r, 0.1) and not _in_bush(p, r):
			found = true
			break
	if not found:
		p = world.resolve_circle(p, r)
	_add_haylaz(type, p)


func _add_haylaz(type: String, p: Vector2) -> Haylaz:
	var h := Haylaz.new(_next_id, type, p, storm, _rng)
	_next_id += 1
	haylazlar.append(h)
	events.append({"type": "haylaz_spawn", "haylaz": h})
	return h


# ---------- Çalılıkta saklanma (SPEC §12) ----------

var hidden: bool = false          # oyuncu şu an gizli mi
var hide_bush = null              # oyuncunun içinde durduğu çalılık (Bush ya da null)


func _step_hiding(dt: float) -> void:
	var current = null
	for b in world.bushes:
		if b.cool > 0.0:
			b.cool -= dt
			if b.cool <= 0.0:
				b.cool = 0.0
				b.use = 0.0
			continue
		if player.pos.distance_to(b.pos) < b.radius:
			current = b
			if player.reveal <= 0.0:
				b.use += dt
				if b.use >= Balance.HIDE_MAX:
					b.cool = Balance.HIDE_COOL
					current = null
					events.append({"type": "hide_expired", "pos": b.pos})
		else:
			b.use = maxf(0.0, b.use - dt * Balance.HIDE_RECOVER)
	var was := hidden
	hide_bush = current
	hidden = current != null and player.reveal <= 0.0
	if hidden and not was:
		events.append({"type": "hidden"})
	elif was and not hidden and current != null:
		events.append({"type": "revealed"})


## Oyuncu saklanınca Haylazın arayacağı yer: çalıya göre kendi tarafından dışarı doğru, 12–18,75 m ötede.
func _pick_search(h: Haylaz) -> void:
	var c: Vector2 = hide_bush.pos if hide_bush != null else player.pos
	var base := (h.pos - c).angle()
	var p := c
	for k in 12:
		var a := base + _rng.randf_range(-0.9, 0.9) + (_rng.randf_range(-1.5, 1.5) if k > 6 else 0.0)
		var dd := _rng.randf_range(Balance.HIDE_SEARCH_DIST.x, Balance.HIDE_SEARCH_DIST.y)
		p = world.clamp_inside(c + Vector2.from_angle(a) * dd, 1.5)
		if p.distance_to(player.pos) > Balance.HIDE_SEARCH_MIN_PLAYER:
			break
	h.search_pos = p
	h.searching = true


# ---------- Haylaz davranışları (SPEC §6) ----------

func _step_haylazlar(dt: float) -> void:
	for h: Haylaz in haylazlar.duplicate():   # Kar Kralı koşucu çağırınca liste büyüyebilir
		h.prev_pos = h.pos
		if h.spawn_left > 0.0:
			h.spawn_left -= dt
			continue
		if h.frozen > 0.0:
			h.frozen -= dt   # donmuş: kıpırdamaz, atmaz, üşütmez
			continue
		var to_p := player.pos - h.pos
		var d := maxf(to_p.length(), 0.001)
		var u := to_p / d
		var side := u.orthogonal()
		# oyuncu saklandıysa: Haylazlar onu göremez, arama noktasına yürür
		var target := player.pos
		if hidden:
			if not h.searching or h.pos.distance_to(h.search_pos) < Balance.HIDE_SEARCH_REACHED:
				_pick_search(h)
			target = h.search_pos
		else:
			h.searching = false
		var to_t := target - h.pos
		var d_t := maxf(to_t.length(), 0.001)
		var u_t := to_t / d_t
		var mv := Vector2.ZERO
		match h.type:
			"atici":
				if d > Balance.ATICI_FAR:
					mv = u
				elif d < Balance.ATICI_NEAR:
					mv = -u
				else:
					mv = side * h.strafe * Balance.ATICI_STRAFE
					if _rng.randf() < dt * Balance.ATICI_FLIP_RATE:
						h.strafe *= -1.0
				h.throw_timer -= dt
				if h.throw_timer <= 0.0 and d < Balance.ATICI_THROW_RANGE and not hidden:
					var spd := minf(Balance.ATICI_BALL_SPEED.z, Balance.ATICI_BALL_SPEED.x + storm * Balance.ATICI_BALL_SPEED.y)
					var dir := u.rotated(_rng.randf_range(-Balance.ATICI_SPREAD, Balance.ATICI_SPREAD))
					_enemy_throw(h, dir, spd, Balance.ENEMY_BALL_RADIUS)
					h.throw_timer = maxf(Balance.ATICI_INTERVAL_MIN,
						_rng.randf_range(Balance.ATICI_INTERVAL.x, Balance.ATICI_INTERVAL.y) - storm * Balance.ATICI_INTERVAL_DROP)
			"kosucu":
				if h.stun > 0.0:
					h.stun -= dt
					mv = -u * 0.5
				else:
					h.zig += dt * Balance.KOSUCU_ZIG_FREQ
					mv = u + side * sin(h.zig) * Balance.KOSUCU_ZIG
					if d < h.radius + player.radius + Balance.HAYLAZ_CONTACT_MARGIN and not hidden:
						_hurt_player()
						h.stun = Balance.KOSUCU_STUN
						h.pos = world.resolve_circle(h.pos - u * Balance.KOSUCU_BOUNCE, h.radius)
			"koca":
				if d > Balance.KOCA_NEAR:
					mv = u
				h.throw_timer -= dt
				if h.throw_timer <= 0.0 and d < Balance.KOCA_THROW_RANGE and not hidden:
					for o in [-Balance.KOCA_FAN, 0.0, Balance.KOCA_FAN]:
						_enemy_throw(h, u.rotated(o), Balance.KOCA_BALL_SPEED, Balance.KOCA_BALL_RADIUS)
					h.throw_timer = _rng.randf_range(Balance.KOCA_INTERVAL.x, Balance.KOCA_INTERVAL.y)
			"kral":
				mv = _step_kral(h, dt, d, u, side)
		if hidden:
			mv = u_t   # arama yürüyüşü: saldırı davranışı yok (Kar Kralı'nın hedefsiz saldırıları sürer)
			if h.type == "kosucu" and h.stun > 0.0:
				h.stun -= dt
		mv = mv.limit_length(1.0)
		# engele takıldıysa bir süre yandan dolaş
		if h.detour_left > 0.0:
			h.detour_left -= dt
			mv = (h.detour_dir * 0.85 + mv * 0.4).limit_length(1.0)
		var spd_mul := Balance.KOSUCU_STUN_SPEED if h.type == "kosucu" and h.stun > 0.0 else 1.0
		var want := mv * h.speed * spd_mul * dt
		h.pos = world.resolve_circle(h.pos + want, h.radius)
		# takılma: hedefine yaklaşmaya çalışıyor ama yaklaşamıyorsa (engelin arkasında kaldıysa)
		var expected := want.dot(u_t)
		var progress := d_t - h.pos.distance_to(target)
		if expected > 0.0005 and progress < expected * 0.3:
			h.stuck += dt
		else:
			h.stuck = maxf(0.0, h.stuck - dt)
		if h.stuck > Balance.HAYLAZ_STUCK_TIME and h.detour_left <= 0.0:
			h.detour_dir = (mv.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)).normalized()
			h.detour_left = Balance.HAYLAZ_DETOUR_TIME
			h.stuck = 0.0
		# koşucu (ve arayan Haylazlar) gittiği yöne, diğerleri oyuncuya bakar
		if (h.type == "kosucu" or hidden) and mv.length_squared() > 0.01:
			h.facing = mv.normalized()
		else:
			h.facing = u
	# Haylazlar birbirinin içine girmesin
	for i in haylazlar.size():
		var a: Haylaz = haylazlar[i]
		if a.spawn_left > 0.0:
			continue
		for j in range(i + 1, haylazlar.size()):
			var b: Haylaz = haylazlar[j]
			if b.spawn_left > 0.0:
				continue
			var sep := a.pos - b.pos
			var dist := sep.length()
			var m := a.radius + b.radius
			if dist < m and dist > 0.001:
				var k := sep / dist * (m - dist) * 0.5
				a.pos = world.resolve_circle(a.pos + k, a.radius)
				b.pos = world.resolve_circle(b.pos - k, b.radius)
	# saklanılan çalıya giremezler: kenarından dolaşırlar
	if hidden and hide_bush != null:
		for h: Haylaz in haylazlar:
			var away: Vector2 = h.pos - hide_bush.pos
			var m: float = hide_bush.radius + h.radius + Balance.HIDE_BUSH_MARGIN
			if away.length() < m:
				var n := away.normalized() if away.length() > 0.001 else Vector2.UP
				h.pos = world.resolve_circle(hide_bush.pos + n * m, h.radius)
	for h: Haylaz in haylazlar:
		h.vel = (h.pos - h.prev_pos) / dt if dt > 0.0 else Vector2.ZERO


## Kar Kralı (SPEC §6): yaklaşır / uzaklaşır / yan yan kayar; sırayla halka atış,
## oyuncuya 5'li atış ve 2 koşucu çağırma. Değerse oyuncuyu üşütür ve iter.
func _step_kral(h: Haylaz, dt: float, d: float, u: Vector2, side: Vector2) -> Vector2:
	var mv := Vector2.ZERO
	if d > Balance.KRAL_FAR:
		mv = u
	elif d < Balance.KRAL_NEAR:
		mv = -u
	else:
		mv = side * h.strafe
		if _rng.randf() < dt * Balance.KRAL_FLIP_RATE:
			h.strafe *= -1.0
	h.throw_timer -= dt
	if h.throw_timer <= 0.0:
		h.phase = (h.phase + 1) % 3
		match h.phase:
			0:
				for k in Balance.KRAL_RING:
					var a := TAU * k / Balance.KRAL_RING + time
					_enemy_throw(h, Vector2.from_angle(a), Balance.KRAL_RING_SPEED, Balance.KRAL_RING_RADIUS)
			1:
				if not hidden:
					for k in range(-(Balance.KRAL_AIMED / 2), Balance.KRAL_AIMED / 2 + 1):
						_enemy_throw(h, u.rotated(k * Balance.KRAL_AIMED_SPREAD), Balance.KRAL_AIMED_SPEED, Balance.KRAL_AIMED_RADIUS)
			2:
				if haylazlar.size() < Balance.KRAL_SUMMON_MAX:
					events.append({"type": "kral_summon", "haylaz": h})
					for k in Balance.KRAL_SUMMON:
						var off := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * Balance.KRAL_SUMMON_SPREAD
						_add_haylaz("kosucu", world.resolve_circle(h.pos + off, 0.4))
		h.throw_timer = Balance.KRAL_INTERVAL_ANGRY if h.hp < h.max_hp / 2.0 else Balance.KRAL_INTERVAL
	if not hidden and d < h.radius + player.radius + Balance.HAYLAZ_CONTACT_MARGIN:
		_hurt_player()
		player.pos = world.resolve_circle(player.pos + u * Balance.KRAL_PUSH, player.radius)
	return mv


# ---------- Kar yığınları ----------

func _step_piles(dt: float) -> void:
	# Kar Mıknatısı: yakındaki yığınlar oyuncuya kayar
	if player.has_power("miknatis") and player.ammo < player.capacity:
		for pile: Pile in piles:
			var to := player.pos - pile.pos
			var d := to.length()
			if d < Balance.MAGNET_RANGE and d > 0.05:
				pile.pos += to / d * minf(Balance.MAGNET_SPEED * dt, d)
	for pile: Pile in piles:
		if player.ammo >= player.capacity:
			break
		if player.pos.distance_to(pile.pos) < player.radius + pile.radius() * Balance.PILE_PICKUP_FACTOR:
			var take := mini(pile.amount, player.capacity - player.ammo)
			player.ammo += take
			pile.amount -= take
			events.append({"type": "pickup", "pos": pile.pos, "amount": take})
	piles = piles.filter(func(p: Pile) -> bool: return p.amount > 0)

	_pile_timer -= dt
	if _pile_timer <= 0.0:
		_pile_timer = Balance.PILE_INTERVAL if in_storm else Balance.PILE_BREAK_INTERVAL
		if piles.size() < Balance.PILE_MAX:
			_spawn_pile(false)


## Yeni kar yığını. initial: oyun başında oyuncunun yakınına.
func _spawn_pile(initial: bool) -> void:
	var limit := world.half - Balance.PILE_EDGE_MARGIN
	for i in Balance.PILE_TRIES:
		var p: Vector2
		if initial:
			var d := _rng.randf_range(Balance.PILE_INITIAL_DIST.x, Balance.PILE_INITIAL_DIST.y)
			p = player.pos + Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * d
		else:
			p = Vector2(_rng.randf_range(-limit, limit), _rng.randf_range(-limit, limit))
			if p.distance_to(player.pos) < Balance.PILE_MIN_DIST_PLAYER:
				continue
		if absf(p.x) > limit or absf(p.y) > limit:
			continue
		var amount := _rng.randi_range(Balance.PILE_AMOUNT.x, Balance.PILE_AMOUNT.y)
		if not world.is_free(p, Balance.pile_radius(amount), 0.3):
			continue
		if _in_bush(p, 0.5) or _near_pile(p):
			continue
		var pile := Pile.new(p, amount)
		piles.append(pile)
		events.append({"type": "pile_spawn", "pos": p})
		return


# ---------- Güçlendirmeler (SPEC §9) ----------

func _drop_power(pos: Vector2) -> void:
	var type: String = Balance.POWER_ORDER[_rng.randi_range(0, Balance.POWER_ORDER.size() - 1)]
	if player.hearts <= 1 and _rng.randf() < Balance.LOW_HEART_ORB_CHANCE:
		type = "kure"
	var p := world.clamp_inside(pos, 0.5)
	powerups.append(Power.new(type, p))
	events.append({"type": "power_spawn", "power_type": type, "pos": p})


func _step_powers(dt: float) -> void:
	# yerdekiler: süresi dolan kaybolur, üstünden geçilen alınır
	for w: Power in powerups:
		w.life -= dt
		if w.life > 0.0 and player.pos.distance_to(w.pos) < player.radius + Balance.POWER_PICKUP:
			w.life = 0.0
			_apply_power(w.type, w.pos)
	powerups = powerups.filter(func(w: Power) -> bool: return w.life > 0.0)
	# etkin olanların süresi
	for type: String in player.powers.keys():
		player.powers[type] -= dt
		if player.powers[type] <= 0.0:
			player.powers.erase(type)
			if type == "yagmur":
				player.ammo = player.capacity   # Kartopu Yağmuru bitince kartopu dolu kalır
			events.append({"type": "power_end", "power_type": type})


func _apply_power(type: String, pos: Vector2) -> void:
	match type:
		"kure":
			if player.hearts < player.max_hearts:
				player.hearts += 1
			else:
				_add_score(Balance.ORB_FULL_POINTS, player.pos, 1)
		_:
			player.powers[type] = float(Balance.POWERS[type]["time"])
			if type == "yagmur":
				player.ammo = player.capacity
	events.append({"type": "power_pickup", "power_type": type, "pos": pos})


func _near_pile(p: Vector2) -> bool:
	for other: Pile in piles:
		if p.distance_to(other.pos) < Balance.PILE_MIN_GAP:
			return true
	return false


func _in_bush(p: Vector2, margin: float) -> bool:
	for b in world.bushes:
		if p.distance_to(b.pos) < b.radius + margin:
			return true
	return false
