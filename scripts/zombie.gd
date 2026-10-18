class_name Zombie
extends CharacterBody3D
## Graveyard zombie (also used for bosses). Hit zones: head / body / legs. Leg hits slow it down permanently.

enum S { RISING, CHASE, WINDUP, RECOVER, STUNNED, DEAD }

var is_boss := false
var wave := 1
var max_hp := 60.0
var hp := 60.0
var damage := 12.0
var base_speed := 1.8
var attack_range := 1.7
var state: int = S.RISING
var leg_hits := 0
var model: Node3D
var limbs: Dictionary = {}
var model_scale := 1.0

var _t := 0.0
var _rise := 0.0
var _wind := 0.0
var _rec := 0.0
var _stun := 0.0
var _flinch := 0.0
var _atk_cd := 1.0
var _groan_t := 3.0
var _stomp_t := 0.5
var _roar_t := 8.0
var _avoid_t := 0.0
var _avoid_angle := 0.0
var _bias := 1.0
var _stuck := 0.0
var _unstick_t := 0.0
var _unstick_dir := Vector3.ZERO
var _sep := Vector3.ZERO
var _sep_t := 0.0
var _hit_blink := 0.0


func setup(w: int, boss: bool) -> void:
	wave = w
	is_boss = boss
	if boss:
		max_hp = 300.0 + 120.0 * w
		damage = 28.0 + w
		base_speed = 1.5
		attack_range = 2.8
		model_scale = 1.45
	else:
		max_hp = 60.0 + 25.0 * (w - 1)
		damage = 11.0 + 0.8 * w
		base_speed = minf(1.5 + randf() * 0.5 + 0.05 * w, 3.3)
		model_scale = randf_range(0.78, 0.86)
	hp = max_hp


func _ready() -> void:
	collision_layer = GameState.L_ZOMBIE
	collision_mask = GameState.L_WORLD | GameState.L_PLAYER
	add_to_group("zombies")
	_bias = 1.0 if randf() > 0.5 else -1.0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * (1.5 if is_boss else 1.0)
	cap.height = 2.3 * model_scale
	cs.shape = cap
	cs.position = Vector3(0, 1.15 * model_scale, 0)
	add_child(cs)
	_build_model()
	_t = randf() * 10.0
	_rise = 0.0
	model.position.y = -2.2 * model_scale
	FX.dust(global_position + Vector3(0, 0.1, 0), 10, 0.25)


func _area(parent: Node3D, shape: Shape3D, pos: Vector3, zone: String) -> void:
	var a := Area3D.new()
	a.collision_layer = GameState.L_HITBOX
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape3D.new()
	cs.shape = shape
	a.add_child(cs)
	a.position = pos
	a.set_meta("zone", zone)
	a.set_meta("zombie", self)
	parent.add_child(a)


func _build_model() -> void:
	var skin := Color("#6f8460") if not is_boss else Color("#4d5b46")
	var shirt := Color("#4a3f38").lightened(randf_range(-0.05, 0.1))
	var pants := Color("#2a2a30")
	if is_boss:
		shirt = Color("#2a1418")
		pants = Color("#1a1418")
	model = Node3D.new()
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	var hips := Node3D.new()
	hips.position = Vector3(0, 0.97, 0)
	model.add_child(hips)
	limbs["hips"] = hips
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.15, 0, 0)
		hips.add_child(leg)
		Prim.capsule(leg, 0.125, 0.95, pants, Vector3(0, -0.46, 0))
		Prim.box(leg, Vector3(0.22, 0.12, 0.34), Color("#1c1816"), Vector3(0, -0.9, -0.05))
		var cap := CapsuleShape3D.new()
		cap.radius = 0.2
		cap.height = 0.95
		_area(leg, cap, Vector3(0, -0.46, 0), "leg")
		limbs["legL" if side < 0 else "legR"] = leg
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.05, 0)
	hips.add_child(torso)
	Prim.capsule(torso, 0.3, 0.82, shirt, Vector3(0, 0.42, 0))
	Prim.box(torso, Vector3(0.1, 0.3, 0.04), shirt.darkened(0.4), Vector3(0.14, 0.05, -0.29))
	Prim.box(torso, Vector3(0.1, 0.2, 0.04), skin.darkened(0.2), Vector3(-0.1, 0.25, -0.29))
	var tb := BoxShape3D.new()
	tb.size = Vector3(0.7, 0.9, 0.5)
	_area(torso, tb, Vector3(0, 0.42, 0), "body")
	limbs["torso"] = torso
	var head := Node3D.new()
	head.position = Vector3(0, 0.88, 0)
	torso.add_child(head)
	Prim.sphere(head, 0.26, skin, Vector3(0, 0.24, 0))
	for e in [-1, 1]:
		Prim.sphere(head, 0.06, Color("#ffe27a") if not is_boss else Color("#ff2a1a"), Vector3(e * 0.1, 0.29, -0.22), 1.0, 2.0)
	Prim.box(head, Vector3(0.16, 0.05, 0.04), Color("#2a0d0d"), Vector3(0, 0.1, -0.25))
	if is_boss:
		for i in 3:
			var sp := Prim.cyl(head, 0.0, 0.07, 0.3, Color("#cfc6b0"), Vector3((i - 1) * 0.15, 0.52, 0.0))
			sp.rotation.z = (i - 1) * -0.3
	var hs := SphereShape3D.new()
	hs.radius = 0.3
	_area(head, hs, Vector3(0, 0.24, 0), "head")
	limbs["head"] = head
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.4, 0.72, 0)
		torso.add_child(arm)
		Prim.capsule(arm, 0.09, 0.7, shirt.darkened(0.1), Vector3(0, -0.3, 0))
		Prim.sphere(arm, 0.1, skin, Vector3(0, -0.66, 0))
		limbs["armL" if side < 0 else "armR"] = arm


func is_dead() -> bool:
	return state == S.DEAD


func speed_mult() -> float:
	return maxf(0.22, 1.0 - 0.17 * float(leg_hits))


func is_crawling() -> bool:
	return leg_hits >= 5


## zone: "head" | "body" | "leg". Returns true if this hit killed the zombie.
func take_hit(dmg: float, zone: String, from_dir: Vector3) -> bool:
	if state == S.DEAD:
		return false
	var d := dmg
	if zone == "head":
		d *= 2.2 if is_boss else 4.0
	hp -= d
	_hit_blink = 0.1
	_flinch = 0.12 if not is_boss else 0.0
	if zone == "leg":
		leg_hits += 1
	FX.blood(global_position + Vector3(0, 1.3 if zone == "head" else 1.0, 0) * model_scale, from_dir, zone == "head")
	AudioManager.play3d("headshot" if zone == "head" else "zombie_hit", global_position + Vector3(0, 1.2, 0), 0.0, randf_range(0.9, 1.1))
	if hp <= 0.0:
		_die(zone == "head")
		return true
	return false


func stun(secs: float) -> void:
	if state == S.DEAD or state == S.RISING:
		return
	state = S.STUNNED
	_stun = secs * (0.4 if is_boss else 1.0)


func _die(headshot: bool) -> void:
	state = S.DEAD
	remove_from_group("zombies")
	collision_layer = 0
	collision_mask = GameState.L_WORLD
	for a in find_children("*", "Area3D", true, false):
		(a as Area3D).collision_layer = 0
	AudioManager.play3d("zombie_death", global_position + Vector3(0, 1.0, 0), 0.0, 0.8 if is_boss else randf_range(0.9, 1.1))
	GameState.zombie_killed.emit(self, headshot)
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", (1.5 if randf() > 0.5 else -1.5), 0.45)
	tw.parallel().tween_property(model, "position:y", 0.2, 0.45)
	tw.tween_interval(4.0)
	tw.tween_property(model, "position:y", -1.5, 1.5)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		velocity = Vector3.ZERO
		return
	_t += delta
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_flinch = maxf(0.0, _flinch - delta)
	var pl: Node3D = GameState.player
	if pl == null:
		return
	match state:
		S.RISING:
			_rise += delta / 1.1
			model.position.y = lerpf(-2.2 * model_scale, 0.0, clampf(_rise, 0.0, 1.0))
			CharAnimZ.pose(self, "stand", delta)
			if _rise >= 1.0:
				state = S.CHASE
				model.position.y = 0.0
				if is_boss:
					AudioManager.play3d("boss_roar", global_position + Vector3(0, 2, 0), 4.0)
					GameState.camera_shake.emit(0.7)
		S.CHASE:
			_chase(pl, delta)
		S.WINDUP:
			_wind -= delta
			_halt(delta)
			_face(pl.global_position, delta)
			CharAnimZ.pose(self, "windup", delta)
			if _wind <= 0.0:
				_strike(pl)
				state = S.RECOVER
				_rec = 0.6
				_atk_cd = 1.2 if not is_boss else 1.8
		S.RECOVER:
			_rec -= delta
			_halt(delta)
			CharAnimZ.pose(self, "strike", delta)
			if _rec <= 0.0:
				state = S.CHASE
		S.STUNNED:
			_stun -= delta
			_halt(delta)
			CharAnimZ.pose(self, "stun", delta)
			if _stun <= 0.0:
				state = S.CHASE
	if _hit_blink > 0.0:
		_hit_blink -= delta


func _halt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	_gravity(delta)
	move_and_slide()


func _gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _face(p: Vector3, delta: float) -> void:
	var d := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	if d.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-10.0 * delta))


func _chase(pl: Node3D, delta: float) -> void:
	var to := Vector3(pl.global_position.x - global_position.x, 0, pl.global_position.z - global_position.z)
	var dist := to.length()
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(3.0, 7.0)
		AudioManager.play3d("groan_%d" % (1 + randi() % 3), global_position + Vector3(0, 1.5, 0), 2.0 if is_boss else -2.0, 0.65 if is_boss else randf_range(0.85, 1.15))
	if is_boss:
		_roar_t -= delta
		if _roar_t <= 0.0:
			_roar_t = randf_range(10.0, 16.0)
			AudioManager.play3d("boss_roar", global_position + Vector3(0, 2, 0), 3.0)
	if dist <= attack_range * 0.9 and _atk_cd <= 0.0 and _flinch <= 0.0 and not GameState.finished:
		state = S.WINDUP
		_wind = 0.9 if is_boss else 0.55
		return
	var spd := base_speed * speed_mult()
	if _flinch > 0.0:
		spd = 0.0
	var want := Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z)
	if dist > attack_range * 0.7 and spd > 0.0:
		var dir := to / maxf(dist, 0.01)
		_avoid_t -= delta
		if _avoid_t <= 0.0:
			_avoid_t = 0.15
			var free := SteerUtil.free_dir(self, dir, _bias, 2.2)
			_avoid_angle = dir.signed_angle_to(free, Vector3.UP)
		dir = dir.rotated(Vector3.UP, _avoid_angle)
		_sep_t -= delta
		if _sep_t <= 0.0:
			_sep_t = 0.25
			_sep = _separation()
		dir = (dir + _sep * 0.8).normalized()
		if _unstick_t > 0.0:
			_unstick_t -= delta
			dir = _unstick_dir
		want = dir * spd
		if hv.length() < spd * 0.25:
			_stuck += delta
			if _stuck > 1.0:
				_stuck = 0.0
				_unstick_t = 0.8
				_unstick_dir = dir.rotated(Vector3.UP, _bias * PI * 0.6)
				_bias = -_bias
		else:
			_stuck = maxf(0.0, _stuck - delta)
	hv = hv.move_toward(want, 12.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	_gravity(delta)
	move_and_slide()
	if hv.length() > 0.2:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-hv.x, -hv.z), 1.0 - exp(-8.0 * delta))
		if is_boss:
			_stomp_t -= delta * hv.length()
			if _stomp_t <= 0.0:
				_stomp_t = 1.6
				AudioManager.play3d("stomp", global_position, 2.0)
				if dist < 22.0:
					GameState.camera_shake.emit(0.25 * (1.0 - dist / 22.0) + 0.05)
	CharAnimZ.pose(self, "crawl" if is_crawling() else "walk", delta, hv.length())


func _separation() -> Vector3:
	var out := Vector3.ZERO
	for o in get_tree().get_nodes_in_group("zombies"):
		if o != self:
			var d: Vector3 = global_position - o.global_position
			d.y = 0.0
			var l: float = d.length()
			if l < 1.1 and l > 0.01:
				out += d / l * (1.1 - l)
	return out


func _strike(pl: Node3D) -> void:
	var d := Vector3(pl.global_position.x - global_position.x, 0, pl.global_position.z - global_position.z).length()
	AudioManager.play3d("zombie_attack", global_position + Vector3(0, 1.4, 0), 0.0, 0.7 if is_boss else 1.0)
	if d <= attack_range * 1.35:
		pl.call("take_damage", damage, global_position)
		if is_boss:
			GameState.camera_shake.emit(0.5)
