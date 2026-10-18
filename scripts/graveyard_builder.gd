class_name GraveyardBuilder
extends RefCounted
## Spooky evening graveyard: sky, fog, ground, fence, graves, dead trees, lanterns, crypt, crows.


static func make_environment(root: Node3D) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#1a1038")
	sm.sky_horizon_color = Color("#d9632b")
	sm.sky_curve = 0.22
	sm.ground_horizon_color = Color("#6a2e3a")
	sm.ground_bottom_color = Color("#120a1a")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#5a3a4a")
	env.fog_density = 0.022
	env.fog_sky_affect = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-7, 200, 0)
	sun.light_color = Color("#ff8a3d")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	root.add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.light_color = Color("#7f8fe0")
	moon.light_energy = 0.3
	root.add_child(moon)
	# Moon disc in the sky
	var disc := Prim.sphere(root, 7.0, Color("#e9e2c8"), Vector3(-70, 55, 110), 1.0, 1.4)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func build(root: Node3D) -> GraveyardAmbient:
	make_environment(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var props := Node3D.new()
	props.name = "Graveyard"
	root.add_child(props)
	var amb := GraveyardAmbient.new()
	root.add_child(amb)
	var A: float = GameState.AREA

	# Ground
	var ground := StaticBody3D.new()
	ground.collision_layer = GameState.L_WORLD
	ground.collision_mask = 0
	var gcs := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(300, 2, 300)
	gcs.shape = gbs
	gcs.position.y = -1.0
	ground.add_child(gcs)
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	var gm := Prim.part(ground, pm, Color("#3c4228"), Vector3.ZERO, 1.0)
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)
	# dirt path
	var p1 := Prim.box(props, Vector3(3.0, 0.04, A * 2.0), Color("#4a3b2c"), Vector3(0, 0.02, 0), 1.0)
	p1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p2 := Prim.box(props, Vector3(A * 2.0, 0.04, 2.4), Color("#4a3b2c"), Vector3(0, 0.025, 8), 1.0)
	p2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Invisible walls just inside the fence
	var W := A + 1.0
	Prim.static_box(props, Vector3(2, 8, W * 2 + 4), Vector3(-W, 4, 0))
	Prim.static_box(props, Vector3(2, 8, W * 2 + 4), Vector3(W, 4, 0))
	Prim.static_box(props, Vector3(W * 2 + 4, 8, 2), Vector3(0, 4, -W))
	Prim.static_box(props, Vector3(W * 2 + 4, 8, 2), Vector3(0, 4, W))
	_fence(props, A + 0.6, rng)

	# Crypt at the back
	var crypt := Prim.static_box(props, Vector3(10, 5, 7), Vector3(0, 2.5, -A + 5.0), true, Color("#4b4a52"))
	Prim.box(crypt, Vector3(12, 0.6, 9), Color("#3a3940"), Vector3(0, 2.8, 0))
	Prim.box(crypt, Vector3(2.2, 3.4, 0.2), Color("#0c0b0f"), Vector3(0, -0.8, 3.55))
	for sx in [-1, 1]:
		Prim.cyl(crypt, 0.35, 0.4, 4.2, Color("#605f68"), Vector3(sx * 2.2, -0.3, 3.8))

	# Gravestones and crosses
	var placed: Array[Vector3] = [Vector3(0, 0, -A + 5.0)]
	var count := 0
	var guard := 0
	while count < 48 and guard < 600:
		guard += 1
		var p := Vector3(rng.randf_range(-A + 3.0, A - 3.0), 0, rng.randf_range(-A + 3.0, A - 3.0))
		if Vector2(p.x, p.z).length() < 7.0 or absf(p.x) < 2.2 or absf(p.z - 8.0) < 2.0:
			continue
		if p.z < -A + 11.0 and absf(p.x) < 9.0:
			continue
		var ok := true
		for q in placed:
			if Vector2(p.x - q.x, p.z - q.z).length() < 3.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		count += 1
		if rng.randf() < 0.3:
			_cross(props, p, rng)
		else:
			_gravestone(props, p, rng)
		if rng.randf() < 0.5:
			var mound := Prim.box(props, Vector3(1.0, 0.25, 2.0), Color("#2f2a22"), p + Vector3(0, 0.1, 1.3), 1.0)
			mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Dead trees
	var tcount := 0
	guard = 0
	while tcount < 14 and guard < 300:
		guard += 1
		var p := Vector3(rng.randf_range(-A + 2.0, A - 2.0), 0, rng.randf_range(-A + 2.0, A - 2.0))
		if Vector2(p.x, p.z).length() < 9.0 or absf(p.x) < 3.0:
			continue
		var ok := true
		for q in placed:
			if Vector2(p.x - q.x, p.z - q.z).length() < 4.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		tcount += 1
		_dead_tree(props, p, rng)

	# Lanterns
	var lpos := [Vector3(-6, 0, 4), Vector3(6, 0, 4), Vector3(-14, 0, -12), Vector3(14, 0, -12), Vector3(-25, 0, 15), Vector3(25, 0, 15), Vector3(0, 0, -20)]
	for lp in lpos:
		var l := _lantern(props, lp)
		amb.lights.append(l)

	# Crows: some perched, some circling
	for i in 6:
		var c := Node3D.new()
		Prim.sphere(c, 0.18, Color("#0a0a0c"), Vector3.ZERO, 0.7)
		Prim.box(c, Vector3(1.2, 0.04, 0.35), Color("#0a0a0c"), Vector3(0, 0.02, 0))
		props.add_child(c)
		amb.crows.append(c)
	return amb


static func _gravestone(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(1.0, 1.8)
	var w := rng.randf_range(0.7, 1.1)
	var col := Color("#6b6a72").darkened(rng.randf_range(0.0, 0.3))
	var sb := Prim.static_box(parent, Vector3(w, h, 0.3), p + Vector3(0, h * 0.5, 0))
	sb.rotation.y = rng.randf_range(-0.3, 0.3)
	sb.rotation.z = rng.randf_range(-0.14, 0.14)
	sb.rotation.x = rng.randf_range(-0.1, 0.1)
	Prim.box(sb, Vector3(w, h, 0.3), col)
	var top := Prim.cyl(sb, w * 0.5, w * 0.5, 0.3, col, Vector3(0, h * 0.5, 0))
	top.rotation.x = PI * 0.5
	Prim.box(sb, Vector3(w * 0.5, 0.05, 0.05), col.darkened(0.4), Vector3(0, h * 0.2, -0.16))


static func _cross(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(1.5, 2.2)
	var sb := Prim.static_box(parent, Vector3(0.35, h, 0.35), p + Vector3(0, h * 0.5, 0))
	sb.rotation.z = rng.randf_range(-0.2, 0.2)
	sb.rotation.y = rng.randf() * TAU
	var col := Color("#58565e")
	Prim.box(sb, Vector3(0.25, h, 0.25), col)
	Prim.box(sb, Vector3(1.0, 0.25, 0.25), col, Vector3(0, h * 0.25, 0))


static func _dead_tree(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.9, 1.5)
	var sb := StaticBody3D.new()
	sb.collision_layer = GameState.L_WORLD
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.4 * s
	cy.height = 4.0
	cs.shape = cy
	cs.position.y = 2.0
	sb.add_child(cs)
	parent.add_child(sb)
	sb.position = p
	var bark := Color("#2b2320")
	Prim.cyl(sb, 0.18 * s, 0.4 * s, 5.0 * s, bark, Vector3(0, 2.5 * s, 0))
	for i in 5:
		var br := Prim.cyl(sb, 0.04 * s, 0.12 * s, rng.randf_range(1.5, 2.6) * s, bark, Vector3(0, (2.6 + i * 0.45) * s, 0))
		br.rotation = Vector3(rng.randf_range(-0.8, 0.8), rng.randf() * TAU, rng.randf_range(0.7, 1.2))
		br.position += Vector3(sin(br.rotation.y) * 0.5, 0, cos(br.rotation.y) * 0.5) * s


static func _lantern(parent: Node3D, p: Vector3) -> OmniLight3D:
	Prim.cyl(parent, 0.06, 0.08, 2.6, Color("#1a1a1e"), p + Vector3(0, 1.3, 0), 0.5)
	Prim.box(parent, Vector3(0.35, 0.45, 0.35), Color("#ffb347"), p + Vector3(0, 2.7, 0), 0.4, 2.5)
	Prim.box(parent, Vector3(0.5, 0.08, 0.5), Color("#1a1a1e"), p + Vector3(0, 3.0, 0), 0.5)
	var l := OmniLight3D.new()
	l.light_color = Color("#ffa24a")
	l.light_energy = 2.2
	l.omni_range = 14.0
	l.position = p + Vector3(0, 2.7, 0)
	parent.add_child(l)
	return l


static func _fence(parent: Node3D, half: float, rng: RandomNumberGenerator) -> void:
	var col := Color("#18181c")
	var step := 1.4
	var n := int(half * 2.0 / step)
	for side in 4:
		for i in n + 1:
			var t := -half + i * step
			var pos := Vector3.ZERO
			var rot := 0.0
			match side:
				0:
					pos = Vector3(t, 0, -half)
				1:
					pos = Vector3(t, 0, half)
				2:
					pos = Vector3(-half, 0, t)
					rot = PI * 0.5
				_:
					pos = Vector3(half, 0, t)
					rot = PI * 0.5
			if rng.randf() < 0.05:
				continue
			var h := 2.4 + rng.randf_range(-0.1, 0.1)
			var bar := Prim.cyl(parent, 0.04, 0.04, h, col, pos + Vector3(0, h * 0.5, 0), 0.4)
			Prim.cyl(bar, 0.0, 0.07, 0.3, col, Vector3(0, h * 0.5 + 0.1, 0), 0.4)
			bar.rotation.z = rng.randf_range(-0.03, 0.03)
		# horizontal rails
		for hh in [0.6, 1.9]:
			var len := half * 2.0
			var rail: MeshInstance3D
			match side:
				0:
					rail = Prim.box(parent, Vector3(len, 0.08, 0.08), col, Vector3(0, hh, -half))
				1:
					rail = Prim.box(parent, Vector3(len, 0.08, 0.08), col, Vector3(0, hh, half))
				2:
					rail = Prim.box(parent, Vector3(0.08, 0.08, len), col, Vector3(-half, hh, 0))
				_:
					rail = Prim.box(parent, Vector3(0.08, 0.08, len), col, Vector3(half, hh, 0))
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
