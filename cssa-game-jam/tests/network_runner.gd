extends Node

## Six peers, a mid-class arrival, ownership, disconnect, and natural timers.
var failed: bool = false

func _ready() -> void:
	if Game.is_host(): run_host.call_deferred()
	else: run_client.call_deferred()

func verify(condition: bool, description: String) -> void:
	if condition: print("PASS ", description)
	else:
		failed = true
		push_error("FAIL " + description)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func run_host() -> void:
	Game.config.npc_count = 0 # Isolate human roll-call and six-peer networking.
	Game.config.preparation_seconds = 3
	Game.config.class_seconds = 9
	Game.config.break_seconds = 3
	for attempt in range(100):
		if Game.players.size() >= 5: break
		await wait(0.1)
	verify(Game.players.size() == 5, "Initial five peers registered")
	var arrival_positions: Array[Vector3] = []
	for id in Game.players:
		var position: Vector3 = Game.players[id].position
		verify(position.z > 30.0 and position.y < 0.0 and not arrival_positions.has(position), "Peer starts at a distinct lunar arrival spot")
		arrival_positions.append(position)
	Game.start_run()
	verify(Game.players.values().all(func(player): return player.position in arrival_positions), "Starting the first round keeps the lunar arrivals in place")
	var seat := 0
	for id in Game.players:
		Game.players[id].position = Game.world.seat_positions[seat]
		Game.players[id].mode = "seated"
		Game.players[id].seat = seat
		Game.players[id].epoch += 1
		seat += 1
	var board := Game.world.to_global(Vector3(0, 0, -7))
	var rear_aisle := Game.world.to_global(Vector3(0, 0, 6))
	verify(Game.world.walk_path(board, rear_aisle).size() > 5, "Investigation path spans classroom aisles")
	for attempt in range(60):
		if Game.phase == "class": break
		await wait(0.1)
	verify(Game.phase == "class", "Preparation timer starts class automatically")
	print("NETWORK_READY_FOR_LATE_JOIN")
	for attempt in range(60):
		if Game.players.size() == 6: break
		await wait(0.1)
	verify(Game.players.size() == 6, "Six-player LAN lobby supported")
	var late: int = 0
	for id in Game.players:
		if not Game.players[id].alive: late = id
	verify(late != 0, "Mid-class arrival spectates until the bell")
	# Demonstrate real server-side shot collision and no-through-walls sight.
	Game.world.teacher.global_position = board
	verify(not Game.world.teacher.clear_sight(Game.world.to_global(Vector3(5, 1, 12))), "Hallway wall blocks teacher vision")
	Game.players[1].mode = "walk"
	Game.players[1].seat = -1
	Game.players[1].position = Game.world.to_global(Vector3(0, 0, -5))
	Game.players[1].epoch += 1
	await wait(0.2)
	var stomach: float = Game.players[1].stomach
	Game.world.teacher.aim_point = Game.world.to_global(Vector3(0, 1, -5))
	Game.world.teacher.fire()
	verify(Game.players[1].stomach < stomach - 60 and Game.players[1].mode == "walk", "Shotgun ray damages visible student without premature ragdoll")
	# Return host to a desk to avoid a second lethal roll-call shot.
	Game.players[1].stomach = 100.0
	Game.players[1].mode = "seated"
	Game.players[1].seat = 0
	Game.players[1].position = Game.world.seat_positions[0]
	Game.players[1].epoch += 1
	for attempt in range(120):
		if Game.phase == "break": break
		await wait(0.1)
	verify(Game.phase == "break", "Class timer opens break automatically")
	verify(late != 0 and Game.players[late].alive, "Late arrival re-cloned at bell")
	verify(Game.survived == 1 and Game.grade == 2, "Natural round updates shared progression")
	print("NETWORK_READY_FOR_DISCONNECT")
	for attempt in range(25):
		if Game.players.size() < 6: break
		await wait(0.1)
	verify(Game.players.size() == 5 and Game.world.player_nodes.size() == 5, "Disconnect removes roster and player body")
	for attempt in range(50):
		if Game.phase == "class": break
		await wait(0.1)
	verify(Game.phase == "class", "Break timer advances to next class")
	print("NETWORK_HOST_", "FAILED" if failed else "PASSED")
	await wait(0.5)
	get_tree().quit(1 if failed else 0)

func run_client() -> void:
	for attempt in range(150):
		if Game.players.size() == 6: break
		await wait(0.1)
	verify(Game.players.size() == 6, "Client sees all six players")
	verify(Game.world.player_nodes.size() == 6, "Client has six matching player bodies")
	verify(Game.world.items.size() >= 25, "Client receives large classroom snapshot")
	var id := multiplayer.get_unique_id()
	if "--late" in OS.get_cmdline_user_args():
		verify(not Game.players[id].alive, "Late client starts in spectator mode")
		var camera: Camera3D = Game.world.player_nodes[id].camera
		var earth: Node3D = Game.world.get_node("SpaceBackdrop/Earth")
		verify(camera.global_position.z > 30.0
			and -camera.global_basis.z.dot(camera.global_position.direction_to(earth.global_position)) > 0.99,
			"Late client sees Earth from the lunar ramp")
	for attempt in range(120):
		if Game.phase == "break": break
		await wait(0.1)
	verify(Game.phase == "break" and Game.survived == 1, "Client receives phase and score changes")
	verify(Game.players[id].alive, "Client is alive after cloning")
	if "--late" in OS.get_cmdline_user_args():
		var cafe_position: Vector3 = Game.world.cafe_respawn_position(Game.players[id].spawn_slot)
		verify(Game.world.player_nodes[id].global_position.distance_to(cafe_position) < 0.2, "Late client materializes in the cafe")
	print("NETWORK_CLIENT_", "FAILED" if failed else "PASSED")
	if "--late" in OS.get_cmdline_user_args():
		await wait(0.3)
		Net.disconnect_session()
