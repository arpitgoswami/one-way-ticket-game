class_name WeaponManager
extends Node3D
## Chainsaw, pistol, machine gun and two grenade types. Viewmodels are built from primitives.

const GUNS := ["chainsaw", "pistol", "mg"]
const MAG := {"pistol": 12, "mg": 30}
const RELOAD_TIME := {"pistol": 1.2, "mg": 2.0}

@export var pistol_damage := 30.0
@export var mg_damage := 15.0
@export var saw_damage := 16.0

var player: Player
var current := "pistol"
var prev_gun := "pistol"
var ammo := {"pistol": {"mag": 12, "res": 36}, "mg": {"mag": 30, "res": 60}}
var diesel := 60.0
var grenades := {"flash": 1, "frag": 1}
var last_grenade := "frag"
var reloading := false
var shot_kick := 0.0   # 0..1, read by the crosshair

var _hand: Node3D
var _models: Dictionary = {}
var _muzzles: Dictionary = {}
var _flash_light: OmniLight3D
var _flash_t := 0.0
var _cd := 0.0
var _spread := 0.0
var _reload_t := 0.0
var _reload_total := 1.0
var _reload_sound := 0
var _sw_phase := 0
var _sw_t := 0.0
var _sw_target := "pistol"
var _kick := 0.0
var _saw_tick := 0.0
var _saw_idle: AudioStreamPlayer
var _saw_rev: AudioStreamPlayer
var _sway := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	_hand = Node3D.new()
	_hand.position = Vector3(0.26, -0.27, -0.55)
	add_child(_hand)
	_build_models()
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color("#ffc060")
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 9.0
	add_child(_flash_light)
	_flash_light.position = Vector3(0.26, -0.2, -1.0)
	_saw_idle = AudioManager.make_loop_player("chainsaw_idle", -6.0)
	_saw_rev = AudioManager.make_loop_player("chainsaw_rev", -3.0)
	add_child(_saw_idle)
	add_child(_saw_rev)
	_show_model("pistol")


func _build_models() -> void:
	var dark := Color("#1a1a1e")
	var steel := Color("#3a3d44")
	# Pistol
	var p := Node3D.new()
	Prim.box(p, Vector3(0.06, 0.075, 0.3), steel, Vector3(0, 0, 0), 0.4)
	Prim.box(p, Vector3(0.05, 0.05, 0.12), dark, Vector3(0, -0.01, -0.2), 0.4)
	Prim.box(p, Vector3(0.055, 0.15, 0.07), dark, Vector3(0, -0.11, 0.09))
	Prim.box(p, Vector3(0.02, 0.02, 0.02), Color("#d01818"), Vector3(0, 0.045, 0.1), 0.4, 1.0)
	_add_muzzle(p, "pistol", Vector3(0, 0, -0.3))
	# Machine gun
	var m := Node3D.new()
	Prim.box(m, Vector3(0.07, 0.1, 0.55), steel, Vector3(0, 0, 0), 0.4)
	Prim.cyl(m, 0.015, 0.015, 0.3, dark, Vector3(0, 0.01, -0.4), 0.4).rotation.x = PI * 0.5
	Prim.box(m, Vector3(0.05, 0.2, 0.08), dark, Vector3(0, -0.15, -0.05))
	Prim.box(m, Vector3(0.055, 0.12, 0.07), dark, Vector3(0, -0.1, 0.18))
	Prim.box(m, Vector3(0.06, 0.1, 0.25), Color("#4a3a2a"), Vector3(0, -0.01, 0.38))
	Prim.box(m, Vector3(0.03, 0.04, 0.06), dark, Vector3(0, 0.07, -0.1))
	_add_muzzle(m, "mg", Vector3(0, 0.01, -0.58))
	# Chainsaw
	var c := Node3D.new()
	Prim.box(c, Vector3(0.14, 0.17, 0.34), Color("#d85a14"), Vector3(0, 0, 0.05), 0.5)
	Prim.box(c, Vector3(0.04, 0.09, 0.6), Color("#9aa0a8"), Vector3(0, 0.0, -0.4), 0.3)
	Prim.box(c, Vector3(0.05, 0.1, 0.62), dark, Vector3(0, 0.0, -0.4), 0.8)
	Prim.box(c, Vector3(0.05, 0.05, 0.22), dark, Vector3(0, 0.13, 0.1))
	Prim.box(c, Vector3(0.18, 0.04, 0.04), dark, Vector3(0, 0.1, 0.22))
	_models["chainsaw"] = c
	_models["pistol"] = p
	_models["mg"] = m
	# Grenades
	var f := Node3D.new()
	Prim.cyl(f, 0.04, 0.04, 0.16, Color("#e8e8e8"), Vector3.ZERO, 0.4)
	Prim.cyl(f, 0.045, 0.045, 0.03, Color("#d01818"), Vector3(0, 0.04, 0))
	var g := Node3D.new()
	Prim.sphere(g, 0.065, Color("#3d4a3a"), Vector3.ZERO, 1.25)
	Prim.cyl(g, 0.02, 0.02, 0.04, Color("#aaaaaa"), Vector3(0, 0.09, 0))
	_models["flash"] = f
	_models["frag"] = g
	for k in _models:
		_hand.add_child(_models[k])
		_models[k].visible = false


func _add_muzzle(parent: Node3D, key: String, pos: Vector3) -> void:
	var mz := Node3D.new()
	mz.position = pos
	parent.add_child(mz)
	var fl := Prim.sphere(mz, 0.06, Color("#ffd27a"), Vector3.ZERO, 1.0, 4.0)
	fl.scale = Vector3(1, 1, 2.0)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fl.visible = false
	_muzzles[key] = mz


func _show_model(k: String) -> void:
	for n in _models:
		_models[n].visible = n == k
	current = k


# ------------------------------------------------------------ public API

func weapon_name() -> String:
	match current:
		"chainsaw":
			return "CHAINSAW"
		"pistol":
			return "PISTOL"
		"mg":
			return "MACHINE GUN"
		"flash":
			return "FLASHBANG"
	return "GRENADE"


func ammo_text() -> String:
	match current:
		"chainsaw":
			return "FUEL %d" % int(diesel)
		"pistol", "mg":
			var a: Dictionary = ammo[current]
			return "%d / %d" % [a["mag"], a["res"]]
	return "x %d" % int(grenades[current])


func add_ammo() -> void:
	ammo["pistol"]["res"] = mini(ammo["pistol"]["res"] + 12, 120)
	ammo["mg"]["res"] = mini(ammo["mg"]["res"] + 30, 240)


func add_diesel(x: float) -> void:
	diesel = minf(100.0, diesel + x)


func add_grenade(kind: String, n: int) -> void:
	grenades[kind] = mini(int(grenades[kind]) + n, 9)


func is_busy_for_sprint() -> bool:
	return false


func is_grenade() -> bool:
	return current == "flash" or current == "frag"


func equip(k: String) -> void:
	if k == current or _sw_phase != 0:
		return
	if (k == "flash" or k == "frag") and int(grenades[k]) <= 0:
		AudioManager.play("empty", -6.0)
		return
	if not is_grenade():
		prev_gun = current
	if k == "flash" or k == "frag":
		last_grenade = k
	reloading = false
	_sw_target = k
	_sw_phase = 1
	_sw_t = 0.0


func _cycle(dir: int) -> void:
	var base := prev_gun if is_grenade() else current
	var i := GUNS.find(base)
	i = (i + dir + GUNS.size()) % GUNS.size()
	if is_grenade():
		prev_gun = GUNS[i]
		equip(GUNS[i])
	else:
		equip(GUNS[i])


func _unhandled_input(event: InputEvent) -> void:
	if not player.alive or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle(1)


# ------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	_time += delta
	_cd = maxf(0.0, _cd - delta)
	_spread = maxf(0.0, _spread - delta * 0.12)
	shot_kick = maxf(0.0, shot_kick - delta * 4.0)
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-16.0 * delta))
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash_light.light_energy = 0.0
			for k in _muzzles:
				_muzzles[k].get_child(0).visible = false
	if not player.alive:
		_saw_idle.stop()
		_saw_rev.stop()
		return
	# switching animation
	if _sw_phase == 1:
		_sw_t += delta / 0.12
		if _sw_t >= 1.0:
			_show_model(_sw_target)
			_sw_phase = 2
			_sw_t = 0.0
	elif _sw_phase == 2:
		_sw_t += delta / 0.14
		if _sw_t >= 1.0:
			_sw_phase = 0
	# input
	if Input.is_action_just_pressed("weapon_1"):
		equip("chainsaw")
	elif Input.is_action_just_pressed("weapon_2"):
		equip("pistol")
	elif Input.is_action_just_pressed("weapon_3"):
		equip("mg")
	elif Input.is_action_just_pressed("weapon_4"):
		equip("flash")
	elif Input.is_action_just_pressed("weapon_5"):
		equip("frag")
	if Input.is_action_just_pressed("throw_grenade") and _sw_phase == 0:
		var k := last_grenade
		if int(grenades[k]) <= 0:
			k = "flash" if k == "frag" else "frag"
		throw_grenade(k)
	if Input.is_action_just_pressed("reload") and (current == "pistol" or current == "mg"):
		start_reload()
	# reload progress
	if reloading:
		_reload_t += delta
		var frac := _reload_t / _reload_total
		if _reload_sound == 0 and frac > 0.25:
			_reload_sound = 1
			AudioManager.play("reload_a", -4.0, 0.8)
		if _reload_sound == 1 and frac > 0.75:
			_reload_sound = 2
			AudioManager.play("reload_a", -2.0, 1.1)
		if _reload_t >= _reload_total:
			_finish_reload()
	var firing := Input.is_action_pressed("fire") and _sw_phase == 0 and not get_tree().paused
	var fired_press := Input.is_action_just_pressed("fire") and firing
	match current:
		"pistol":
			if fired_press:
				_try_shoot("pistol", 0.25, 0.004, pistol_damage)
		"mg":
			if firing:
				_try_shoot("mg", 0.085, 0.012, mg_damage)
		"chainsaw":
			_chainsaw(delta, firing, fired_press)
		"flash", "frag":
			if fired_press and _cd <= 0.0:
				throw_grenade(current)
	if current != "chainsaw":
		_saw_idle.stop()
		_saw_rev.stop()


func start_reload() -> void:
	if reloading or _sw_phase != 0:
		return
	var a: Dictionary = ammo[current]
	if a["mag"] >= MAG[current] or a["res"] <= 0:
		return
	reloading = true
	_reload_t = 0.0
	_reload_total = RELOAD_TIME[current]
	_reload_sound = 0


func _finish_reload() -> void:
	reloading = false
	var a: Dictionary = ammo[current]
	var need: int = MAG[current] - int(a["mag"])
	var take: int = mini(need, int(a["res"]))
	a["mag"] += take
	a["res"] -= take


func _try_shoot(gun: String, rate: float, base_spread: float, dmg: float) -> void:
	if reloading or _cd > 0.0:
		return
	var a: Dictionary = ammo[gun]
	if a["mag"] <= 0:
		_cd = 0.25
		AudioManager.play("empty", -4.0)
		start_reload()
		return
	a["mag"] -= 1
	_cd = rate
	var move_pen := player.speed_ratio * 0.03
	var spread := base_spread + move_pen + (_spread if gun == "mg" else 0.0)
	if gun == "mg":
		_spread = minf(_spread + 0.0035, 0.04)
	shot_kick = 1.0
	_kick = 0.05 if gun == "pistol" else 0.03
	_flash_t = 0.05
	_flash_light.light_energy = 3.0
	_muzzles[gun].get_child(0).visible = true
	AudioManager.play(gun, -2.0 if gun == "pistol" else -5.0, randf_range(0.95, 1.05))
	player.add_recoil(0.012 if gun == "pistol" else 0.006, randf_range(-0.002, 0.002))
	_eject_casing()
	_hitscan(spread, dmg, _muzzles[gun])


func _hitscan(spread: float, dmg: float, muzzle: Node3D) -> void:
	var cam := player.cam
	var b := cam.global_transform.basis
	var dir := (b * Vector3(randf_range(-spread, spread), randf_range(-spread, spread), -1.0)).normalized()
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, GameState.L_WORLD | GameState.L_HITBOX)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [player.get_rid()]
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	var end := from + dir * 60.0
	if r.is_empty():
		FX.tracer(muzzle.global_position, end)
		return
	end = r["position"]
	FX.tracer(muzzle.global_position, end)
	var col: Object = r["collider"]
	if col is Area3D and (col as Area3D).has_meta("zone"):
		var area: Area3D = col
		var z: Zombie = area.get_meta("zombie")
		var zone: String = area.get_meta("zone")
		if z != null and is_instance_valid(z) and not z.is_dead():
			var killed := z.take_hit(dmg, zone, dir)
			GameState.hit_marker.emit(zone == "head", killed)
	else:
		FX.spark(end, r["normal"])
		FX.dust(end, 3, 0.1)


func _eject_casing() -> void:
	var w: Node3D = GameState.world
	if w == null:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 0.03)
	mi.mesh = bm
	mi.material_override = Prim.mat(Color("#c9a24a"), 0.3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	var b := player.cam.global_transform.basis
	var start := player.cam.global_position + b * Vector3(0.22, -0.2, -0.45)
	mi.global_position = start
	var end := start + b.x * 0.7 + Vector3(0, -1.4, 0) + b.z * 0.2
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", start + b.x * 0.35 + Vector3(0, 0.15, 0), 0.1)
	tw.tween_property(mi, "global_position", end, 0.3)
	tw.tween_callback(mi.queue_free)


func _chainsaw(delta: float, firing: bool, pressed: bool) -> void:
	var has_fuel := diesel > 0.0
	if pressed and not has_fuel:
		AudioManager.play("empty", -4.0)
	if firing and has_fuel and _sw_phase == 0:
		diesel = maxf(0.0, diesel - 5.0 * delta)
		if not _saw_rev.playing:
			_saw_rev.play()
		_saw_idle.stop()
		GameState.camera_shake.emit(0.1)
		_saw_tick -= delta
		if _saw_tick <= 0.0:
			_saw_tick = 0.1
			_saw_hit()
	else:
		_saw_rev.stop()
		if has_fuel and not _saw_idle.playing:
			_saw_idle.play()
		elif not has_fuel:
			_saw_idle.stop()


func _saw_hit() -> void:
	var fwd := -player.cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for z in get_tree().get_nodes_in_group("zombies"):
		var to: Vector3 = z.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		var reach := 2.6 if not z.is_boss else 3.4
		if d < reach and (d < 0.8 or fwd.dot(to.normalized()) > 0.35):
			var killed: bool = z.take_hit(saw_damage, "body", to.normalized())
			GameState.hit_marker.emit(false, killed)


func throw_grenade(kind: String) -> void:
	if int(grenades[kind]) <= 0 or not player.alive:
		return
	grenades[kind] = int(grenades[kind]) - 1
	last_grenade = kind
	var g := Grenade.new()
	g.kind = kind
	GameState.world.add_child(g)
	var b := player.cam.global_transform.basis
	g.global_position = player.cam.global_position + (-b.z) * 0.7 + Vector3(0, -0.15, 0)
	g.linear_velocity = (-b.z) * 14.0 + Vector3.UP * 3.0 + player.velocity * 0.5
	g.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	AudioManager.play("throw", -2.0)
	_cd = 0.6
	if is_grenade() and int(grenades[current]) <= 0:
		equip(prev_gun)


func _process(delta: float) -> void:
	# viewmodel sway / bob / recoil / reload / switch animation
	var ps := player.speed_ratio
	var bob := Vector3(sin(_time * 9.0) * 0.012, absf(cos(_time * 9.0)) * 0.012, 0.0) * ps
	_sway = _sway.lerp(player.look_delta * 0.0004, 1.0 - exp(-10.0 * delta))
	var pos := Vector3(0.26, -0.27, -0.55) + bob + Vector3(-_sway.x, _sway.y, 0.0)
	pos.z += _kick
	var rot := Vector3(_kick * 4.0, 0, 0)
	if reloading:
		var f := clampf(_reload_t / _reload_total, 0.0, 1.0)
		pos.y -= sin(PI * f) * 0.18
		rot.x = -sin(PI * f) * 0.8
		rot.z = sin(PI * f) * 0.4
	if _sw_phase == 1:
		pos.y -= _sw_t * 0.35
		rot.x -= _sw_t * 0.6
	elif _sw_phase == 2:
		pos.y -= (1.0 - _sw_t) * 0.35
		rot.x -= (1.0 - _sw_t) * 0.6
	if current == "chainsaw" and _saw_rev.playing:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.006
	elif current == "chainsaw" and _saw_idle.playing:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.0015
	if is_grenade():
		pos += Vector3(-0.05, 0.03, 0.05)
	_hand.position = pos
	_hand.rotation = rot
