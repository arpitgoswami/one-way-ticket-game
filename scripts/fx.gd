class_name FX
extends RefCounted
## Small particle / flash effects.


static func _pmat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func burst(pos: Vector3, color: Color, amount: int = 12, speed: float = 4.0, size: float = 0.08, life: float = 0.5, spread: float = 180.0, up: Vector3 = Vector3.UP, gravity: float = -8.0) -> void:
	var w: Node3D = GameState.world
	if w == null or not w.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = _pmat()
	p.mesh = m
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = up
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.color = color
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	w.add_child(p)
	p.global_position = pos
	p.emitting = true
	w.get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


static func blood(pos: Vector3, dir: Vector3, big: bool = false) -> void:
	burst(pos, Color(0.55, 0.02, 0.02, 1), 18 if big else 8, 4.0 if big else 2.5, 0.06, 0.6, 50.0, -dir + Vector3.UP * 0.3)


static func spark(pos: Vector3, normal: Vector3) -> void:
	burst(pos, Color(1.0, 0.8, 0.4, 1), 5, 3.0, 0.03, 0.25, 40.0, normal, -4.0)


static func dust(pos: Vector3, amount: int = 8, size: float = 0.2) -> void:
	burst(pos, Color(0.45, 0.4, 0.35, 0.6), amount, 1.8, size, 0.9, 70.0, Vector3.UP, 0.3)


static func tracer(from: Vector3, to: Vector3) -> void:
	var w: Node3D = GameState.world
	if w == null or not w.is_inside_tree():
		return
	var len := from.distance_to(to)
	if len < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, minf(len, 3.0))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	var dir := (to - from).normalized()
	mi.global_position = from + dir * (minf(len, 3.0) * 0.5 + 0.5)
	mi.look_at(to, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.08)
	tw.tween_callback(mi.queue_free)


static func explosion(pos: Vector3, radius: float, color: Color) -> void:
	var w: Node3D = GameState.world
	if w == null or not w.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	mi.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 6.0
	l.omni_range = radius * 2.0
	mi.add_child(l)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.35)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_property(l, "light_energy", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)
	burst(pos, Color(0.2, 0.2, 0.2, 0.8), 20, 5.0, 0.35, 1.5, 180.0, Vector3.UP, 0.8)
