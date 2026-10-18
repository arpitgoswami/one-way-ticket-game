class_name PauseMenu
extends CanvasLayer
## Esc menu: Resume / Options / Quit to Menu.

var shop: Shop
var _main: VBoxContainer
var _opts: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := UIKit.panel()
	center.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 8)
	stack.add_child(_main)
	_main.add_child(UIKit.label("PAUSED", 36, UIKit.RED))
	var b1 := UIKit.button("RESUME")
	b1.pressed.connect(resume)
	_main.add_child(b1)
	var b2 := UIKit.button("OPTIONS")
	b2.pressed.connect(func() -> void:
		_main.visible = false
		_opts.visible = true)
	_main.add_child(b2)
	var b3 := UIKit.button("QUIT TO MENU")
	b3.pressed.connect(func() -> void:
		get_tree().paused = false
		AudioManager.stop_ambience()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_main.add_child(b3)
	_opts = VBoxContainer.new()
	_opts.visible = false
	_opts.add_child(UIKit.settings_panel())
	var back := UIKit.button("BACK")
	back.pressed.connect(func() -> void:
		_opts.visible = false
		_main.visible = true)
	_opts.add_child(back)
	stack.add_child(_opts)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not GameState.finished:
		if visible:
			resume()
		elif not get_tree().paused:
			pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	visible = true
	_main.visible = true
	_opts.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
