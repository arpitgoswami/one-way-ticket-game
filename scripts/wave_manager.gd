class_name WaveManager
extends Node
## Infinite waves. 2-3 zombies per wave; every 5th wave adds a boss + 2 zombies. Spawns extra zombies if the player camps.

enum St { INTRO, SPAWNING, ACTIVE, BREAK, OVER }

@export var max_alive := 12
@export var camp_time := 2.0
@export var camp_cooldown := 18.0
@export var break_time := 6.0

var state: int = St.INTRO
var wave := 0
var queue: Array = []          # [{"boss": bool}]
var _timer := 3.0
var _spawn_t := 0.0
var _camp_cd := 8.0
var _cleared_fired := false


func _ready() -> void:
	GameState.player_died.connect(func() -> void: state = St.OVER)


func alive_count() -> int:
	return get_tree().get_nodes_in_group("zombies").size()


func remaining() -> int:
	return alive_count() + queue.size()


func _physics_process(delta: float) -> void:
	if state == St.OVER or GameState.finished:
		return
	match state:
		St.INTRO, St.BREAK:
			_timer -= delta
			if _timer <= 0.0:
				_start_wave()
		St.SPAWNING:
			_spawn_t -= delta
			if _spawn_t <= 0.0 and queue.size() > 0:
				_spawn_t = 1.4
				var e: Dictionary = queue.pop_front()
				_spawn(e["boss"])
			if queue.is_empty():
				state = St.ACTIVE
		St.ACTIVE:
			_camp_logic(delta)
			if alive_count() == 0 and queue.is_empty():
				_clear_wave()
	if state == St.SPAWNING:
		_camp_logic(delta)


func _start_wave() -> void:
	wave += 1
	GameState.wave = wave
	var boss := wave % 5 == 0
	queue.clear()
	if boss:
		queue.append({"boss": true})
		queue.append({"boss": false})
		queue.append({"boss": false})
	else:
		for i in randi_range(2, 3):
			queue.append({"boss": false})
	state = St.SPAWNING
	_spawn_t = 0.5
	_cleared_fired = false
	GameState.wave_started.emit(wave, boss)
	AudioManager.play("sting", -2.0)


func _clear_wave() -> void:
	state = St.BREAK
	_timer = break_time
	GameState.add_score(200 * wave)
	GameState.wave_cleared.emit(wave)


func _camp_logic(delta: float) -> void:
	_camp_cd -= delta
	var pl: Node3D = GameState.player
	if pl == null or not pl.get("alive"):
		return
	if pl.still_time >= camp_time and _camp_cd <= 0.0 and alive_count() < max_alive:
		_camp_cd = camp_cooldown
		pl.still_time = 0.0
		var n := randi_range(2, 3)
		for i in n:
			if alive_count() >= max_alive:
				break
			_spawn(false)
		GameState.message.emit("DON'T STAND STILL")


func spawn_point(min_dist: float = 20.0) -> Vector3:
	var A: float = GameState.AREA - 2.0
	var pl: Node3D = GameState.player
	var best := Vector3(A, 0, A)
	for i in 14:
		var p := Vector3.ZERO
		var side := randi() % 4
		var t := randf_range(-A, A)
		match side:
			0:
				p = Vector3(t, 0, -A)
			1:
				p = Vector3(t, 0, A)
			2:
				p = Vector3(-A, 0, t)
			_:
				p = Vector3(A, 0, t)
		best = p
		if pl == null or pl.global_position.distance_to(p) >= min_dist:
			return p
	return best


func _spawn(boss: bool) -> Zombie:
	var z := Zombie.new()
	z.setup(wave, boss)
	GameState.world.add_child(z)
	z.global_position = spawn_point(24.0 if boss else 20.0)
	if boss:
		GameState.boss_spawned.emit(z)
	return z
