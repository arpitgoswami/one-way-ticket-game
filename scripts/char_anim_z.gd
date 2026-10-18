class_name CharAnimZ
extends RefCounted
## Procedural zombie animation. Positive X rotation swings a limb forward; torso negative X = lean forward.


static func pose(z: Zombie, state: String, delta: float, spd: float = 0.0) -> void:
	var L: Dictionary = z.limbs
	var aL := 1.2
	var aR := 1.35
	var lL := 0.0
	var lR := 0.0
	var tx := -0.1
	var hz := 0.0
	var hx := 0.0
	var model_rx := 0.0
	var y := 0.0
	var fast := 14.0
	var ph := z._t * (3.0 + spd * 2.2)
	match state:
		"walk":
			var s := sin(ph)
			var slow := z.speed_mult()
			lL = s * 0.55 * slow + 0.12
			lR = -s * 0.55 * slow
			aL = 1.3 + sin(ph * 0.5) * 0.12
			aR = 1.45 - sin(ph * 0.5) * 0.12
			tx = -0.2
			hz = sin(ph * 0.5) * 0.15
			y = absf(cos(ph)) * 0.04
			if z.leg_hits > 0:
				tx = -0.3
				lL *= 0.6
		"crawl":
			var s2 := sin(ph * 0.8)
			aL = 2.2 + s2 * 0.5
			aR = 2.2 - s2 * 0.5
			lL = 0.2
			lR = -0.2
			tx = -1.2
			hx = 0.9
			y = -0.45
			model_rx = 0.0
		"stand":
			aL = 0.4
			aR = 0.4
			tx = 0.1
			hz = sin(z._t * 3.0) * 0.1
		"windup":
			aL = 2.7
			aR = 2.7
			tx = 0.35
			hx = -0.25
			fast = 22.0
		"strike":
			aL = 0.7
			aR = 0.7
			tx = -0.65
			hx = 0.3
			fast = 30.0
		"stun":
			aL = 0.4 + sin(z._t * 8.0) * 0.5
			aR = 0.4 - sin(z._t * 8.0) * 0.5
			hz = sin(z._t * 10.0) * 0.4
			hx = 0.3
			tx = 0.2
	var k := 1.0 - exp(-fast * delta)
	L["armL"].rotation.x = lerp_angle(L["armL"].rotation.x, aL, k)
	L["armR"].rotation.x = lerp_angle(L["armR"].rotation.x, aR, k)
	L["legL"].rotation.x = lerp_angle(L["legL"].rotation.x, lL, k)
	L["legR"].rotation.x = lerp_angle(L["legR"].rotation.x, lR, k)
	L["torso"].rotation.x = lerp_angle(L["torso"].rotation.x, tx, k)
	L["head"].rotation.z = lerp_angle(L["head"].rotation.z, hz, k)
	L["head"].rotation.x = lerp_angle(L["head"].rotation.x, hx, k)
	if z.state != Zombie.S.RISING:
		z.model.position.y = lerpf(z.model.position.y, y, k)
