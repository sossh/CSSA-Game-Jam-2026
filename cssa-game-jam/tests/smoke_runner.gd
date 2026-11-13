extends Node

## Real ENet integration scenario. Invoke with --smoke on host and client.
## Test-only teleport helpers keep the scenario deterministic and fast.
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

func teleport(id: int, at: Vector3, mode: String = "walk") -> void:
	Game.players[id].position = at
	Game.players[id].mode = mode
	Game.players[id].epoch += 1

func run_host() -> void:
	verify(Net.decode_code(Net.encode_ip("192.168.1.42")) == "192.168.1.42", "LAN code round trip")
	verify(Net.decode_code("zzzz-zzzz") == "", "Malformed code rejected")
	verify(ItemDB.items.size() == 17, "All item resources loaded")
	for attempt in range(100):
		if Game.players.size() >= 2: break
		await wait(0.1)
	verify(Game.players.size() >= 2, "Real ENet client registered")
	if Game.players.size() < 2:
		get_tree().quit(1)
		return
	var client: int = Game.players.keys().filter(func(id): return id != 1)[0]
	Game.start_run()
	Game.remaining = 60
	teleport(1, Vector3(0, 0.1, 5.7))
	teleport(client, Vector3(0.6, 0.1, 5.7))
	await wait(0.4)
	verify(Game.world.items.size() >= 20, "Classroom loot and NPCs spawned")
	var tomato = Game.world.spawn_item("tomato", Vector3(0, 1.3, 4.8))
	await wait(0.1)
	Game.world.interact(1, tomato.entity_id)
	Game.world.interact(client, tomato.entity_id)
	verify(tomato.holder == 1 and Game.players[client].held == "", "Only one peer wins a contested pickup")
	Game.world.release_hand(1, 0.8)
	verify(tomato.holder == 0 and tomato.linear_velocity.length() > 10, "Host launches item with charged velocity")
	Game.world.interact(1, "player:" + str(client))
	verify(Game.players[client].mode == "carried", "Friend can be carried")
	Game.world.release_hand(1, 0.5)
	await wait(0.5)
	verify(Game.players[client].mode == "ragdoll", "Thrown friend enters ragdoll")
	verify(Game.players[client].limbs.size() == 6, "Owner transmits six physical ragdoll limb poses")
	await wait(Game.config.ragdoll_seconds + 0.2)
	verify(Game.players[client].mode == "walk", "Ragdoll recovers")
	teleport(1, Game.world.vending_position + Vector3(0, 0, -2))
	Game.players[1].money = 100
	await wait(0.15)
	var count: int = Game.world.items.size()
	Game.world.buy(1, "chips")
	verify(Game.players[1].money == 93 and Game.world.items.size() == count + 1, "Vending charges once and spawns a physical purchase")
	Game.world.buy(1, "gun")
	verify(Game.players[1].money == 93, "Grade lock rejects gun purchase")
	teleport(1, Vector3(2, 0, -5.2))
	var drug = Game.world.spawn_item("drug", Vector3(2, 1.2, -5.2))
	await wait(0.1)
	Game.world.interact(1, drug.entity_id)
	Game.world.interact(1, "coffee")
	verify(Game.world.teacher.drugs == 1 and Game.players[1].held == "", "Drug is consumed into coffee")
	teleport(1, Vector3(0, 0, 5))
	teleport(client, Vector3(1, 0, 5))
	await wait(0.2)
	Game.start_class()
	Game.remaining = 60
	Game.world.teacher.set_physics_process(false)
	Game.players[1].stomach = 50.0
	var apple = Game.world.spawn_item("apple", Vector3(0, 1.3, 4.5))
	await wait(0.1)
	Game.world.interact(1, apple.entity_id)
	Game.world.use_held(1)
	await wait(1.7)
	verify(Game.players[1].stomach > 70 and Game.players[1].food == 25, "Eating restores stomach and records allowance food")
	verify(not Game.world.items.has(apple.entity_id) if is_instance_valid(apple) else true, "Eaten item consumed")
	var teacher = Game.world.teacher
	teacher.global_position = Vector3(0, 0, -7)
	teacher.state = ClassroomTeacher.State.LECTURE
	teacher.suspicion = 0
	NoiseBus.emit_noise(Vector3(0, 0, 5), 250, str(1), "gunshot")
	verify(teacher.state in [ClassroomTeacher.State.SHOOT, ClassroomTeacher.State.INVESTIGATE], "Over-threshold noise catches/investigates during lecture")
	teacher.state = ClassroomTeacher.State.LECTURE
	teacher.suspicion = 0
	teacher.last_check = Game.elapsed
	NoiseBus.emit_noise(Vector3(0, 0, 5), 65, str(1), "crunch")
	verify(teacher.state == ClassroomTeacher.State.LECTURE, "Check cooldown blocks repeated low-noise turns")
	var balance: int = Game.players[client].money
	Game.kill(client, "test clone")
	verify(Game.phase == "class" and not Game.players[client].alive, "One death spectates while teammate keeps class alive")
	Game.start_break()
	verify(Game.players[client].alive and Game.players[client].money == balance + Game.config.attendance_allowance - Game.config.cloning_fee, "Bell re-clones with fee")
	verify(Game.survived == 1 and Game.grade == 2, "Class increments endless score and grade")
	verify(Game.players[1].money == 93 + 5 + 12, "Allowance includes eaten food")
	Game.start_preparation()
	Game.remaining = 60
	Game.kill(client, "test wipe")
	Game.kill(1, "test wipe")
	verify(Game.phase == "game_over", "Simultaneous team wipe ends the run")
	Game.start_run()
	Game.remaining = 60
	verify(Game.phase == "preparation" and Game.survived == 0 and Game.players[1].alive, "Host can restart a wiped run")
	teleport(1, Vector3(0, 0, 5))
	teleport(client, Vector3(1, 0, 5))
	await wait(0.5)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/opencode/cosmic-detention.png")
	print("SMOKE_HOST_", "FAILED" if failed else "PASSED")
	await wait(1)
	get_tree().quit(1 if failed else 0)

func run_client() -> void:
	for attempt in range(150):
		if Game.players.size() >= 2: break
		await wait(0.1)
	verify(Game.players.size() >= 2, "Client receives player roster")
	await wait(1)
	verify(Game.world.player_nodes.size() >= 2, "Client creates both player bodies")
	verify(Game.world.items.size() > 0, "Client receives classroom objects")
	await wait(2)
	var id := multiplayer.get_unique_id()
	verify(Game.players.has(id), "Client retains its assigned identity")
	print("SMOKE_CLIENT_", "FAILED" if failed else "PASSED")
