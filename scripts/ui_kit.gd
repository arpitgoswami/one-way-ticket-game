class_name UIKit
extends RefCounted
## Red / white / black UI helpers.

const RED := Color("#d01818")
const DARKRED := Color("#5a0a0a")
const WHITE := Color("#f2f2f2")
const BLACK := Color("#0a0a0a")
const PANEL := Color(0.04, 0.04, 0.04, 0.9)


static func style(bg: Color, border: Color = WHITE, radius: int = 2, bw: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func label(text: String, size: int = 20, color: Color = WHITE, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", maxi(3, size / 7))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	return l


static func button(text: String, width: float = 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", style(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.0), 0, 0))
	b.add_theme_stylebox_override("hover", style(RED, RED, 0, 0))
	b.add_theme_stylebox_override("focus", style(RED, WHITE, 0, 2))
	b.add_theme_stylebox_override("pressed", style(DARKRED, WHITE, 0, 0))
	b.add_theme_stylebox_override("disabled", style(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0), 0, 0))
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", WHITE)
	b.add_theme_color_override("font_focus_color", WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	return b


static func bar(fill: Color, size: Vector2 = Vector2(220, 12)) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = size
	p.show_percentage = false
	p.max_value = 100.0
	p.value = 100.0
	var bg := style(Color(0, 0, 0, 0.7), Color(1, 1, 1, 0.5), 0, 1)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fg := style(fill, fill, 0, 0)
	fg.content_margin_top = 0
	fg.content_margin_bottom = 0
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


static func panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style(PANEL, RED, 0, 2))
	return pc


static func settings_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(label("OPTIONS", 30, RED))
	_slider(box, "Mouse sensitivity", 0.2, 3.0, GameState.sensitivity, func(v: float) -> void:
		GameState.sensitivity = v)
	_slider(box, "Field of view", 60.0, 110.0, GameState.fov, func(v: float) -> void:
		GameState.fov = v)
	_slider(box, "Master volume", 0.0, 1.0, GameState.vol_master, func(v: float) -> void:
		GameState.vol_master = v
		AudioManager.apply_volumes())
	_slider(box, "Music volume", 0.0, 1.0, GameState.vol_music, func(v: float) -> void:
		GameState.vol_music = v
		AudioManager.apply_volumes())
	_slider(box, "Effects volume", 0.0, 1.0, GameState.vol_sfx, func(v: float) -> void:
		GameState.vol_sfx = v
		AudioManager.apply_volumes())
	return box


static func _slider(parent: Control, text: String, lo: float, hi: float, val: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var l := label(text, 18)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = val
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float) -> void:
		cb.call(v)
		GameState.save_settings())
	row.add_child(s)
	parent.add_child(row)
