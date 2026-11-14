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
	verify_scene_nodes()
	verify(Net.decode_code(Net.encode_ip("192.168.1.42")) == "192.168.1.42", "LAN code round trip")
	verify(Net.decode_code("zzzz-zzzz") == "", "Malformed code rejected")
	verify(ItemDB.items.size() == 39, "All item resources loaded")
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
	await verify_presentation()
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
	verify("throws Suspicious tomato" in "\n".join(Game.activity_history), "Throw appears in timestamped incident feed")
	verify(tomato.holder == 0 and tomato.linear_velocity.length() > 10, "Host launches item with charged velocity")
	Game.world.interact(1, "player:" + str(client))
	verify(Game.players[client].mode == "carried", "Friend can be carried")
	Game.world.release_hand(1, 0.5)
	await wait(0.5)
	verify(Game.players[client].mode == "ragdoll", "Thrown friend enters ragdoll")
	verify(Game.players[client].limbs.size() == 6, "Owner transmits six physical ragdoll limb poses")
	await wait(Game.config.player.ragdoll_seconds + 0.2)
	verify(Game.players[client].mode == "walk", "Ragdoll recovers")
	var ragdoll_id: int = Game.world.player_nodes[client].ragdoll.get_instance_id()
	Game.launch_player(client, Vector3(0, 4, 3))
	await wait(0.4)
	verify(Game.world.player_nodes[client].ragdoll.get_instance_id() == ragdoll_id and Game.players[client].limbs.size() == 6, "Existing scene ragdoll resets for another launch")
	await wait(Game.config.player.ragdoll_seconds + 0.1)
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
	Game.world.teacher.fsm.set_physics_process(false)
	Game.players[1].stomach = 50.0
	teleport(1, Game.world.seat_positions[0], "seated")
	Game.players[1].seat = 0
	verify(Game.players[1].mode == "seated", "Player can sit at desk")
	var desk_pos: Vector3 = Game.world.seat_positions[0] - Vector3(0, 0, 0.8)
	var apple = Game.world.spawn_item("apple", desk_pos + Vector3(0, 1.05, 0))
	await wait(0.1)
	Game.world.interact(1, apple.entity_id)
	verify(Game.players[1].held == apple.entity_id, "Seated player can pick up food from their desk")
	Game.world.use_held(1)
	await wait(Game.config.interactions.eat_seconds + 0.2)
	verify(Game.players[1].stomach > 70 and Game.players[1].food == 25, "Eating restores stomach and records allowance food")
	verify(not Game.world.items.has(apple.entity_id) if is_instance_valid(apple) else true, "Eaten item consumed")
	var teacher = Game.world.teacher
	teacher.global_position = Vector3(0, 0, -7)
	teacher.fsm.force_change_state("LectureState")
	teacher.suspicion = 0
	NoiseBus.emit_noise(Vector3(0, 0, 5), 250, str(1), "gunshot")
	verify(teacher.get_current_state_name() in ["shootstate", "investigatestate"], "Over-threshold noise catches/investigates during lecture")
	teacher.fsm.force_change_state("LectureState")
	teacher.suspicion = 0
	teacher.last_check = Game.elapsed
	NoiseBus.emit_noise(Vector3(0, 0, 5), 65, str(1), "crunch")
	verify(teacher.get_current_state_name() == "lecturestate", "Check cooldown blocks repeated low-noise turns")
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-screenshot="):
			await RenderingServer.frame_post_draw
			var path := arg.trim_prefix("--smoke-screenshot=")
			verify(get_viewport().get_texture().get_image().save_png(path) == OK, "Rendered screenshot saved to " + path)
	print("SMOKE_HOST_", "FAILED" if failed else "PASSED")
	await wait(1)
	get_tree().quit(1 if failed else 0)

func verify_scene_nodes() -> void:
	# Detached scenes have not run _ready: these nodes must be authored in .tscn.
	var room = load("res://world/classroom/classroom.tscn").instantiate()
	verify(room.get_node("Desks").get_child_count() == 16 and room.has_node("Teacher/Shotgun/Barrel"), "Classroom and teacher are editable before running scripts")
	verify(room.has_node("Desks/Desk01/SitPoint") and room.has_node("Hallway/VendingMachine/DispensePoint"), "Interaction and spawn markers exist in scene files")
	room.free()
	var player = load("res://characters/player/network_player.tscn").instantiate()
	verify(player.has_node("Head/Camera") and player.get_node("Ragdoll/Bodies").get_child_count() == 6 and player.get_node("Ragdoll/Joints").get_child_count() == 5, "Player camera, ragdoll bodies and joints are prebuilt")
	player.free()
	for data: ItemData in ItemDB.items.values():
		var item = data.scene.instantiate()
		verify(item.has_node("Visual") and item.has_node("CollisionShape3D"), data.id + " has an authored visual and collider")
		item.free()
	var ui = get_tree().current_scene.get_node("UI")
	ui.open_vending()
	verify(ui.vending_rows.get_child_count() == ItemDB.items.size() and ui.vending_panel.visible, "Scene-authored vending controls open and refresh")
	ui.close_vending()
	verify(ui.has_node("Root/HUD/EventFeed/Content/Entries"), "Incident feed is authored in the HUD scene")
	for file in ["impact_burst", "eating", "fart", "burp", "footstep", "tomato_splat", "shot", "pop_rocks"]:
		var scene = load("res://effects/" + file + ".tscn").instantiate()
		verify(scene.get_node("Particles") is CPUParticles3D and scene.has_node("Cleanup"), file + " uses scene-authored Godot particles and cleanup")
		scene.free()

func verify_presentation() -> void:
	Game.log_activity("NETWORK_PRESENTATION_MARKER")
	var effects := Game.world.get_node("Effects")
	for key in ["chew", "impact", "burp", "fart", "footstep", "splat", "pop_rocks"]:
		NoiseBus.emit_noise(Vector3(0, 0, 5), 0, "1", key)
	verify(effects.get_child_count() >= 7, "Gameplay events spawn particle scene instances")
	var spawned: Array = effects.get_children()
	verify("NETWORK_PRESENTATION_MARKER" in get_tree().current_scene.get_node("UI/Root/HUD/EventFeed/Content/Entries").text, "Incident feed updates from authoritative events")
	await wait(2.7)
	verify(spawned.all(func(instance): return not is_instance_valid(instance)), "One-shot particle instances clean themselves up")
	for i in range(Game.config.activity_limit + 5): Game.append_activity("Bounded history test", Game.elapsed)
	verify(Game.activity_history.size() == Game.config.activity_limit, "Incident history is bounded")

func run_client() -> void:
	for attempt in range(150):
		if Game.players.size() >= 2: break
		await wait(0.1)
	verify(Game.players.size() >= 2, "Client receives player roster")
	await wait(1)
	verify(Game.world.player_nodes.size() >= 2, "Client creates both player bodies")
	verify(Game.world.items.size() > 0, "Client receives classroom objects")
	verify("NETWORK_PRESENTATION_MARKER" in "\n".join(Game.activity_history), "Client receives shared incident feed")
	await wait(2)
	var id := multiplayer.get_unique_id()
	verify(Game.players.has(id), "Client retains its assigned identity")
	print("SMOKE_CLIENT_", "FAILED" if failed else "PASSED")
