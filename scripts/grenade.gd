class_name Grenade
extends RigidBody3D
## Thrown grenade. kind = "frag" (area damage) or "flash" (stuns zombies, blinds the player if close/looking).

var kind := "frag"
var fuse := 2.0
var _light: OmniLight3D
var _blink := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = GameState.L_WORLD
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.1
	cs.shape = ss
	add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.7
	physics_material_override = pm
	var col := Color("#3d4a3a") if kind == "frag" else Color("#cfcfcf")
	Prim.sphere(self, 0.1, col, Vector3.ZERO, 1.2)
	Prim.cyl(self, 0.04, 0.04, 0.06, Color("#a0a0a0"), Vector3(0, 0.12, 0))
	_light = OmniLight3D.new()
	_light.light_color = Color("#ff2a1a") if kind == "frag" else Color("#ffffff")
	_light.light_energy = 0.0
	_light.omni_range = 3.0
	add_child(_light)


func _physics_process(delta: float) -> void:
	fuse -= delta
	_blink += delta * (6.0 + (2.0 - fuse) * 4.0)
	_light.light_energy = 1.5 if sin(_blink) > 0.6 else 0.0
	if fuse <= 0.0:
		_explode()


func _explode() -> void:
	set_physics_process(false)
	var pos := global_position
	var pl: Node3D = GameState.player
	if kind == "frag":
		FX.explosion(pos, 5.0, Color("#ff9a3a"))
		AudioManager.play3d("explosion", pos, 6.0)
		GameState.camera_shake.emit(0.9 * clampf(1.0 - pos.distance_to(pl.global_position) / 25.0, 0.1, 1.0))
		for z in get_tree().get_nodes_in_group("zombies"):
			var d: float = z.global_position.distance_to(pos)
			if d < 8.0:
				var dir: Vector3 = (z.global_position - pos).normalized()
				z.call("take_hit", 260.0 * (1.0 - d / 8.0) + 20.0, "body", dir)
		if pl != null:
			var pd := pl.global_position.distance_to(pos)
			if pd < 6.0:
				pl.call("take_damage", 30.0 * (1.0 - pd / 6.0), pos)
	else:
		FX.explosion(pos, 3.0, Color("#ffffff"))
		AudioManager.play3d("explosion", pos, -4.0, 1.6)
		AudioManager.play3d("flash_ring", pos, 0.0)
		for z in get_tree().get_nodes_in_group("zombies"):
			if z.global_position.distance_to(pos) < 14.0:
				z.call("stun", 5.0)
		if pl != null:
			var pd2 := pl.global_position.distance_to(pos)
			if pd2 < 16.0:
				var cam: Camera3D = pl.get("cam")
				var facing := 1.0
				if cam != null:
					var to_g := (pos - cam.global_position).normalized()
					facing = clampf(-cam.global_transform.basis.z.dot(to_g), 0.0, 1.0)
				GameState.flashbanged.emit(clampf((1.0 - pd2 / 16.0) * (0.3 + 0.7 * facing) * 1.4, 0.0, 1.0))
	queue_free()
