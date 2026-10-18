extends Node
## Headless smoke test: godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn

var fails := 0
var world: Node


func check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		fails += 1


func wait(sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().physics_frame


func zombies() -> Array:
	return get_tree().get_nodes_in_group("zombies")


func kill_all() -> void:
	for z in zombies():
		z.take_hit(99999.0, "head", Vector3.FORWARD)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.testing = true
	GameState.player_name = "TESTER"
	# menu loads
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await wait(0.5)
	check(menu.menu_box.get_child_count() == 5, "main menu has 5 options")
	menu._show("highscores")
	menu._show("credits")
	menu._show("options")
	menu._show("exit")
	menu._show("")
	menu.queue_free()
	await wait(0.2)

	world = load("res://scenes/game_world.tscn").instantiate()
	add_child(world)
	await wait(0.5)
	var pl: Player = GameState.player
	var wm: WaveManager = world.waves
	check(pl != null and wm != null, "world assembled")
	pl.invincible = true

	# movement
	var z0 := pl.global_position.z
	Input.action_press("move_forward")
	await wait(1.0)
	check(pl.global_position.z < z0 - 2.0, "player walks (dz=%.1f)" % (pl.global_position.z - z0))
	Input.action_press("sprint")
	await wait(0.8)
	var v := Vector3(pl.velocity.x, 0, pl.velocity.z).length()
	check(v > 6.5, "player sprints (%.1f m/s)" % v)
	check(pl.speed_ratio > 0.8, "speed_ratio drives crosshair spread (%.2f)" % pl.speed_ratio)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await wait(1.0)
	check(pl.speed_ratio < 0.1, "crosshair closes when standing still")
	pl.global_position = Vector3(0, 0.1, 12)
	pl.still_time = 0.0

	# wave 1
	wm._camp_cd = 999.0
	await wait(4.5)
	check(wm.wave == 1, "wave 1 started")
	var n := wm.remaining()
	check(n >= 2 and n <= 3, "wave 1 has 2-3 zombies (%d)" % n)
	await wait(4.0)
	var z: Zombie = zombies()[0]
	check(z.max_hp == 60.0, "wave 1 HP = 60")

	# hit zones via real raycast: stand a zombie in front of the player
	await wait(1.5)
	kill_all()
	await wait(0.3)
	var tz := Zombie.new()
	tz.setup(1, false)
	world.add_child(tz)
	tz.global_position = Vector3(0, 0, 4)
	tz.state = Zombie.S.STUNNED
	tz._stun = 100.0
	tz._rise = 1.0
	await wait(0.2)
	pl.global_position = Vector3(0, 0.1, 12)
	pl.yaw = 0.0
	pl.pitch = 0.0
	await wait(0.1)
	# aim at the head (y ~ 1.5)
	var head_pos := tz.global_position + Vector3(0, 2.14 * tz.model_scale, 0)
	var from := pl.cam.global_position
	var dir := (head_pos - from).normalized()
	pl.pitch = asin(dir.y)
	await wait(0.2)
	tz.hp = 1000.0
	tz.max_hp = 1000.0
	var hp0 := tz.hp
	pl.weapons._hitscan(0.0, 30.0, pl.weapons._muzzles["pistol"])
	check(hp0 - tz.hp >= 100.0, "headshot deals big damage (%.0f)" % (hp0 - tz.hp))
	var leg_pos := tz.global_position + Vector3(0, 0.45 * tz.model_scale, 0)
	pl.pitch = asin((leg_pos - from).normalized().y)
	await wait(0.2)
	hp0 = tz.hp
	var lh0 := tz.leg_hits
	pl.weapons._hitscan(0.0, 30.0, pl.weapons._muzzles["pistol"])
	check(tz.leg_hits == lh0 + 1 and tz.speed_mult() < 1.0, "leg shot slows zombie (mult %.2f)" % tz.speed_mult())
	check(hp0 - tz.hp <= 31.0 and hp0 - tz.hp > 0.0, "leg shot is normal damage")
	tz.queue_free()
	await wait(0.2)

	# weapons
	pl.weapons.equip("mg")
	await wait(0.6)
	check(pl.weapons.current == "mg", "switch to machine gun")
	var mag0: int = pl.weapons.ammo["mg"]["mag"]
	Input.action_press("fire")
	await wait(0.5)
	Input.action_release("fire")
	check(pl.weapons.ammo["mg"]["mag"] < mag0 - 3, "machine gun fires automatically (%d -> %d)" % [mag0, pl.weapons.ammo["mg"]["mag"]])
	Input.action_press("reload")
	await wait(0.1)
	Input.action_release("reload")
	await wait(2.4)
	check(pl.weapons.ammo["mg"]["mag"] == 30, "reload refills the magazine")
	pl.weapons.equip("chainsaw")
	await wait(0.6)
	var d0: float = pl.weapons.diesel
	Input.action_press("fire")
	await wait(1.0)
	Input.action_release("fire")
	check(pl.weapons.diesel < d0 - 3.0, "chainsaw burns diesel (%.0f -> %.0f)" % [d0, pl.weapons.diesel])
	pl.weapons.diesel = 0.0
	Input.action_press("fire")
	await wait(0.5)
	Input.action_release("fire")
	check(not pl.weapons._saw_rev.playing, "chainsaw stops without diesel")
	pl.weapons.equip("pistol")
	await wait(0.6)
	# scroll wheel
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	pl.weapons._unhandled_input(ev)
	await wait(0.6)
	check(pl.weapons.current == "chainsaw", "mouse wheel changes weapon")

	# grenades
	pl.weapons.equip("pistol")
	await wait(0.6)
	var gz := Zombie.new()
	gz.setup(1, false)
	world.add_child(gz)
	gz.global_position = Vector3(3, 0, 3)
	gz._rise = 1.0
	gz.state = Zombie.S.CHASE
	pl.global_position = Vector3(3, 0.1, 15)
	await wait(0.2)
	var fg := Grenade.new()
	fg.kind = "flash"
	fg.fuse = 0.3
	world.add_child(fg)
	fg.global_position = Vector3(3, 1, 4)
	await wait(0.6)
	check(gz.state == Zombie.S.STUNNED, "flashbang stuns zombies")
	var gh: float = gz.hp
	var eg := Grenade.new()
	eg.kind = "frag"
	eg.fuse = 0.3
	world.add_child(eg)
	eg.global_position = Vector3(3, 0.5, 3.5)
	await wait(0.6)
	check(gz.is_dead() or gz.hp < gh, "explosive grenade damages zombies")
	kill_all()

	# pickups
	var sp: PickupSpawner = world.get_node("Pickups")
	var c0 := GameState.coins
	sp.spawn_at("coin", pl.global_position)
	await wait(0.3)
	check(GameState.coins == c0 + 1, "coin pickup collected")
	pl.health = 50.0
	sp.spawn_at("medkit", pl.global_position)
	await wait(0.3)
	check(pl.health >= 84.0, "medkit heals (%.0f)" % pl.health)
	var res0: int = pl.weapons.ammo["pistol"]["res"]
	sp.spawn_at("ammo", pl.global_position)
	await wait(0.3)
	check(pl.weapons.ammo["pistol"]["res"] > res0, "ammo pack collected")
	var df0: float = pl.weapons.diesel
	sp.spawn_at("diesel", pl.global_position)
	await wait(0.3)
	check(pl.weapons.diesel > df0, "diesel pack collected")
	sp.spawn_at("frag", pl.global_position)
	await wait(0.3)
	check(pl.weapons.grenades["frag"] >= 1, "grenade pickup collected")

	# shop
	var shop: Shop = null
	for ch in world.get_children():
		if ch is Shop:
			shop = ch
	GameState.coins = 100
	var mh0 := pl.max_health
	check(shop.buy("maxhp") and pl.max_health == mh0 + 20.0, "shop: max health upgrade")
	var a0 := pl.armor
	check(shop.buy("armor") and pl.armor > a0, "shop: defense upgrade")
	GameState.coins = 0
	check(not shop.buy("heal"), "shop refuses when too poor")

	# wave progression, camp spawn, boss wave
	kill_all()
	await wait(0.5)
	wm.queue.clear()
	await wait(1.0)
	check(wm.state == WaveManager.St.BREAK or wm.wave >= 2, "wave clears and break starts")
	await wait(8.0)
	check(wm.wave >= 2, "wave 2 begins (wave=%d)" % wm.wave)
	await wait(6.0)
	var alive0 := zombies().size()
	pl.global_position = Vector3(0, 0.1, 12)
	pl.still_time = 3.0
	wm._camp_cd = 0.0
	await wait(0.5)
	check(zombies().size() >= alive0 + 2 or wm.alive_count() >= alive0 + 2, "standing still spawns 2-3 more zombies (%d -> %d)" % [alive0, zombies().size()])
	var z2: Zombie = zombies()[0]
	check(z2.max_hp > 60.0, "HP grows with waves (%.0f)" % z2.max_hp)
	kill_all()
	wm.queue.clear()
	wm.wave = 4
	wm._timer = 0.1
	wm.state = WaveManager.St.BREAK
	await wait(1.0)
	check(wm.wave == 5, "wave 5 reached")
	await wait(6.0)
	var bosses := 0
	for zz in zombies():
		if zz.is_boss:
			bosses += 1
	check(bosses == 1 and zombies().size() == 3, "boss wave: 1 boss + 2 zombies (%d zombies)" % zombies().size())
	for zz in zombies():
		if zz.is_boss:
			check(zz.max_hp > 800.0, "boss has much more HP (%.0f)" % zz.max_hp)
	kill_all()

	# zombie attacks player
	pl.invincible = false
	pl.health = pl.max_health
	var az := Zombie.new()
	az.setup(3, false)
	world.add_child(az)
	az.global_position = pl.global_position + Vector3(0, 0, -2.5)
	az._rise = 1.0
	az.state = Zombie.S.CHASE
	await wait(3.5)
	check(pl.health < pl.max_health, "zombies attack the player (hp %.0f)" % pl.health)
	kill_all()

	# death -> highscore
	var hs0 := GameState.highscores.size()
	GameState.score = 1234
	pl._invuln = 0.0
	pl.take_damage(100000.0)
	await wait(0.5)
	check(not pl.alive and GameState.finished, "player dies")
	check(GameState.highscores.size() == hs0 + 1 and GameState.highscores[GameState.highscores.size() - 1]["name"] == "TESTER", "score saved with player name")

	var go := GameOver.new()
	add_child(go)
	go._build()
	check(go.get_child_count() > 0, "game over screen builds")
	print("\nRESULT: %s (%d failures)" % ["ALL PASSED" if fails == 0 else "FAILURES", fails])
	get_tree().quit(fails)
