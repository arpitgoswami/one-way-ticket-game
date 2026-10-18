class_name Player
extends CharacterBody3D
## First-person controller: movement, health/armor, camera, death.

@export var walk_speed := 4.6
@export var sprint_speed := 7.8
@export var accel := 38.0
@export var jump_vel := 5.2
@export var gravity := 16.0
@export var mouse_sens := 0.0021

var health := 100.0
var max_health := 100.0
var armor := 0.0
var max_armor := 50.0
var alive := true
var invincible := false
var cam: Camera3D
var head: Node3D
var weapons: WeaponManager
var yaw := 0.0
var pitch := 0.0
var still_time := 0.0
var speed_ratio := 0.0
var look_delta := Vector2.ZERO

var _bob_t := 0.0
var _shake := 0.0
var _invuln := 0.0
var _step_d := 0.0
var _recoil_p := 0.0
var _recoil_y := 0.0


func _ready() -> void:
	collision_layer = GameState.L_PLAYER
	collision_mask = GameState.L_WORLD | GameState.L_ZOMBIE
	GameState.player = self
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)
	head = Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = GameState.fov
	cam.near = 0.05
	cam.far = 300.0
	head.add_child(cam)
	cam.current = true
	weapons = WeaponManager.new()
	weapons.player = self
	cam.add_child(weapons)
	GameState.camera_shake.connect(func(a: float) -> void: _shake = maxf(_shake, a))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	emit_health()


func emit_health() -> void:
	GameState.player_health_changed.emit(health, max_health, armor, max_armor)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and alive:
		var m: InputEventMouseMotion = event
		var s := mouse_sens * GameState.sensitivity
		yaw -= m.relative.x * s
		pitch = clampf(pitch - m.relative.y * s, -1.45, 1.45)
		look_delta += m.relative


func add_recoil(p: float, y: float) -> void:
	_recoil_p += p
	_recoil_y += y


func take_damage(amount: float, _from: Vector3 = Vector3.ZERO) -> void:
	if not alive or _invuln > 0.0 or invincible:
		return
	_invuln = 0.35
	var absorbed := minf(armor, amount * 0.7)
	armor -= absorbed
	health = maxf(0.0, health - (amount - absorbed))
	_shake = maxf(_shake, 0.4)
	AudioManager.play("hurt", -2.0, randf_range(0.9, 1.1))
	GameState.player_damaged.emit(amount)
	emit_health()
	AudioManager.set_breath(1.0 - health / max_health if health < 40.0 else 0.0)
	if health <= 0.0:
		_die()


func heal(x: float) -> void:
	health = minf(max_health, health + x)
	emit_health()
	AudioManager.set_breath(1.0 - health / max_health if health < 40.0 else 0.0)


func add_armor(x: float) -> void:
	armor = minf(max_armor, armor + x)
	emit_health()


func _die() -> void:
	alive = false
	GameState.finished = true
	AudioManager.play("death")
	AudioManager.set_breath(0.0)
	weapons.visible = false
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.35, 0.8)
	tw.parallel().tween_property(cam, "rotation:z", 0.9, 0.8)
	GameState.player_died.emit()


func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	rotation.y = yaw
	if not alive:
		velocity = Vector3.ZERO
		return
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := global_transform.basis * Vector3(inp.x, 0, inp.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var sprinting := Input.is_action_pressed("sprint") and inp.y < 0.0 and not weapons.is_busy_for_sprint()
	var target := dir * (sprint_speed if sprinting else walk_speed)
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_vel
	move_and_slide()
	var spd := Vector3(velocity.x, 0, velocity.z).length()
	speed_ratio = clampf(spd / sprint_speed, 0.0, 1.0)
	if spd < 0.4:
		still_time += delta
	else:
		still_time = 0.0
	# footsteps + head bob
	if is_on_floor() and spd > 0.8:
		_bob_t += delta * (6.0 + spd * 0.9)
		_step_d += spd * delta
		if _step_d > (2.6 if sprinting else 2.0):
			_step_d = 0.0
			AudioManager.play("step", -9.0 if sprinting else -13.0, randf_range(0.85, 1.1))
	else:
		_bob_t += delta * 1.5
	var bob := sin(_bob_t) * 0.035 * clampf(spd / walk_speed, 0.0, 1.5) if spd > 0.8 else sin(_bob_t) * 0.004
	head.position.y = lerpf(head.position.y, 1.6 + bob, 1.0 - exp(-14.0 * delta))
	# recoil recovery and camera feel
	var rp := _recoil_p * (1.0 - exp(-18.0 * delta))
	var ry := _recoil_y * (1.0 - exp(-18.0 * delta))
	pitch = clampf(pitch + rp, -1.45, 1.45)
	yaw += ry
	_recoil_p -= rp
	_recoil_y -= ry
	head.rotation.x = pitch
	_shake = maxf(0.0, _shake - delta * 2.0)
	cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.08
	cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.08
	cam.rotation.z = lerpf(cam.rotation.z, -inp.x * 0.02, 1.0 - exp(-8.0 * delta))
	var fov_t := GameState.fov + (5.0 if sprinting and spd > 5.0 else 0.0)
	cam.fov = lerpf(cam.fov, fov_t, 1.0 - exp(-6.0 * delta))
	look_delta = look_delta.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * delta))
