extends Control
## Minimal loading screen: black, title, thin red progress bar, one tip.

const TIPS := [
	"Shoot the legs to slow them. Shoot the head to end them.",
	"Standing still draws more of them.",
	"Chainsaws drink diesel.",
	"Every fifth wave, something big climbs out of the ground.",
	"Coins buy health and defense. Press TAB.",
	"A flashbang buys you five quiet seconds.",
]
const TARGET := "res://scenes/game_world.tscn"

var bar: ProgressBar
var _shown := 0.0
var _t := 0.0
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	add_child(v)
	var title := UIKit.label("ONE WAY TICKET", 54, UIKit.WHITE)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", UIKit.DARKRED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	bar = UIKit.bar(UIKit.RED, Vector2(420, 4))
	bar.max_value = 1.0
	bar.value = 0.0
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(bar)
	var tip := UIKit.label(TIPS[randi() % TIPS.size()], 16, Color(1, 1, 1, 0.6), false)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_shown = lerpf(_shown, minf(_t / 1.8, 1.0), 1.0 - exp(-8.0 * delta))
	bar.value = _shown
	if _t > 1.9:
		_done = true
		bar.value = 1.0
		get_tree().change_scene_to_file(TARGET)
