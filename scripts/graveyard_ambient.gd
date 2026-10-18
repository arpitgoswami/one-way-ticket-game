class_name GraveyardAmbient
extends Node3D
## Flickering lanterns and circling crows.

var lights: Array = []
var crows: Array = []
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	for i in lights.size():
		var l: OmniLight3D = lights[i]
		var f := 0.75 + 0.25 * sin(_t * 9.0 + i * 1.7) * sin(_t * 3.1 + i) + randf_range(-0.06, 0.06)
		l.light_energy = 2.2 * f
	for i in crows.size():
		var c: Node3D = crows[i]
		var a := _t * 0.25 + i * 1.1
		c.position = Vector3(cos(a) * (24.0 + i * 2.0), 15.0 + sin(_t * 0.7 + i) * 2.0, sin(a) * (24.0 + i * 2.0))
		c.rotation.y = -a
		c.rotation.z = sin(_t * 9.0 + i) * 0.3
