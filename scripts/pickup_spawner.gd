class_name PickupSpawner
extends Node
## Spawns random pickups inside the graveyard and handles collecting them.

@export var max_pickups := 10
@export var spawn_interval_min := 5.0
@export var spawn_interval_max := 9.0

var pickups: Array = []
var _timer := 3.0


func _ready() -> void:
	GameState.wave_cleared.connect(_on_wave_cleared)
	GameState.zombie_killed.connect(_on_zombie_killed)
	for i in 4:
		spawn_random()


func random_pos(min_from_player: float = 3.0) -> Vector3:
	var A: float = GameState.AREA - 4.0
	var pl: Node3D = GameState.player
	for i in 12:
		var p := Vector3(randf_range(-A, A), 0, randf_range(-A, A))
		if pl == null or pl.global_position.distance_to(p) > min_from_player:
			return p
	return Vector3(randf_range(-A, A), 0, randf_range(-A, A))


func spawn_at(kind: String, pos: Vector3) -> void:
	pickups = pickups.filter(func(p: Variant) -> bool: return is_instance_valid(p))
	if pickups.size() >= max_pickups + 6:
		var old: Node = pickups.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var p := Pickup.new()
	p.kind = kind
	GameState.world.add_child(p)
	p.global_position = Vector3(pos.x, 0, pos.z)
	pickups.append(p)


func spawn_random() -> void:
	pickups = pickups.filter(func(p: Variant) -> bool: return is_instance_valid(p))
	if pickups.size() >= max_pickups:
		return
	var r := randf()
	var kind := "coin"
	if r < 0.4:
		kind = "coin"
	elif r < 0.62:
		kind = "ammo"
	elif r < 0.80:
		kind = "medkit"
	else:
		kind = "diesel"
	spawn_at(kind, random_pos())


func _on_wave_cleared(_w: int) -> void:
	# a small number of grenades after each wave
	var n := 1 + (1 if randf() < 0.35 else 0)
	for i in n:
		spawn_at("flash" if randf() < 0.5 else "frag", random_pos(6.0))
	spawn_at("ammo", random_pos(6.0))


func _on_zombie_killed(z: Node, _hs: bool) -> void:
	if randf() < 0.35:
		spawn_at("coin", z.global_position)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(spawn_interval_min, spawn_interval_max)
		spawn_random()
	var pl: Node3D = GameState.player
	if pl == null or not pl.get("alive"):
		return
	for p in pickups:
		if not is_instance_valid(p):
			continue
		var d := Vector2(p.global_position.x - pl.global_position.x, p.global_position.z - pl.global_position.z).length()
		if d < 1.5 and _collect(p, pl):
			p.queue_free()
	pickups = pickups.filter(func(q: Variant) -> bool: return is_instance_valid(q) and not q.is_queued_for_deletion())


func _collect(p: Pickup, pl: Node3D) -> bool:
	var w: Node = pl.get("weapons")
	match p.kind:
		"coin":
			GameState.coins += 1
			AudioManager.play("coin", -4.0)
		"medkit":
			if pl.health >= pl.max_health:
				return false
			pl.heal(35.0)
			AudioManager.play("pickup")
		"ammo":
			w.add_ammo()
			AudioManager.play("pickup")
		"diesel":
			w.add_diesel(40.0)
			AudioManager.play("pickup")
		"flash":
			w.add_grenade("flash", 1)
			AudioManager.play("pickup")
		_:
			w.add_grenade("frag", 1)
			AudioManager.play("pickup")
	GameState.pickup_collected.emit(p.kind)
	return true
