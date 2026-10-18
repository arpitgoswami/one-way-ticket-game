class_name GameOver
extends CanvasLayer
## Shown when the player dies. The score is saved to the highscores first.


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameState.player_died.connect(_on_died)


func _on_died() -> void:
	GameState.submit_score()
	if GameState.testing:
		return
	await get_tree().create_timer(1.8, true).timeout
	_build()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIKit.panel()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UIKit.label("YOU DIED", 60, UIKit.RED))
	v.add_child(UIKit.label("%s" % GameState.player_name, 24))
	v.add_child(UIKit.label("SCORE  %d" % GameState.score, 34))
	v.add_child(UIKit.label("WAVE REACHED  %d     KILLS  %d" % [GameState.wave, GameState.kills], 20))
	var b1 := UIKit.button("PLAY AGAIN", 320)
	b1.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	v.add_child(b1)
	var b2 := UIKit.button("HIGHSCORES", 320)
	b2.pressed.connect(func() -> void:
		GameState.open_highscores_on_menu = true
		get_tree().paused = false
		AudioManager.stop_ambience()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	v.add_child(b2)
	var b3 := UIKit.button("MAIN MENU", 320)
	b3.pressed.connect(func() -> void:
		get_tree().paused = false
		AudioManager.stop_ambience()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	v.add_child(b3)
	b1.grab_focus()
