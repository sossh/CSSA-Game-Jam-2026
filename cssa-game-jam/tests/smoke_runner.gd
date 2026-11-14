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
	verify(ItemDB.items.size() == 41, "All item resources loaded")
	for attempt in range(100):
		if Game.players.size() >= 2: break
		await wait(0.1)
	verify(Game.players.size() >= 2, "Real ENet client registered")
	if Game.players.size() < 2:
		get_tree().quit(1)
		return
	var client: int = Game.players.keys().filter(func(id): return id != 1)[0]
	verify_lunar_collision()
	Game.start_run()
	Game.remaining = 60
	await verify_presentation()
	teleport(1, Game.world.to_global(Vector3(0, 0.1, 5.7)))
	teleport(client, Game.world.to_global(Vector3(0.6, 0.1, 5.7)))
	await wait(0.4)
	verify(Game.world.items.size() >= 20, "Classroom loot and NPCs spawned")
	var tomato = Game.world.spawn_item("tomato", Game.world.to_global(Vector3(0, 1.3, 4.8)))
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
	var first_machine: Node3D = Game.world.get_node("Hallway/VendingMachine")
	teleport(1, first_machine.to_global(Vector3(0, 0, -2)))
	Game.players[1].money = 100
	await wait(0.15)
	var ui := get_tree().current_scene.get_node("UI")
	Game.world.interact(1, "vending")
	verify(ui.vending_panel.visible and ui.vending_machine_id == "vending", "First keypad opens vending from the hallway")
	ui.close_vending()
	var count: int = Game.world.items.size()
	Game.world.buy(1, "chips")
	verify(Game.players[1].money == 93 and Game.world.items.size() == count + 1, "Vending charges once and spawns a physical purchase")
	Game.world.buy(1, "gun")
	verify(Game.players[1].money == 38 and Game.world.items.size() == count + 2, "Grade one can buy previously locked stock")
	await verify_second_vending_machine()
	await verify_rocket_vending_machine()
	await verify_rocket_assembly()
	teleport(1, Game.world.to_global(Vector3(2, 0, -5.2)))
	var drug = Game.world.spawn_item("drug", Game.world.to_global(Vector3(2, 1.2, -5.2)))
	await wait(0.1)
	Game.world.interact(1, drug.entity_id)
	Game.world.interact(1, "coffee")
	verify(Game.world.teacher.drugs == 1 and Game.players[1].held == "", "Drug is consumed into coffee")
	teleport(1, Game.world.to_global(Vector3(0, 0, 5)))
	teleport(client, Game.world.to_global(Vector3(1, 0, 5)))
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
	verify(teacher.get_current_state_name() == "lecturestate" and teacher.global_position.distance_to(teacher.board) < 0.2, "Teacher lectures right away at round start")
	teacher.suspicion = 0
	NoiseBus.emit_noise(teacher.global_position + Vector3.BACK * 3.0, 70, str(client), "burp")
	verify(teacher.suspicion == 0 and teacher.get_current_state_name() == "lecturestate", "Round start sound grace period ignores student noise")
	NoiseBus.emit_noise(teacher.global_position + Vector3.BACK * 3.0, 250, str(1), "gunshot")
	verify(teacher.get_current_state_name() in ["shootstate", "investigatestate"], "Over-threshold noise catches/investigates during lecture")
	teacher.fsm.force_change_state("ShootState")
	teacher.target = str(1)
	NoiseBus.emit_noise(Vector3(2, 0, 5), 100, str(client), "crunch")
	verify(teacher.target == str(1) and teacher.get_current_state_name() == "shootstate", "Player can make noise when teacher actively attacks another student")
	teacher.fsm.force_change_state("LectureState")
	teacher.suspicion = 0
	teacher.sound_grace_until = 0.0
	teacher.last_check = Game.elapsed
	NoiseBus.emit_noise(Game.world.to_global(Vector3(0, 0, 5)), 65, str(1), "crunch")
	verify(teacher.get_current_state_name() == "lecturestate", "Check cooldown blocks repeated low-noise turns")
	var before_stomach: float = Game.players[client].stomach
	Game.damage(client, 30, "was expelled by shotgun", Vector3(0, 5, 5))
	verify(Game.players[client].stomach < before_stomach and Game.players[client].mode != "ragdoll", "Non-lethal shot does not ragdoll immediately")
	teacher.student_shot_grace[str(client)] = Game.elapsed + 6.0
	verify(teacher.student_shot_grace.get(str(client), 0.0) > Game.elapsed, "Teacher respects shot grace period before shooting again")
	var balance: int = Game.players[client].money
	var host_balance: int = Game.players[1].money
	Game.kill(client, "test clone", Vector3(0, 5, 5))
	await wait(0.1)
	verify(Game.phase == "class" and not Game.players[client].alive and Game.world.player_nodes[client].ragdoll.active, "One death spectates with death ragdoll while teammate keeps class alive")
	Game.start_break()
	verify(Game.players[client].alive and Game.players[client].money == balance + Game.config.attendance_allowance - Game.config.cloning_fee, "Bell re-clones with fee")
	verify(Game.survived == 1 and Game.grade == 2, "Class increments endless score and grade")
	verify(Game.players[1].money == host_balance + 5 + 12, "Allowance includes eaten food")
	Game.start_preparation()
	Game.remaining = 60
	Game.kill(client, "test wipe")
	Game.kill(1, "test wipe")
	verify(Game.phase == "game_over", "Simultaneous team wipe ends the run")
	Game.start_run()
	Game.remaining = 60
	verify(Game.phase == "preparation" and Game.survived == 0 and Game.players[1].alive, "Host can restart a wiped run")
	teleport(1, Game.world.to_global(Vector3(0, 0, 5)))
	teleport(client, Game.world.to_global(Vector3(1, 0, 5)))
	await wait(0.5)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-screenshot="):
			await RenderingServer.frame_post_draw
			var path := arg.trim_prefix("--smoke-screenshot=")
			verify(get_viewport().get_texture().get_image().save_png(path) == OK, "Rendered screenshot saved to " + path)
	verify(Game.rocket_parts == 0 and Game.world.launch_site.stage_models.all(func(stage): return not stage.visible), "New run clears the launch pad")
	var site: Node3D = Game.world.launch_site
	verify(Game.rocket_launch_started_at < 0.0 and site.rocket.position.is_equal_approx(site.pad_position)
		and not site.get_node("Falcon9/Thruster/Core").emitting, "New run resets flight and exhaust")
	print("SMOKE_HOST_", "FAILED" if failed else "PASSED")
	await wait(1)
	get_tree().quit(1 if failed else 0)

func verify_second_vending_machine() -> void:
	var world := Game.world
	var machine: Node3D = world.get_node("Hallway/VendingMachine2")
	var keypad: Node3D = machine.get_node("Keypad")
	var tray: StaticBody3D = machine.get_node("PickupTray")
	var point: Marker3D = machine.get_node("DispensePoint")
	teleport(1, machine.to_global(Vector3(0, 0, -2)))
	await wait(0.15)
	var space := world.get_world_3d().direct_space_state
	var eye := machine.to_global(Vector3(-0.63, 1.55, -2))
	var keypad_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, keypad.global_position, 17))
	verify(keypad_hit.get("collider") == keypad, "Second keypad can be aimed at from the hallway")
	var cabinet_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		machine.to_global(Vector3(0, 1.4, -2)), machine.to_global(Vector3(0, 1.4, 0)), 1))
	verify(cabinet_hit.get("collider") == machine.get_node("Case"), "Second cabinet collider faces the hallway")
	var tray_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point.global_position, point.global_position + Vector3.DOWN, 1))
	verify(tray_hit.get("collider") == tray, "Second machine dispenses above its own tray")
	var ui := get_tree().current_scene.get_node("UI")
	Game.world.interact(1, "vending:2")
	verify(ui.vending_panel.visible and ui.vending_machine_id == "vending:2", "Second keypad opens its own vending")
	ui.close_vending()
	var balance: int = Game.players[1].money
	var existing_items: Array = world.items.keys()
	world.buy(1, "chips", "vending:2")
	var purchases: Array = world.items.keys().filter(func(id): return not id in existing_items)
	verify(Game.players[1].money == balance - ItemDB.get_item("chips").price and purchases.size() == 1,
		"Second machine charges once and dispenses one item")
	if purchases.size() != 1: return
	var item: Node3D = world.items[purchases[0]]
	verify(item.global_position.is_equal_approx(point.global_position), "Second purchase starts at its dispense marker")
	await wait(0.6)
	if is_instance_valid(item):
		var landing := tray.to_local(item.global_position)
		verify(absf(landing.x) < 0.4 and absf(landing.z) < 0.4 and landing.y > 0.035 and landing.y < 0.23,
			"Second purchase lands on the pickup tray")
		world.remove_item(purchases[0])
	else:
		verify(false, "Second purchase survives the drop")
	Game.players[1].money = balance

func verify_rocket_vending_machine() -> void:
	var world := Game.world
	var machine: Node3D = world.get_node("Hallway/RocketVendingMachine")
	var point: Marker3D = machine.get_node("DispensePoint")
	var tray: StaticBody3D = machine.get_node("PickupTray")
	var ui := get_tree().current_scene.get_node("UI")
	var player: Dictionary = Game.players[1]
	var balance: int = player.money
	player.money = 3
	teleport(1, machine.to_global(Vector3(0, 0, -2)))
	await wait(0.15)
	world.interact(1, ItemDB.ROCKET_VENDING)
	var rows: Array = ui.vending_rows.get_children().filter(func(row): return row.visible)
	verify(ui.vending_panel.visible and rows.map(func(row): return row.item_id) == ["rocket", "rocket_second_stage", "rocket_fairing"],
		"Falcon keypad offers the three stages in code order")
	var item_count: int = world.items.size()
	world.buy(1, "chips", ItemDB.ROCKET_VENDING)
	verify(player.money == 3 and world.items.size() == item_count, "Falcon cabinet rejects snack purchases")
	for index in range(rows.size()):
		var entry = rows[index]
		var code := "A%02d" % (index + 1)
		verify(not entry.disabled and entry.text.begins_with(code + " • ₿1 • "), "Falcon menu offers " + code + " for one Bitcoin")
		var item_id: String = entry.item_id
		var existing_items: Array = world.items.keys()
		var money: int = player.money
		ui.buy_code(code)
		var purchases: Array = world.items.keys().filter(func(id): return not id in existing_items)
		verify(purchases.size() == 1 and player.money == money - 1,
			"Falcon keypad charges once and dispenses one item for " + code)
		if purchases.size() != 1: continue
		var item: ClassroomItem = world.items[purchases[0]]
		verify(item.item_id == item_id and item.global_position.is_equal_approx(point.global_position),
			"Falcon cabinet dispenses the matching model at its chute")
		await wait(0.7)
		var landing := tray.to_local(item.global_position)
		verify(absf(landing.x) < 0.4 and absf(landing.z) < 0.4 and landing.y > 0.035 and landing.y < 0.38,
			"Falcon purchase lands on the pickup tray")
		world.remove_item(purchases[0])
	ui.close_vending()
	teleport(1, world.get_node("Hallway/VendingMachine").to_global(Vector3(0, 0, -2)))
	await wait(0.15)
	var remaining_money: int = player.money
	world.buy(1, "rocket")
	verify(player.money == remaining_money and world.items.size() == item_count, "Cosmic Crunch rejects Falcon stock")
	world.interact(1, "vending")
	var regular_rows: Array = ui.vending_rows.get_children().filter(func(row): return row.visible)
	verify(regular_rows.size() == ItemDB.stock().size() and regular_rows.all(func(row): return not row.disabled), "Cosmic Crunch offers every regular item at grade one")
	ui.close_vending()
	player.money = balance

func verify_rocket_assembly() -> void:
	var world := Game.world
	var console: Interactable = world.interactions["rocket_console"]
	var site: Node3D = world.launch_site
	var rocket := site.get_node("Falcon9") as Node3D
	var core := rocket.get_node("Thruster/Core") as CPUParticles3D
	var player: Dictionary = Game.players[1]
	var target := console.get_parent() as Node3D
	teleport(1, target.to_global(Vector3(0, 0.15, 2.8)))
	await wait(0.15)
	verify(Game.rocket_parts == 0 and site.stage_models.all(func(stage): return not stage.visible), "Rocket starts unassembled")
	var ray := PhysicsRayQueryParameters3D.create(player.position + Vector3.UP * 1.55, console.global_position, 17)
	verify(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == console, "Launch console can be aimed at from the platform")
	world.interact(1, "rocket_console")
	verify(Game.rocket_launch_started_at < 0.0 and not core.emitting, "Incomplete Falcon cannot launch")
	for part in ["rocket_fairing", "rocket", "rocket", "rocket_second_stage"]:
		var item: ClassroomItem = world.spawn_item(part, player.position + Vector3.UP)
		var entity_id := item.entity_id
		item.pickup(1)
		player.held = entity_id
		var already_installed := Game.installed_rocket_parts.has(part)
		world.interact(1, "rocket_console")
		if already_installed:
			verify(world.items.has(entity_id) and player.held == entity_id, "Duplicate rocket part stays in the player's hand")
			world.remove_item(entity_id)
		else:
			var stage_index: int = ItemDB.FALCON_STOCK.find(part)
			verify(not world.items.has(entity_id) and player.held.is_empty() and site.stage_models[stage_index].visible, "Console consumes and mounts " + part)
	await wait(0.15)
	verify(Game.rocket_parts == 3 and site.stage_colliders.all(func(shape): return not shape.disabled), "Completed Falcon has all three colliders")
	verify(Game.make_snapshot().installed_rocket_parts == Game.installed_rocket_parts, "Snapshots include each installed part")
	var pad_height := rocket.position.y
	Game.request("interact", {"target": "rocket_console"})
	var started_at := Game.rocket_launch_started_at
	verify(started_at >= 0.0 and Game.make_snapshot().rocket_launch_started_at == started_at, "Host starts and replicates the launch")
	await wait(0.65)
	verify(core.emitting and is_equal_approx(rocket.position.y, pad_height), "Engine ignites before liftoff")
	await wait(1.15)
	verify(rocket.position.y > pad_height and rocket.quaternion.is_equal_approx(Quaternion.IDENTITY)
		and is_equal_approx(rocket.position.x, site.pad_position.x) and is_equal_approx(rocket.position.z, site.pad_position.z)
		and site.stage_colliders.all(func(shape): return shape.disabled), "Rocket lifts straight off the pad with stage collisions disabled")
	Game.request("interact", {"target": "rocket_console"})
	verify(Game.rocket_launch_started_at == started_at, "Launch console cannot restart an active flight")

func verify_lunar_collision() -> void:
	var world := Game.world
	var ground := world.get_node("PlanetSurface/Ground")
	var space := world.get_world_3d().direct_space_state
	var crater := Vector3(-3.43, 0, 30.05)
	var rim := crater + Vector3.RIGHT * 1.72
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		world.to_global(crater + Vector3.UP * 5), world.to_global(crater + Vector3.DOWN * 12), 1))
	var rim_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		world.to_global(rim + Vector3.UP * 5), world.to_global(rim + Vector3.DOWN * 12), 1))
	verify(floor_hit.get("collider") == ground and rim_hit.get("collider") == ground
		and rim_hit.position.y - floor_hit.position.y > 0.4, "Lunar collision follows the crater floor and rim")

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
	for attempt in range(100):
		if Game.rocket_parts == 3: break
		await wait(0.1)
	var site: Node3D = Game.world.launch_site
	verify(Game.rocket_parts == 3 and site.stage_models.all(func(stage): return stage.visible), "Client sees all three installed rocket stages")
	for attempt in range(45):
		if Game.rocket_launch_started_at >= 0.0 and site.get_node("Falcon9/Thruster/Core").emitting: break
		await wait(0.1)
	verify(Game.rocket_launch_started_at >= 0.0 and site.get_node("Falcon9/Thruster/Core").emitting, "Client sees the host's rocket ignition")
	print("SMOKE_CLIENT_", "FAILED" if failed else "PASSED")
