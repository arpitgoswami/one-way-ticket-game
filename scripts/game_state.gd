extends Node
## Global state: settings, highscores, run stats, signals and input map. (Autoload "GameState")

signal player_health_changed(hp: float, max_hp: float, armor: float, max_armor: float)
signal player_damaged(amount: float)
signal player_died
signal zombie_killed(zombie: Node, headshot: bool)
signal wave_started(wave: int, boss: bool)
signal wave_cleared(wave: int)
signal boss_spawned(boss: Node)
signal pickup_collected(kind: String)
signal hit_marker(headshot: bool, kill: bool)
signal message(text: String)
signal camera_shake(amount: float)
signal flashbanged(intensity: float)

const L_WORLD := 1
const L_PLAYER := 2
const L_ZOMBIE := 4
const L_HITBOX := 8

const AREA := 35.0   # half-size of the playable graveyard

var sensitivity := 1.0
var vol_master := 0.8
var vol_music := 0.5
var vol_sfx := 0.8
var fov := 75.0

var player_name := "PLAYER"
var highscores: Array = []

var player: Node3D = null
var world: Node3D = null
var open_highscores_on_menu := false
var testing := false

var score := 0
var wave := 0
var coins := 0
var kills := 0
var finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	load_settings()
	load_highscores()


func reset_run() -> void:
	score = 0
	wave = 0
	coins = 0
	kills = 0
	finished = false
	player = null
	world = null
	get_tree().paused = false


func _key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _setup_inputs() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("sprint", KEY_SHIFT)
	_key("jump", KEY_SPACE)
	_key("reload", KEY_R)
	_key("interact", KEY_E)
	_key("pause", KEY_ESCAPE)
	_key("shop", KEY_TAB)
	_key("weapon_1", KEY_1)
	_key("weapon_2", KEY_2)
	_key("weapon_3", KEY_3)
	_key("weapon_4", KEY_4)
	_key("weapon_5", KEY_5)
	_key("throw_grenade", KEY_G)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", m)


# ------------------------------------------------------------ persistence

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://owt_settings.cfg") == OK:
		sensitivity = cf.get_value("input", "sensitivity", 1.0)
		fov = cf.get_value("video", "fov", 75.0)
		vol_master = cf.get_value("audio", "master", 0.8)
		vol_music = cf.get_value("audio", "music", 0.5)
		vol_sfx = cf.get_value("audio", "sfx", 0.8)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("input", "sensitivity", sensitivity)
	cf.set_value("video", "fov", fov)
	cf.set_value("audio", "master", vol_master)
	cf.set_value("audio", "music", vol_music)
	cf.set_value("audio", "sfx", vol_sfx)
	cf.save("user://owt_settings.cfg")


func load_highscores() -> void:
	highscores = []
	if FileAccess.file_exists("user://owt_highscores.json"):
		var f := FileAccess.open("user://owt_highscores.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Array:
			highscores = parsed


func submit_score() -> void:
	if testing:
		highscores.append({"name": player_name, "score": score, "wave": wave})
		return
	highscores.append({"name": player_name, "score": score, "wave": wave})
	highscores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	if highscores.size() > 10:
		highscores.resize(10)
	var f := FileAccess.open("user://owt_highscores.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(highscores))


func add_score(n: int) -> void:
	if not finished:
		score += n
