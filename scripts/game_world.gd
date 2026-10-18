extends Node3D
## Builds the graveyard level and wires up all systems.

var player: Player
var waves: WaveManager


func _ready() -> void:
	GameState.reset_run()
	GameState.world = self
	GraveyardBuilder.build(self)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 0.1, 12)

	waves = WaveManager.new()
	waves.name = "Waves"
	add_child(waves)
	var spawner := PickupSpawner.new()
	spawner.name = "Pickups"
	add_child(spawner)

	var hud := HUD.new()
	hud.waves = waves
	add_child(hud)
	var shop := Shop.new()
	shop.player = player
	add_child(shop)
	var pause := PauseMenu.new()
	pause.shop = shop
	add_child(pause)
	add_child(GameOver.new())

	GameState.zombie_killed.connect(_on_zombie_killed)
	AudioManager.start_ambience()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_zombie_killed(z: Node, headshot: bool) -> void:
	GameState.kills += 1
	var pts := 1000 if z.get("is_boss") else 100
	if headshot:
		pts += 50
	GameState.add_score(pts)
