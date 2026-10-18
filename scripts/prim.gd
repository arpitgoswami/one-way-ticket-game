class_name Prim
extends RefCounted
## Primitive-mesh helpers with cached materials.

static var _mats: Dictionary = {}


static func mat(c: Color, rough: float = 0.9, emis: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), rough, emis]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3 = Vector3.ZERO, rough: float = 0.9, emis: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, rough, emis)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, c: Color, pos: Vector3 = Vector3.ZERO, rough: float = 0.9, emis: float = 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return part(parent, m, c, pos, rough, emis)


static func sphere(parent: Node3D, r: float, c: Color, pos: Vector3 = Vector3.ZERO, squash: float = 1.0, emis: float = 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * squash
	m.radial_segments = 14
	m.rings = 7
	return part(parent, m, c, pos, 0.9, emis)


static func capsule(parent: Node3D, r: float, h: float, c: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 4
	return part(parent, m, c, pos)


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, c: Color, pos: Vector3 = Vector3.ZERO, rough: float = 0.9, emis: float = 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = 12
	return part(parent, m, c, pos, rough, emis)


static func static_box(parent: Node3D, size: Vector3, pos: Vector3, visible_mesh: bool = false, c: Color = Color.GRAY) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = GameState.L_WORLD
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	parent.add_child(sb)
	sb.position = pos
	if visible_mesh:
		box(sb, size, c)
	return sb
