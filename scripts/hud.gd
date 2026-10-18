class_name HUD
extends CanvasLayer
## Minimal red/white/black HUD with a 4-line spreading crosshair.

var waves: WaveManager
var hp_bar: ProgressBar
var armor_bar: ProgressBar
var weapon_lbl: Label
var ammo_lbl: Label
var gren_lbl: Label
var wave_lbl: Label
var remain_lbl: Label
var coins_lbl: Label
var score_lbl: Label
var msg_lbl: Label
var lines: Array = []
var hit_marks: Array = []
var vignette: ColorRect
var flash: ColorRect
var root: Control
var _gap := 6.0
var _blood := 0.0
var _flash := 0.0
var _flash_hold := 0.0
var _msg_t := 0.0
var _hm_t := 0.0
var _hm_color := Color.WHITE


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float intensity = 0.0;\nvoid fragment(){ float d = length(UV - vec2(0.5)) * 1.5; float a = smoothstep(0.35, 1.0, d) * intensity; COLOR = vec4(0.7, 0.0, 0.0, a * 0.85); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vignette = ColorRect.new()
	vignette.material = sm
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	# Bottom-left: health + armor
	var bl := VBoxContainer.new()
	bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_theme_constant_override("separation", 3)
	root.add_child(bl)
	bl.add_child(UIKit.label("HEALTH", 12, UIKit.WHITE, false))
	hp_bar = UIKit.bar(UIKit.RED, Vector2(260, 14))
	bl.add_child(hp_bar)
	bl.add_child(UIKit.label("DEFENSE", 12, UIKit.WHITE, false))
	armor_bar = UIKit.bar(UIKit.WHITE, Vector2(260, 8))
	bl.add_child(armor_bar)

	# Bottom-right: weapon info
	var br := VBoxContainer.new()
	br.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(br)
	weapon_lbl = UIKit.label("PISTOL", 16, UIKit.RED)
	weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(weapon_lbl)
	ammo_lbl = UIKit.label("12 / 36", 40, UIKit.WHITE)
	ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(ammo_lbl)
	gren_lbl = UIKit.label("", 14, UIKit.WHITE, false)
	gren_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(gren_lbl)

	# Top-center: wave
	var tc := VBoxContainer.new()
	tc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 14)
	tc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)
	wave_lbl = UIKit.label("WAVE 1", 26, UIKit.WHITE)
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(wave_lbl)
	remain_lbl = UIKit.label("", 14, UIKit.RED, false)
	remain_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(remain_lbl)

	# Top-right: coins + score
	var tr := VBoxContainer.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	score_lbl = UIKit.label("0", 24, UIKit.WHITE)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(score_lbl)
	coins_lbl = UIKit.label("COINS 0   [TAB] SHOP", 14, UIKit.RED, false)
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(coins_lbl)

	# Center message
	msg_lbl = UIKit.label("", 44, UIKit.WHITE)
	msg_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 110)
	msg_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.modulate.a = 0.0
	root.add_child(msg_lbl)

	# Crosshair: 4 separate lines
	for i in 4:
		var r := ColorRect.new()
		r.color = UIKit.WHITE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(r)
		lines.append(r)
	# Hit marker (4 short diagonal ticks)
	for i in 4:
		var h := ColorRect.new()
		h.color = UIKit.WHITE
		h.size = Vector2(9, 2)
		h.pivot_offset = Vector2(4.5, 1)
		h.rotation = PI * 0.25 + i * PI * 0.5
		h.visible = false
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(h)
		hit_marks.append(h)

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	GameState.wave_started.connect(func(w: int, boss: bool) -> void: show_message("WAVE %d - BOSS" % w if boss else "WAVE %d" % w, UIKit.RED if boss else UIKit.WHITE))
	GameState.message.connect(func(t: String) -> void: show_message(t, UIKit.RED, 28))
	GameState.player_damaged.connect(func(_a: float) -> void: _blood = 1.0)
	GameState.flashbanged.connect(func(i: float) -> void:
		_flash = maxf(_flash, i)
		_flash_hold = 0.8 * i)
	GameState.hit_marker.connect(_on_hit_marker)


func show_message(t: String, color: Color = UIKit.WHITE, size: int = 44) -> void:
	msg_lbl.text = t
	msg_lbl.add_theme_font_size_override("font_size", size)
	msg_lbl.add_theme_color_override("font_color", color)
	_msg_t = 2.6


func _on_hit_marker(head: bool, kill: bool) -> void:
	_hm_t = 0.14
	_hm_color = UIKit.RED if (head or kill) else UIKit.WHITE


func _process(delta: float) -> void:
	var pl: Player = GameState.player
	if pl == null:
		return
	hp_bar.value = pl.health / pl.max_health * 100.0
	armor_bar.value = pl.armor / maxf(pl.max_armor, 1.0) * 100.0
	var w := pl.weapons
	weapon_lbl.text = w.weapon_name()
	ammo_lbl.text = w.ammo_text()
	if w.reloading:
		ammo_lbl.text = "RELOADING"
	gren_lbl.text = "[4] FLASH %d    [5] GRENADE %d" % [w.grenades["flash"], w.grenades["frag"]]
	if waves != null:
		wave_lbl.text = "WAVE %d" % maxi(waves.wave, 1)
		remain_lbl.text = "%d LEFT" % waves.remaining() if waves.state != WaveManager.St.BREAK else "CLEAR"
	score_lbl.text = str(GameState.score)
	coins_lbl.text = "COINS %d   [TAB] SHOP" % GameState.coins
	# message fade
	if _msg_t > 0.0:
		_msg_t -= delta
		msg_lbl.modulate.a = clampf(_msg_t / 0.6, 0.0, 1.0)
	# crosshair
	var c := get_viewport().get_visible_rect().size * 0.5
	var target_gap := 5.0 + pl.speed_ratio * 16.0 + w.shot_kick * 12.0
	_gap = lerpf(_gap, target_gap, 1.0 - exp(-14.0 * delta))
	var len := 9.0
	var th := 2.0
	var dirs := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	for i in 4:
		var r: ColorRect = lines[i]
		var d: Vector2 = dirs[i]
		if i < 2:
			r.size = Vector2(th, len)
			r.position = c + d * (_gap + (len * 0.5 if d.y > 0 else len * 0.5)) - Vector2(th * 0.5, len * 0.5)
		else:
			r.size = Vector2(len, th)
			r.position = c + d * (_gap + len * 0.5) - Vector2(len * 0.5, th * 0.5)
	# hit marker
	_hm_t = maxf(0.0, _hm_t - delta)
	for i in 4:
		var h: ColorRect = hit_marks[i]
		h.visible = _hm_t > 0.0
		h.color = _hm_color
		var off := Vector2(1, 1).rotated(i * PI * 0.5).normalized() * 11.0
		h.position = c + off - Vector2(4.5, 1)
	# blood + low health vignette
	_blood = maxf(0.0, _blood - delta * 1.5)
	var low := clampf(1.0 - pl.health / 35.0, 0.0, 1.0) * 0.6 if pl.health < 35.0 else 0.0
	(vignette.material as ShaderMaterial).set_shader_parameter("intensity", maxf(_blood, low) * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)))
	# flashbang
	if _flash_hold > 0.0:
		_flash_hold -= delta
	else:
		_flash = maxf(0.0, _flash - delta * 0.35)
	flash.color.a = _flash
