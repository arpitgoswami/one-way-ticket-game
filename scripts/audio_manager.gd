extends Node
## Fully synthesized audio (no asset files). Autoload "AudioManager". Buses: Master, Music, SFX.

const RATE := 22050

var sounds: Dictionary = {}
var _pool2d: Array = []
var _pool3d: Array = []
var _i2 := 0
var _i3 := 0
var music_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var cricket_player: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var _bus_music := -1
var _bus_sfx := -1
var _ambience := false
var _ambient_t := 8.0
var _breath_target := 0.0
var _breath_cur := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["Music", "SFX"]:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, n)
		AudioServer.set_bus_send(idx, "Master")
	_bus_music = AudioServer.get_bus_index("Music")
	_bus_sfx = AudioServer.get_bus_index("SFX")
	_generate_all()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	for i in 20:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 8.0
		p3.max_distance = 60.0
		add_child(p3)
		_pool3d.append(p3)
	music_player = _loop("music", "Music", -4.0)
	wind_player = _loop("wind", "SFX", -16.0)
	cricket_player = _loop("crickets", "SFX", -24.0)
	breath_player = _loop("breath", "SFX", -80.0)
	apply_volumes()


func _loop(sound: String, bus: String, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[sound]
	p.bus = bus
	p.volume_db = vol
	add_child(p)
	return p


func make_loop_player(sound: String, vol_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[sound]
	p.bus = "SFX"
	p.volume_db = vol_db
	return p


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameState.vol_master, 0.0001)))
	AudioServer.set_bus_volume_db(_bus_music, linear_to_db(maxf(GameState.vol_music, 0.0001)))
	AudioServer.set_bus_volume_db(_bus_sfx, linear_to_db(maxf(GameState.vol_sfx, 0.0001)))


func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds.has(sound):
		return
	var p: AudioStreamPlayer = _pool2d[_i2]
	_i2 = (_i2 + 1) % _pool2d.size()
	p.stream = sounds[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play3d(sound: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds.has(sound):
		return
	var p: AudioStreamPlayer3D = _pool3d[_i3]
	_i3 = (_i3 + 1) % _pool3d.size()
	p.stream = sounds[sound]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func start_music() -> void:
	if not music_player.playing:
		music_player.play()


func start_ambience() -> void:
	_ambience = true
	start_music()
	if not wind_player.playing:
		wind_player.play()
	if not cricket_player.playing:
		cricket_player.play()
	if not breath_player.playing:
		breath_player.play()


func stop_ambience() -> void:
	_ambience = false
	wind_player.stop()
	cricket_player.stop()
	breath_player.stop()
	_breath_target = 0.0


func set_breath(v: float) -> void:
	_breath_target = clampf(v, 0.0, 1.0)


func _process(delta: float) -> void:
	if not _ambience:
		return
	_breath_cur = lerpf(_breath_cur, _breath_target, 1.0 - exp(-3.0 * delta))
	breath_player.volume_db = linear_to_db(maxf(_breath_cur * 0.6, 0.0001))
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = randf_range(9.0, 20.0)
		var pick := ["crow", "crow", "owl"]
		var s: String = pick[randi() % 3]
		var pl: Node3D = GameState.player
		if pl != null:
			var ang := randf() * TAU
			play3d(s, pl.global_position + Vector3(cos(ang) * 30.0, 8.0, sin(ang) * 30.0), 0.0, randf_range(0.85, 1.15))
		else:
			play(s, -8.0)


# ------------------------------------------------------------- synthesis

func _saw(ph: float) -> float:
	return 2.0 * fposmod(ph, 1.0) - 1.0


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _synth(dur: float, fn: Callable, rate: int = RATE, lp: float = 0.0, loop: bool = false, gain: float = 0.9) -> AudioStreamWAV:
	var n := int(dur * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / rate
		var v: float = fn.call(t, dur)
		if lp > 0.0:
			v = prev * lp + v * (1.0 - lp)
			prev = v
		s[i] = v
	var out_n := n
	if loop:
		var cf := int(0.08 * rate)
		for k in cf:
			var a := float(k) / cf
			s[k] = s[k] * a + s[n - cf + k] * (1.0 - a)
		out_n = n - cf
	var bytes := PackedByteArray()
	bytes.resize(out_n * 2)
	for i in out_n:
		bytes.encode_s16(i * 2, int(clampf(s[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = out_n
	return w


func _generate_all() -> void:
	sounds["pistol"] = _synth(0.4, _s_pistol, RATE, 0.35)
	sounds["mg"] = _synth(0.22, _s_mg, RATE, 0.4)
	sounds["chainsaw_idle"] = _synth(1.0, _s_saw_idle, RATE, 0.6, true, 0.7)
	sounds["chainsaw_rev"] = _synth(1.0, _s_saw_rev, RATE, 0.45, true, 0.7)
	sounds["explosion"] = _synth(1.8, _s_explosion, RATE, 0.88, false, 1.4)
	sounds["flash_ring"] = _synth(3.0, _s_flash_ring, RATE, 0.0, false, 0.5)
	sounds["step"] = _synth(0.12, _s_step, RATE, 0.85, false, 0.8)
	sounds["groan_1"] = _synth(1.3, _s_groan.bind(75.0), RATE, 0.82, false, 0.9)
	sounds["groan_2"] = _synth(1.5, _s_groan.bind(60.0), RATE, 0.85, false, 0.9)
	sounds["groan_3"] = _synth(1.0, _s_groan.bind(95.0), RATE, 0.8, false, 0.9)
	sounds["zombie_hit"] = _synth(0.22, _s_wet, RATE, 0.7)
	sounds["zombie_death"] = _synth(1.2, _s_death_groan, RATE, 0.82, false, 0.9)
	sounds["zombie_attack"] = _synth(0.5, _s_attack, RATE, 0.75)
	sounds["headshot"] = _synth(0.3, _s_headshot, RATE, 0.3)
	sounds["boss_roar"] = _synth(2.2, _s_roar, RATE, 0.8, false, 1.1)
	sounds["stomp"] = _synth(0.5, _s_stomp, RATE, 0.9, false, 1.3)
	sounds["coin"] = _synth(0.3, _s_coin, RATE, 0.0, false, 0.5)
	sounds["pickup"] = _synth(0.3, _s_pickup, RATE, 0.3, false, 0.6)
	sounds["click"] = _synth(0.05, _s_click, RATE, 0.0, false, 0.5)
	sounds["empty"] = _synth(0.07, _s_empty, RATE, 0.0, false, 0.6)
	sounds["reload_a"] = _synth(0.12, _s_reload, RATE, 0.0, false, 0.6)
	sounds["throw"] = _synth(0.3, _s_whoosh, RATE, 0.6, false, 0.7)
	sounds["casing"] = _synth(0.15, _s_casing, RATE, 0.0, false, 0.4)
	sounds["sting"] = _synth(1.8, _s_sting, RATE, 0.5, false, 0.9)
	sounds["hurt"] = _synth(0.35, _s_hurt, RATE, 0.6, false, 0.8)
	sounds["death"] = _synth(1.6, _s_player_death, RATE, 0.8, false, 0.9)
	sounds["crow"] = _synth(0.7, _s_crow, RATE, 0.4, false, 0.6)
	sounds["owl"] = _synth(1.4, _s_owl, RATE, 0.0, false, 0.5)
	sounds["breath"] = _synth(3.0, _s_breath, 11025, 0.9, true, 2.0)
	sounds["wind"] = _synth(4.0, _s_wind, 11025, 0.96, true, 2.5)
	sounds["crickets"] = _synth(2.0, _s_crickets, 11025, 0.0, true, 0.5)
	sounds["music"] = _synth(16.0, _s_music, 11025, 0.2, true, 0.8)


func _s_pistol(t: float, d: float) -> float:
	return (_noise() * exp(-t * 32.0) + sin(TAU * (160.0 - 90.0 * minf(t * 8.0, 1.0)) * t) * exp(-t * 16.0)) * 0.9


func _s_mg(t: float, d: float) -> float:
	return (_noise() * exp(-t * 55.0) + sin(TAU * 130.0 * t) * exp(-t * 28.0)) * 0.9


func _s_saw_idle(t: float, d: float) -> float:
	return (0.6 * _saw(62.0 * t) + 0.25 * _noise()) * (0.6 + 0.4 * sin(TAU * 31.0 * t))


func _s_saw_rev(t: float, d: float) -> float:
	return (0.55 * _saw(150.0 * t) + 0.3 * _noise() + 0.2 * _saw(75.0 * t)) * (0.7 + 0.3 * sin(TAU * 60.0 * t))


func _s_explosion(t: float, d: float) -> float:
	return (_noise() * exp(-t * 2.2) + sin(TAU * (60.0 - 20.0 * t) * t) * exp(-t * 3.0) * 1.2) * minf(t * 80.0, 1.0)


func _s_flash_ring(t: float, d: float) -> float:
	var bang := _noise() * exp(-t * 30.0)
	return bang + sin(TAU * 3300.0 * t) * exp(-t * 1.1) * 0.35 * minf(t * 40.0, 1.0)


func _s_step(t: float, d: float) -> float:
	return _noise() * exp(-t * 30.0)


func _s_groan(t: float, d: float, base: float) -> float:
	var env := minf(t / 0.2, 1.0) * (1.0 - t / d)
	var f := base * (1.0 + 0.1 * sin(TAU * 5.0 * t)) * (1.0 - 0.25 * t / d)
	return (0.7 * _saw(f * t) + 0.3 * _saw(f * 2.01 * t) + 0.25 * _noise()) * env


func _s_wet(t: float, d: float) -> float:
	return (_noise() * 0.6 + sin(TAU * 110.0 * t)) * exp(-t * 22.0)


func _s_death_groan(t: float, d: float) -> float:
	var env := minf(t / 0.1, 1.0) * (1.0 - t / d)
	var f := 110.0 * (1.0 - 0.7 * t / d)
	return (0.8 * _saw(f * t) + 0.3 * _noise()) * env


func _s_attack(t: float, d: float) -> float:
	var env := sin(PI * t / d)
	return (0.6 * _saw((120.0 + 60.0 * t) * t) + 0.5 * _noise()) * env


func _s_headshot(t: float, d: float) -> float:
	return (sin(TAU * 900.0 * t) * 0.4 + _noise() * 0.6) * exp(-t * 28.0)


func _s_roar(t: float, d: float) -> float:
	var env := sin(PI * minf(t / d, 1.0)) ** 0.5
	var f := 48.0 + 18.0 * sin(TAU * 2.0 * t)
	return (0.7 * _saw(f * t) + 0.5 * _saw(f * 1.5 * t) + 0.4 * _noise()) * env


func _s_stomp(t: float, d: float) -> float:
	return (sin(TAU * (70.0 - 40.0 * t) * t) + _noise() * 0.3) * exp(-t * 9.0)


func _s_coin(t: float, d: float) -> float:
	var f := 1320.0 if t < 0.08 else 1760.0
	return sin(TAU * f * t) * exp(-t * 9.0)


func _s_pickup(t: float, d: float) -> float:
	var f := 330.0 if t < 0.1 else 495.0
	return (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * exp(-t * 7.0)


func _s_click(t: float, d: float) -> float:
	return sin(TAU * 1000.0 * t) * (1.0 - t / d)


func _s_empty(t: float, d: float) -> float:
	return (sin(TAU * 600.0 * t) * 0.6 + _noise() * 0.4) * exp(-t * 60.0)


func _s_reload(t: float, d: float) -> float:
	return (sin(TAU * 1800.0 * t) * 0.5 + _noise() * 0.5) * exp(-t * 70.0)


func _s_whoosh(t: float, d: float) -> float:
	return _noise() * sin(PI * t / d) * 0.7


func _s_casing(t: float, d: float) -> float:
	return sin(TAU * 4200.0 * t) * exp(-t * 40.0) * 0.5


func _s_sting(t: float, d: float) -> float:
	var env := minf(t / 0.3, 1.0) * exp(-t * 1.6)
	return (sin(TAU * 55.0 * t) + sin(TAU * 58.3 * t) + 0.5 * sin(TAU * 77.8 * t)) * env * 0.5 + _noise() * exp(-t * 12.0) * 0.5


func _s_hurt(t: float, d: float) -> float:
	return (_noise() * 0.5 + sin(TAU * (240.0 - 120.0 * t) * t)) * exp(-t * 9.0)


func _s_player_death(t: float, d: float) -> float:
	return (sin(TAU * (160.0 - 120.0 * t / d) * t) * 0.7 + _noise() * 0.3) * (1.0 - t / d)


func _s_crow(t: float, d: float) -> float:
	var gate := 1.0 if int(t * 9.0) % 3 != 2 else 0.2
	return _saw((700.0 - 250.0 * fposmod(t * 3.0, 1.0)) * t) * gate * sin(PI * t / d) * 0.6


func _s_owl(t: float, d: float) -> float:
	var h := 1.0 if (t < 0.45 or (t > 0.65 and t < 1.2)) else 0.0
	return sin(TAU * 380.0 * t) * h * sin(PI * fposmod(t, 0.6) / 0.6) * 0.5


func _s_breath(t: float, d: float) -> float:
	var ph := fposmod(t, 1.5) / 1.5
	return _noise() * sin(PI * ph) * 0.8


func _s_wind(t: float, d: float) -> float:
	return _noise() * (0.55 + 0.45 * sin(TAU * 0.5 * t))


func _s_crickets(t: float, d: float) -> float:
	var gate := 1.0 if fposmod(t * 14.0, 1.0) < 0.35 else 0.0
	return sin(TAU * 4300.0 * t) * gate * 0.4 + sin(TAU * 3900.0 * t) * (1.0 if fposmod(t * 11.0 + 0.4, 1.0) < 0.3 else 0.0) * 0.3


func _s_music(t: float, d: float) -> float:
	# Slow, dark A-minor drone with sparse bell notes. 16 s loop.
	var bell := [0.0, 440.0, 0.0, 0.0, 523.3, 0.0, 0.0, 392.0, 0.0, 0.0, 329.6, 0.0, 0.0, 440.0, 0.0, 0.0]
	var i := int(t) % 16
	var bt := fposmod(t, 1.0)
	var v := sin(TAU * 55.0 * t) * 0.35 + sin(TAU * 82.4 * t) * 0.18 + sin(TAU * 110.0 * t + 0.4 * sin(TAU * 0.2 * t)) * 0.1
	var b: float = bell[i]
	if b > 0.0:
		v += sin(TAU * b * t) * 0.14 * exp(-bt * 2.6)
	return v * (0.8 + 0.2 * sin(TAU * t / 8.0))
