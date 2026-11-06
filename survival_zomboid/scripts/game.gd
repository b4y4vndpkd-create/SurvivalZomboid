extends Node2D
## Survival Zomboid - game logic and world rendering (all drawn with _draw()).

const MAP_SIZE := 2400
const SAVE_PATH := "user://survival_zomboid_save.json"
const BASE_SPEED := 138.0      # 2.3 px/frame * 60
const SPRINT_SPEED := 234.0    # 3.9 px/frame * 60
const STICK_RADIUS := 70.0

class Zombie:
	var pos := Vector2.ZERO
	var radius := 17.0
	var hp := 50.0
	var max_hp := 50.0
	var speed := 69.0
	var damage := 8.0
	var angle := 0.0
	var is_fast := false
	var is_boss := false

class Bullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var damage := 0.0
	var color := Color.WHITE
	var is_rocket := false
	var splash := 0.0
	var life := 1.5

class Particle:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var radius := 2.0
	var alpha := 1.0
	var color := Color.RED

class Explosion:
	var pos := Vector2.ZERO
	var radius := 100.0
	var alpha := 1.0

var WEAPONS := {
	"Pistol": {"name": "Pistol", "cost": 0, "damage": 25.0, "fire_rate": 300, "speed": 12.0, "spread": 0.05, "count": 1,
		"color": Color("#facc15"), "infinite": true, "ammo_cost": 0, "ammo_amount": 0, "splash": 0.0, "rocket": false},
	"Shotgun": {"name": "Shotgun", "cost": 150, "damage": 18.0, "fire_rate": 700, "speed": 10.0, "spread": 0.22, "count": 6,
		"color": Color("#f97316"), "infinite": false, "ammo_cost": 40, "ammo_amount": 20, "splash": 0.0, "rocket": false},
	"Auto Rifle": {"name": "Auto Rifle", "cost": 300, "damage": 22.0, "fire_rate": 110, "speed": 14.0, "spread": 0.1, "count": 1,
		"color": Color("#38bdf8"), "infinite": false, "ammo_cost": 60, "ammo_amount": 60, "splash": 0.0, "rocket": false},
	"Plasma Cannon": {"name": "Plasma Cannon", "cost": 600, "damage": 95.0, "fire_rate": 850, "speed": 8.0, "spread": 0.02, "count": 1,
		"color": Color("#c084fc"), "infinite": false, "ammo_cost": 100, "ammo_amount": 10, "splash": 0.0, "rocket": false},
	"Bazooka": {"name": "Bazooka", "cost": 850, "damage": 160.0, "fire_rate": 1300, "speed": 7.0, "spread": 0.03, "count": 1,
		"color": Color("#ef4444"), "infinite": false, "ammo_cost": 120, "ammo_amount": 5, "splash": 110.0, "rocket": true},
}

var HEALING_ITEMS := {
	"Bandage": {"name": "Bandage", "heal": 25, "cost": 20},
	"Medkit": {"name": "Medkit", "heal": 60, "cost": 50},
	"Healing Potion": {"name": "Potion", "heal": 100, "cost": 90},
}

# ---- state
var in_game := false
var paused := false
var settings_open := false
var round_num := 1
var highest_round := 1
var round_active := false
var zombies_to_spawn := 8
var zombies_remaining := 8
var money := 100
var health := 100.0
var max_health := 100.0
var owned_weapons: Array = ["Pistol"]
var current_weapon := "Pistol"
var weapon_ammo := {}
var camera_shake_on := true
var shake := 0.0
var last_shot_ms := 0

var player_pos := Vector2(MAP_SIZE / 2.0, MAP_SIZE / 2.0)
var player_angle := 0.0
var stamina := 100.0
var max_stamina := 100.0

var decorations: Array = []
var zombies: Array[Zombie] = []
var bullets: Array[Bullet] = []
var particles: Array[Particle] = []
var explosions: Array[Explosion] = []

# ---- input state
var firing_mouse := false
var sprint_hold := false
var using_touch := false
var stick_active := false
var stick_index := -1
var stick_start := Vector2.ZERO
var stick_cur := Vector2.ZERO
var aim_index := -1
var sprint_index := -1
var aim_start := Vector2.ZERO
var aim_cur := Vector2.ZERO

var camera: Camera2D
var ui


func _ready() -> void:
	randomize()
	camera = $Camera2D
	ui = $UI
	ui.setup(self)
	weapon_ammo = _default_ammo()
	_generate_decorations()
	_load_progress()
	ui.show_main_menu()


func _default_ammo() -> Dictionary:
	return {
		"Pistol": {"reserve": 999},
		"Shotgun": {"reserve": 40},
		"Auto Rifle": {"reserve": 120},
		"Plasma Cannon": {"reserve": 15},
		"Bazooka": {"reserve": 8},
	}


# ------------------------------------------------------------------ save/load
func _save_progress() -> void:
	if round_num > highest_round:
		highest_round = round_num
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"highest_round": highest_round}))


func _load_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_DICTIONARY:
				highest_round = int(data.get("highest_round", 1))


# ------------------------------------------------------------------ map
func _generate_decorations() -> void:
	decorations.clear()
	for i in 260:
		var p := Vector2(randf_range(120.0, MAP_SIZE - 120.0), randf_range(120.0, MAP_SIZE - 120.0))
		var r := randf()
		if r < 0.38:
			var flakes: Array = []
			for k in 4:
				flakes.append({"off": Vector2(randf_range(-12.0, 12.0), randf_range(12.0, 30.0)), "size": randf_range(2.0, 5.0)})
			decorations.append({"type": "oak", "pos": p, "radius": randf_range(42.0, 56.0), "flakes": flakes})
		elif r < 0.62:
			decorations.append({"type": "birch", "pos": p, "radius": randf_range(28.0, 38.0)})
		elif r < 0.82:
			decorations.append({"type": "boulder", "pos": p, "radius": randf_range(16.0, 30.0)})
		else:
			decorations.append({"type": "flowers", "pos": p, "yellow": randf() < 0.6})


# ------------------------------------------------------------------ flow
func start_new_game() -> void:
	_reset_touch()
	money = 100
	health = 100.0
	round_num = 1
	owned_weapons = ["Pistol"]
	current_weapon = "Pistol"
	weapon_ammo = _default_ammo()
	player_pos = Vector2(MAP_SIZE / 2.0, MAP_SIZE / 2.0)
	stamina = max_stamina
	bullets.clear()
	explosions.clear()
	zombies.clear()
	particles.clear()
	in_game = true
	paused = false
	settings_open = false
	ui.show_hud()
	Audio.start_bgm()
	_start_round(1)


func _start_round(n: int) -> void:
	round_num = n
	round_active = true
	zombies_to_spawn = 8 + (n - 1) * 6
	if n >= 3:
		zombies_to_spawn += 1
	zombies_remaining = zombies_to_spawn
	ui.refresh_hud()


func open_shop() -> void:
	if round_active:
		return
	if in_game:
		paused = true
	_reset_touch()
	Audio.stop_bgm()
	ui.show_shop()


func close_shop() -> void:
	ui.hide_shop()
	if in_game:
		paused = false
		Audio.start_bgm()


func start_next_round_from_shop() -> void:
	close_shop()
	_start_round(round_num + 1)
	_save_progress()


func open_settings() -> void:
	if settings_open:
		return
	settings_open = true
	_reset_touch()
	if in_game:
		paused = true
	Audio.stop_bgm()
	ui.show_settings()


func close_settings() -> void:
	settings_open = false
	ui.hide_settings()
	if in_game:
		paused = false
		Audio.start_bgm()


func quit_to_menu() -> void:
	_save_progress()
	Audio.stop_bgm()
	in_game = false
	paused = false
	settings_open = false
	ui.show_main_menu()


func quit_game() -> void:
	get_tree().quit()


func _game_over() -> void:
	Audio.stop_bgm()
	_save_progress()
	in_game = false
	paused = false
	ui.show_main_menu("GAME OVER - you reached round %d" % round_num)


# ------------------------------------------------------------------ shop
func buy_weapon(key: String) -> void:
	var w: Dictionary = WEAPONS[key]
	if money >= int(w["cost"]) and not owned_weapons.has(key):
		money -= int(w["cost"])
		owned_weapons.append(key)
		current_weapon = key
		_save_progress()
		ui.show_shop()
		ui.refresh_hud()


func buy_ammo(key: String) -> void:
	var w: Dictionary = WEAPONS[key]
	if w["infinite"]:
		return
	if money >= int(w["ammo_cost"]):
		money -= int(w["ammo_cost"])
		weapon_ammo[key]["reserve"] += int(w["ammo_amount"])
		_save_progress()
		ui.show_shop()
		ui.refresh_hud()


func buy_heal(key: String) -> void:
	var h: Dictionary = HEALING_ITEMS[key]
	if money >= int(h["cost"]) and health < max_health:
		money -= int(h["cost"])
		health = minf(max_health, health + float(h["heal"]))
		_save_progress()
		ui.show_shop()
		ui.refresh_hud()


func select_weapon(key: String) -> void:
	if owned_weapons.has(key):
		current_weapon = key
		Audio.play("click")
		ui.refresh_hud()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	# touch state is always tracked so releases are never lost
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and in_game:
			if settings_open:
				close_settings()
			elif not paused:
				open_settings()
			return
		if in_game and not paused:
			var idx := int(event.keycode) - int(KEY_1)
			if idx >= 0 and idx < owned_weapons.size():
				select_weapon(owned_weapons[idx])

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		if in_game and not paused:
			firing_mouse = true
			using_touch = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		firing_mouse = false
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		using_touch = false


func _handle_touch(event: InputEvent) -> void:
	using_touch = true
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		if event.pressed:
			if ui.is_sprint_at(event.position):
				sprint_index = event.index
				sprint_hold = true
				return
			if ui.is_over_button(event.position):
				return
			if event.position.x < half and not stick_active:
				stick_active = true
				stick_index = event.index
				stick_start = event.position
				stick_cur = event.position
			elif event.position.x >= half and aim_index == -1:
				aim_index = event.index
				aim_start = event.position
				aim_cur = event.position
		else:
			if event.index == stick_index:
				stick_active = false
				stick_index = -1
			if event.index == aim_index:
				aim_index = -1
			if event.index == sprint_index:
				sprint_index = -1
				sprint_hold = false
	elif event is InputEventScreenDrag:
		if event.index == stick_index:
			stick_cur = event.position
		elif event.index == aim_index:
			aim_cur = event.position


func _reset_touch() -> void:
	stick_active = false
	stick_index = -1
	aim_index = -1
	sprint_index = -1
	firing_mouse = false
	sprint_hold = false


# ------------------------------------------------------------------ update
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if in_game and not paused:
		_update_player(delta)
		_update_zombies(delta)
		_update_bullets(delta)
		_update_particles(delta)
		_check_round_clear()
		if in_game:
			ui.refresh_hud()

	if shake > 0.0:
		camera.offset = Vector2(randf() - 0.5, randf() - 0.5) * shake
		shake *= pow(0.9, delta * 60.0)
		if shake < 0.5:
			shake = 0.0
	else:
		camera.offset = Vector2.ZERO
	camera.global_position = player_pos
	queue_redraw()


func _update_player(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if stick_active:
		var sd := stick_cur - stick_start
		if sd.length() > 8.0:
			dir = sd.limit_length(STICK_RADIUS) / STICK_RADIUS

	var moving := dir != Vector2.ZERO
	var sprint_pressed := Input.is_key_pressed(KEY_SHIFT) or sprint_hold
	var speed := BASE_SPEED
	if sprint_pressed and stamina > 5.0 and moving:
		speed = SPRINT_SPEED
		stamina = maxf(0.0, stamina - 36.0 * delta)
	elif stamina < max_stamina:
		stamina = minf(max_stamina, stamina + 21.0 * delta)

	if dir.length() > 1.0:
		dir = dir.normalized()
	player_pos += dir * speed * delta
	player_pos.x = clampf(player_pos.x, 80.0, MAP_SIZE - 80.0)
	player_pos.y = clampf(player_pos.y, 80.0, MAP_SIZE - 80.0)

	var aim_fire := false
	if aim_index != -1:
		var ad := aim_cur - aim_start
		if ad.length() > 12.0:
			player_angle = ad.angle()
		aim_fire = ad.length() > 24.0
	elif not using_touch:
		player_angle = (get_global_mouse_position() - player_pos).angle()

	var w: Dictionary = WEAPONS[current_weapon]
	var wants_fire := Input.is_key_pressed(KEY_SPACE) or firing_mouse or aim_fire
	if wants_fire and Time.get_ticks_msec() - last_shot_ms >= int(w["fire_rate"]):
		_fire_weapon()


func _fire_weapon() -> void:
	var w: Dictionary = WEAPONS[current_weapon]
	var ammo: Dictionary = weapon_ammo[current_weapon]
	if not w["infinite"] and ammo["reserve"] <= 0:
		return
	if not w["infinite"]:
		ammo["reserve"] -= 1
	last_shot_ms = Time.get_ticks_msec()
	Audio.play_weapon(current_weapon)
	if camera_shake_on:
		shake = 6.0
	for i in int(w["count"]):
		var ang := player_angle + (randf() - 0.5) * float(w["spread"])
		var b := Bullet.new()
		b.pos = player_pos + Vector2.from_angle(player_angle) * 22.0
		b.vel = Vector2.from_angle(ang) * float(w["speed"]) * 60.0
		b.damage = float(w["damage"])
		b.color = w["color"]
		b.is_rocket = w["rocket"]
		b.splash = float(w["splash"])
		b.life = 1.5
		bullets.append(b)


func _spawn_zombie() -> void:
	var side := randi() % 4
	var zp := player_pos
	match side:
		0:
			zp += Vector2(randf_range(-600.0, 600.0), -700.0)
		1:
			zp += Vector2(randf_range(-600.0, 600.0), 700.0)
		2:
			zp += Vector2(-900.0, randf_range(-450.0, 450.0))
		_:
			zp += Vector2(900.0, randf_range(-450.0, 450.0))
	zp.x = clampf(zp.x, 150.0, MAP_SIZE - 150.0)
	zp.y = clampf(zp.y, 150.0, MAP_SIZE - 150.0)

	var has_boss := false
	for other in zombies:
		if other.is_boss:
			has_boss = true
	var make_boss := round_num >= 3 and not has_boss and randf() < 0.4

	var z := Zombie.new()
	z.pos = zp
	if make_boss:
		Audio.play("boss")
		z.is_boss = true
		z.radius = 28.0
		z.max_hp = 400.0 + (round_num - 3) * 120.0
		z.hp = z.max_hp
		z.speed = 0.9 * 60.0
		z.damage = 25.0
	else:
		Audio.play("spawn")
		z.is_fast = randf() < 0.25
		z.radius = 17.0
		z.max_hp = 50.0 + (round_num - 1) * 15.0
		z.hp = z.max_hp
		z.speed = (1.9 if z.is_fast else 1.15) * 60.0
		z.damage = 12.0 if z.is_fast else 8.0
	zombies.append(z)
	zombies_to_spawn -= 1


func _update_zombies(delta: float) -> void:
	if round_active and zombies_to_spawn > 0 and zombies.size() < 12:
		if randf() < 0.035 * delta * 60.0:
			_spawn_zombie()

	for z in zombies:
		var d := player_pos - z.pos
		var dist := d.length()
		z.angle = d.angle()
		if randf() < 0.005 * delta * 60.0:
			if z.is_boss:
				Audio.play("boss")
			elif randf() < 0.4:
				Audio.play_groan()
		if dist > 18.0:
			z.pos += d / dist * z.speed * delta
		else:
			health -= z.damage * 3.0 * delta
			if health <= 0.0:
				health = 0.0
				_game_over()
				return


func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		b.pos += b.vel * delta
		b.life -= delta
		var hit := false
		for j in range(zombies.size() - 1, -1, -1):
			var z := zombies[j]
			if z.pos.distance_to(b.pos) < z.radius + 4.0:
				hit = true
				if b.splash > 0.0:
					_explode(b.pos, b.splash, b.damage)
				else:
					z.hp -= b.damage
					Audio.play("hit")
					_blood(b.pos, 8, z.is_boss)
				break
		var out := b.pos.x < 30.0 or b.pos.x > MAP_SIZE - 30.0 or b.pos.y < 30.0 or b.pos.y > MAP_SIZE - 30.0
		if hit or b.life <= 0.0 or out:
			if not hit and b.splash > 0.0:
				_explode(b.pos, b.splash, b.damage)
			bullets.remove_at(i)

	for j in range(zombies.size() - 1, -1, -1):
		var z := zombies[j]
		if z.hp <= 0.0:
			money += 100 if z.is_boss else (25 if z.is_fast else 15)
			zombies_remaining -= 1
			Audio.play("hit")
			_blood(z.pos, 25 if z.is_boss else 14, z.is_boss)
			zombies.remove_at(j)


func _check_round_clear() -> void:
	if round_active and zombies_to_spawn <= 0 and zombies.is_empty():
		round_active = false
		_save_progress()
		Audio.play("clear")
		open_shop()


func _explode(pos: Vector2, radius: float, damage: float) -> void:
	var e := Explosion.new()
	e.pos = pos
	e.radius = radius
	explosions.append(e)
	Audio.play_weapon("Bazooka")
	if camera_shake_on:
		shake = 14.0
	for z in zombies:
		var dist := z.pos.distance_to(pos)
		if dist < radius + z.radius:
			z.hp -= damage * (1.0 - dist / (radius * 1.5))


func _blood(pos: Vector2, count: int, boss: bool) -> void:
	for i in count:
		var ang := randf() * TAU
		var spd := (1.0 + randf() * 4.0) * 60.0
		var p := Particle.new()
		p.pos = pos
		p.vel = Vector2.from_angle(ang) * spd
		p.radius = randf_range(3.0, 6.0) if boss else randf_range(2.0, 5.0)
		p.color = Color("#6b21a8") if boss else Color("#991b1b")
		particles.append(p)


func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.pos += p.vel * delta
		p.alpha -= 1.8 * delta
		if p.alpha <= 0.0:
			particles.remove_at(i)
	for i in range(explosions.size() - 1, -1, -1):
		var e := explosions[i]
		e.alpha -= 3.0 * delta
		if e.alpha <= 0.0:
			explosions.remove_at(i)


# ------------------------------------------------------------------ drawing helpers
func _circ(c: Vector2, r: float, fill: Color, outline := Color(0, 0, 0, 0), w := 0.0) -> void:
	draw_circle(c, r, fill)
	if w > 0.0:
		draw_arc(c, r, 0.0, TAU, 28, outline, w, true)


func _ell(c: Vector2, rx: float, ry: float, fill: Color, outline := Color(0, 0, 0, 0), w := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, fill)
	if w > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, outline, w, true)


func _rrect(r: Rect2, fill: Color, outline: Color, w: float) -> void:
	draw_rect(r, fill)
	draw_rect(r, outline, false, w)


func _quad(p0: Vector2, p1: Vector2, p2: Vector2, steps := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return pts


func _reset_xform() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color("#223821"))
	var tile := Color("#2b4729")
	var x := 0
	while x < MAP_SIZE:
		var y := 0
		while y < MAP_SIZE:
			if (x + y) % 280 == 0:
				draw_rect(Rect2(x, y, 140, 140), tile)
			y += 140
		x += 140

	_draw_decorations()
	draw_rect(Rect2(50, 50, MAP_SIZE - 100, MAP_SIZE - 100), Color("#38220f"), false, 8.0)

	for z in zombies:
		_draw_zombie(z)
	if in_game:
		_draw_player()

	for b in bullets:
		draw_circle(b.pos, 5.0 if b.is_rocket else 3.5, b.color)
	for p in particles:
		var c := p.color
		c.a = clampf(p.alpha, 0.0, 1.0)
		draw_circle(p.pos, p.radius, c)
	for e in explosions:
		draw_circle(e.pos, e.radius * (2.0 - e.alpha), Color(0.937, 0.267, 0.267, 0.45))


func _draw_decorations() -> void:
	for d in decorations:
		var p: Vector2 = d["pos"]
		match d["type"]:
			"oak":
				var r: float = d["radius"]
				_circ(p, r * 0.38, Color("#4a2f1d"), Color("#27170c"), 3.0)
				for f in d["flakes"]:
					draw_rect(Rect2(p + f["off"], Vector2(f["size"], f["size"])), Color("#362112"))
				draw_circle(p + Vector2(-4, -4), r * 0.85, Color("#2c5233"))
				draw_circle(p, r * 0.72, Color("#386641"))
				draw_circle(p + Vector2(6, 6), r * 0.5, Color("#417a4b"))
			"birch":
				var r: float = d["radius"]
				_circ(p, r * 0.32, Color("#d4d4d4"), Color("#262626"), 2.5)
				draw_rect(Rect2(p.x - 3, p.y - 5, 6, 3), Color("#525252"))
				draw_rect(Rect2(p.x - 2, p.y + 4, 4, 2), Color("#525252"))
				draw_circle(p, r * 0.7, Color("#487c53"))
			"boulder":
				var r: float = d["radius"]
				_circ(p, r, Color("#525b52"), Color("#2f362f"), 2.5)
				draw_circle(p + Vector2(-3, -3), r * 0.45, Color("#3f6233"))
			"flowers":
				var c := Color("#facc15") if d["yellow"] else Color("#ffffff")
				draw_circle(p, 4.0, c)
				draw_circle(p + Vector2(6, -4), 3.0, c)
				draw_circle(p + Vector2(-5, 5), 3.5, c)


func _draw_zombie(z: Zombie) -> void:
	draw_set_transform(z.pos, z.angle, Vector2.ONE)
	var skin := Color("#d49b78")
	var edge := Color("#27170c")
	if z.is_boss:
		var hand := Color("#6b21a8")
		_rrect(Rect2(-6, -28, 34, 12), skin, edge, 2.5)
		_circ(Vector2(28, -22), 6.0, hand)
		_rrect(Rect2(-6, 16, 34, 12), skin, edge, 2.5)
		_circ(Vector2(28, 22), 6.0, hand)
		_ell(Vector2(-4, 0), 22.0, 23.0, Color("#581c87"), Color("#3b0764"), 4.0)
		_circ(Vector2(-2, 0), 13.0, Color("#78350f"), edge, 3.0)
	else:
		var hand := Color("#b91c1c")
		_rrect(Rect2(-4, -22, 26, 9), skin, edge, 2.0)
		_circ(Vector2(22, -18), 4.5, hand)
		_rrect(Rect2(-4, 13, 26, 9), skin, edge, 2.0)
		_circ(Vector2(22, 18), 4.5, hand)
		_ell(Vector2(-4, 0), 16.0, 17.0, Color("#3f622d"), Color("#1b2e12"), 3.0)
		draw_rect(Rect2(2, -6, 5, 5), Color("#991b1b"))
		draw_rect(Rect2(-8, 5, 4, 4), Color("#991b1b"))
		_circ(Vector2(-2, 0), 9.5, Color("#78350f"), edge, 2.5)
	_reset_xform()
	if z.is_boss:
		var bar := Rect2(z.pos.x - 20.0, z.pos.y - 42.0, 40.0, 6.0)
		draw_rect(bar, Color("#0f172a"))
		draw_rect(Rect2(bar.position, Vector2(40.0 * clampf(z.hp / z.max_hp, 0.0, 1.0), 6.0)), Color("#ef4444"))


func _draw_player() -> void:
	draw_set_transform(player_pos, player_angle, Vector2.ONE)
	var ol := Color("#0d140a")
	var arm_col := Color("#2d3e3a")

	# backpack
	_rrect(Rect2(-22, -13, 14, 26), Color("#3b4727"), ol, 2.5)
	draw_rect(Rect2(-20, -10, 10, 6), Color("#4c5c32"))
	draw_rect(Rect2(-20, 4, 10, 6), Color("#4c5c32"))
	draw_rect(Rect2(-20, -10, 10, 6), Color("#1e2614"), false, 1.2)
	draw_rect(Rect2(-20, 4, 10, 6), Color("#1e2614"), false, 1.2)

	# torso + vest
	_ell(Vector2(-2, 0), 14.0, 16.0, arm_col, ol, 3.0)
	_rrect(Rect2(-6, -11, 12, 22), Color("#7a6b4f"), ol, 1.5)

	# arms
	var a1 := _quad(Vector2(-2, -13), Vector2(12, -16), Vector2(17, -5))
	a1.append(Vector2(11, -1))
	a1.append_array(_quad(Vector2(11, -1), Vector2(8, -10), Vector2(-2, -8)))
	draw_colored_polygon(a1, arm_col)
	a1.append(a1[0])
	draw_polyline(a1, ol, 2.5, true)

	var a2 := _quad(Vector2(-2, 13), Vector2(12, 15), Vector2(18, 5))
	a2.append(Vector2(12, 1))
	a2.append_array(_quad(Vector2(12, 1), Vector2(6, 9), Vector2(-2, 7)))
	draw_colored_polygon(a2, arm_col)
	a2.append(a2[0])
	draw_polyline(a2, ol, 2.5, true)

	# hands
	_circ(Vector2(16, -2), 3.5, Color("#4a3525"), ol, 1.5)
	_circ(Vector2(17, 2), 3.5, Color("#4a3525"), ol, 1.5)

	# weapon
	var wc: Color = WEAPONS[current_weapon]["color"]
	draw_rect(Rect2(15, -2.5, 16, 4), wc)
	draw_rect(Rect2(31, -2.5, 3.5, 5), Color("#0f172a"))
	draw_rect(Rect2(15, -2.5, 16, 4), ol, false, 1.2)

	# head + helmet hair
	_circ(Vector2(-2, 0), 9.5, Color("#e09f67"))
	_circ(Vector2(-2, 0), 8.5, Color("#262322"), ol, 2.5)
	var hair := PackedVector2Array([Vector2(3, 0)])
	for i in range(13):
		var a := lerpf(-PI / 2.2, PI / 2.2, i / 12.0)
		hair.append(Vector2(3, 0) + Vector2(cos(a), sin(a)) * 7.5)
	draw_colored_polygon(hair, Color("#141211"))
	_reset_xform()
