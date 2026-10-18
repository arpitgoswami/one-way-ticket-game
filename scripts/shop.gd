class_name Shop
extends CanvasLayer
## Coin shop (Tab). Pauses the game while open.

var player: Player
var items := {
	"heal": {"label": "HEAL +50 HP", "base": 12, "bought": 0},
	"maxhp": {"label": "MAX HEALTH +20", "base": 30, "bought": 0},
	"armor": {"label": "DEFENSE +50", "base": 20, "bought": 0},
	"armorcap": {"label": "DEFENSE CAPACITY +25", "base": 35, "bought": 0},
}
var _buttons: Dictionary = {}
var _coins_lbl: Label
var _root: Control


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := UIKit.panel()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UIKit.label("SHOP", 34, UIKit.RED))
	_coins_lbl = UIKit.label("", 20)
	v.add_child(_coins_lbl)
	for k in items:
		var b := UIKit.button("", 420)
		b.pressed.connect(buy.bind(k))
		v.add_child(b)
		_buttons[k] = b
	var close := UIKit.button("CLOSE  [TAB]", 420)
	close.pressed.connect(close_shop)
	v.add_child(close)
	_refresh()


func price(k: String) -> int:
	return int(round(float(items[k]["base"]) * pow(1.35, float(items[k]["bought"]))))


func _refresh() -> void:
	_coins_lbl.text = "COINS: %d" % GameState.coins
	for k in items:
		(_buttons[k] as Button).text = "%s     %d" % [items[k]["label"], price(k)]
		(_buttons[k] as Button).disabled = GameState.coins < price(k)


func buy(k: String) -> bool:
	var cost := price(k)
	if GameState.coins < cost or player == null:
		AudioManager.play("empty")
		return false
	GameState.coins -= cost
	items[k]["bought"] += 1
	match k:
		"heal":
			player.heal(50.0)
		"maxhp":
			player.max_health += 20.0
			player.heal(20.0)
		"armor":
			player.add_armor(50.0)
		"armorcap":
			player.max_armor += 25.0
			player.add_armor(25.0)
	AudioManager.play("pickup")
	player.emit_health()
	_refresh()
	return true


func open_shop() -> void:
	if GameState.finished:
		return
	visible = true
	_refresh()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_shop() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shop") and not event.is_echo():
		if visible:
			close_shop()
		elif not get_tree().paused:
			open_shop()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("pause"):
		close_shop()
		get_viewport().set_input_as_handled()
