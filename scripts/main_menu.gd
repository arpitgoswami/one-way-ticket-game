extends Node3D
## Main menu over a live graveyard-at-dusk backdrop (or menu_bg.jpg if you supply one).

var cam: Camera3D
var amb: GraveyardAmbient
var menu_box: VBoxContainer
var panels: Dictionary = {}
var name_edit: LineEdit
var hs_label: Label
var _t := 0.0


func _ready() -> void:
	GameState.reset_run()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	amb = GraveyardBuilder.build(self)
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.current = true
	_build_ui()
	AudioManager.stop_ambience()
	AudioManager.start_music()
	AudioManager.wind_player.play()
	if GameState.open_highscores_on_menu:
		GameState.open_highscores_on_menu = false
		_show("highscores")


func _process(delta: float) -> void:
	_t += delta
	var a := _t * 0.05
	cam.position = Vector3(sin(a) * 9.0, 1.7 + sin(_t * 0.3) * 0.15, 14.0 + cos(a) * 3.0)
	cam.look_at(Vector3(sin(a * 0.7) * 6.0 - 3.0, 2.2, -28.0), Vector3.UP)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	if FileAccess.file_exists("res://assets/menu_bg.jpg"):
		var img := Image.load_from_file("res://assets/menu_bg.jpg")
		if img != null:
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			ui.add_child(tr)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 70)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	ui.add_child(left)
	var title := UIKit.label("ONE WAY\nTICKET", 92, UIKit.WHITE)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_constant_override("line_spacing", -14)
	title.add_theme_color_override("font_outline_color", UIKit.DARKRED)
	left.add_child(title)
	left.add_child(Control.new())
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 6)
	left.add_child(menu_box)
	var first: Button = null
	var entries := [["1.  START GAME", "start"], ["2.  HIGHSCORES", "highscores"], ["3.  OPTIONS", "options"], ["4.  CREDITS", "credits"], ["5.  EXIT GAME", "exit"]]
	for e in entries:
		var b := UIKit.button(e[0], 340)
		var key: String = e[1]
		b.pressed.connect(func() -> void:
			AudioManager.play("click")
			_show(key))
		menu_box.add_child(b)
		if first == null:
			first = b
	first.grab_focus()

	panels["start"] = _sub(_name_panel())
	panels["highscores"] = _sub(_hs_panel())
	panels["options"] = _sub(UIKit.settings_panel())
	panels["credits"] = _sub(_credits_panel())
	panels["exit"] = _exit_panel()
	for k in panels:
		left.add_child(panels[k])
		panels[k].visible = false


func _sub(content: Control) -> Control:
	var pc := UIKit.panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	v.add_child(content)
	var back := UIKit.button("BACK", 200)
	back.pressed.connect(func() -> void: _show(""))
	v.add_child(back)
	return pc


func _name_panel() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UIKit.label("ENTER YOUR NAME", 28, UIKit.RED))
	name_edit = LineEdit.new()
	name_edit.max_length = 12
	name_edit.placeholder_text = "NAME"
	name_edit.custom_minimum_size = Vector2(320, 44)
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.add_theme_stylebox_override("normal", UIKit.style(Color(0, 0, 0, 0.8), UIKit.WHITE, 0, 2))
	name_edit.add_theme_stylebox_override("focus", UIKit.style(Color(0, 0, 0, 0.8), UIKit.RED, 0, 2))
	name_edit.add_theme_color_override("font_color", UIKit.WHITE)
	name_edit.text_submitted.connect(func(_t: String) -> void: _start_game())
	v.add_child(name_edit)
	var go := UIKit.button("DESCEND", 320)
	go.pressed.connect(_start_game)
	v.add_child(go)
	return v


func _start_game() -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		name_edit.placeholder_text = "NAME REQUIRED"
		name_edit.grab_focus()
		AudioManager.play("empty")
		return
	GameState.player_name = n.to_upper()
	AudioManager.play("click")
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")


func _hs_panel() -> Control:
	var v := VBoxContainer.new()
	v.add_child(UIKit.label("HIGHSCORES", 30, UIKit.RED))
	hs_label = UIKit.label("", 20)
	v.add_child(hs_label)
	return v


func _refresh_highscores() -> void:
	var s := ""
	if GameState.highscores.is_empty():
		s = "No survivors yet."
	else:
		s = "%-3s %-13s %8s   %s\n" % ["#", "NAME", "SCORE", "WAVE"]
		var i := 1
		for h in GameState.highscores:
			s += "%-3d %-13s %8d   %d\n" % [i, str(h["name"]), int(h["score"]), int(h["wave"])]
			i += 1
	hs_label.text = s
	hs_label.add_theme_font_override("font", _mono())


func _mono() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
	return f


func _credits_panel() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(UIKit.label("Game Design and Idea: ARPIT GOSWAMI", 26))
	v.add_child(UIKit.label("Everything else: CLAUDE SONNET 5.5", 26))
	return v


func _exit_panel() -> Control:
	var pc := UIKit.panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	v.add_child(UIKit.label("LEAVE THE GRAVEYARD?", 28, UIKit.RED))
	var yes := UIKit.button("YES, EXIT", 300)
	yes.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(yes)
	var no := UIKit.button("NO", 300)
	no.pressed.connect(func() -> void: _show(""))
	v.add_child(no)
	return pc


func _show(which: String) -> void:
	menu_box.visible = which == ""
	for k in panels:
		panels[k].visible = k == which
	match which:
		"":
			(menu_box.get_child(0) as Button).grab_focus()
		"start":
			name_edit.grab_focus()
		"highscores":
			_refresh_highscores()
		"exit":
			(panels["exit"].get_child(0).get_child(2) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not menu_box.visible:
		_show("")
