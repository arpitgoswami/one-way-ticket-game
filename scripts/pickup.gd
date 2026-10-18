class_name Pickup
extends Node3D
## A glowing floating pickup. kind: coin | medkit | ammo | diesel | flash | frag

var kind := "coin"
var life := 50.0
var _t := 0.0
var _body: Node3D
var _base_y := 0.7


func _ready() -> void:
	_t = randf() * 6.0
	_body = Node3D.new()
	add_child(_body)
	var glow := Color.WHITE
	match kind:
		"coin":
			var c := Prim.cyl(_body, 0.22, 0.22, 0.05, Color("#ffd24a"), Vector3.ZERO, 0.3, 0.6)
			c.rotation.x = PI * 0.5
			glow = Color("#ffd24a")
		"medkit":
			Prim.box(_body, Vector3(0.5, 0.35, 0.3), Color("#f2f2f2"), Vector3.ZERO, 0.6, 0.3)
			Prim.box(_body, Vector3(0.3, 0.1, 0.32), Color("#d01818"), Vector3.ZERO, 0.6, 0.8)
			Prim.box(_body, Vector3(0.1, 0.3, 0.32), Color("#d01818"), Vector3.ZERO, 0.6, 0.8)
			glow = Color("#ff4040")
		"ammo":
			Prim.box(_body, Vector3(0.5, 0.3, 0.3), Color("#5a6a3a"), Vector3.ZERO, 0.7, 0.2)
			Prim.box(_body, Vector3(0.4, 0.06, 0.32), Color("#e8c84a"), Vector3(0, 0.0, 0), 0.5, 0.8)
			glow = Color("#e8c84a")
		"diesel":
			Prim.box(_body, Vector3(0.3, 0.42, 0.18), Color("#c9301c"), Vector3.ZERO, 0.5, 0.4)
			Prim.cyl(_body, 0.04, 0.04, 0.12, Color("#222222"), Vector3(0.08, 0.26, 0), 0.5)
			glow = Color("#ff5a2a")
		"flash":
			Prim.cyl(_body, 0.08, 0.08, 0.28, Color("#e8e8e8"), Vector3.ZERO, 0.4, 0.6)
			glow = Color("#ffffff")
		_:
			Prim.sphere(_body, 0.14, Color("#4a5a3a"), Vector3.ZERO, 1.2, 0.3)
			Prim.cyl(_body, 0.04, 0.04, 0.08, Color("#aaaaaa"), Vector3(0, 0.18, 0), 0.4)
			glow = Color("#ff7a3a")
	var l := OmniLight3D.new()
	l.light_color = glow
	l.light_energy = 1.0
	l.omni_range = 3.5
	add_child(l)
	var ring := Prim.cyl(self, 0.45, 0.45, 0.02, Color(glow.r, glow.g, glow.b, 0.5), Vector3(0, 0.05, 0), 1.0, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.position.y = _base_y


func _process(delta: float) -> void:
	_t += delta
	life -= delta
	_body.position.y = _base_y + sin(_t * 2.2) * 0.1
	_body.rotation.y += delta * 1.6
	if life < 6.0:
		visible = int(life * 5.0) % 2 == 0
	if life <= 0.0:
		queue_free()
