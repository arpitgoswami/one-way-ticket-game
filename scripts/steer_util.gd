class_name SteerUtil
extends RefCounted
## Raycast obstacle avoidance against the world layer (gravestones, trees, crypt).

const MASK := 1


static func free_dir(body: Node3D, dir: Vector3, bias: float = 1.0, look: float = 2.2) -> Vector3:
	if dir.length_squared() < 0.0001:
		return dir
	var space := body.get_world_3d().direct_space_state
	var from := body.global_position + Vector3(0, 0.6, 0)
	var angles := [0.0, 0.55 * bias, -0.55 * bias, 1.1 * bias, -1.1 * bias, 1.7 * bias, -1.7 * bias]
	for a in angles:
		var d: Vector3 = dir.rotated(Vector3.UP, float(a))
		var q := PhysicsRayQueryParameters3D.create(from, from + d * look, MASK)
		if space.intersect_ray(q).is_empty():
			return d
	return dir.rotated(Vector3.UP, PI * 0.5 * bias)
