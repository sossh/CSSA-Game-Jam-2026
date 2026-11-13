class_name ClassroomWorld
extends Node3D

var player_nodes: Dictionary = {}
var items: Dictionary = {}
var interactions: Dictionary = {}
var seat_positions: Array[Vector3] = []
var spawn_positions: Array[Vector3] = []
var teacher: ClassroomTeacher
var door: Node3D
var clock: Label3D
var rocket_label: Label3D
var rocket_visual: Node3D
var menu_camera: Camera3D
var grid: AStarGrid2D
var serial: int = 0
var last_rocket_count: int = -1
var vending_position := Vector3(5, 0, 13)
var coffee_position := Vector3(3, 1.2, -6.5)
var rocket_position := Vector3(-5, 0, 13)

func _ready() -> void:
	Game.world = self
	build_room()
	teacher = ClassroomTeacher.new()
	teacher.name = "Teacher"
	add_child(teacher)
	Game.effect.connect(on_effect)

func build_room() -> void:
	var floor_color := Color(0.18, 0.22, 0.3)
	var wall_color := Color(0.3, 0.36, 0.44)
	Greybox.box(self, Vector3(0, -0.2, 3), Vector3(18, 0.4, 26), floor_color)
	Greybox.box(self, Vector3(0, 2.5, -10), Vector3(18, 5, 0.3), wall_color)
	Greybox.box(self, Vector3(-9, 2.5, 3), Vector3(0.3, 5, 26), wall_color)
	Greybox.box(self, Vector3(9, 2.5, 3), Vector3(0.3, 5, 26), wall_color)
	Greybox.box(self, Vector3(0, 2.5, 16), Vector3(18, 5, 0.3), wall_color)
	Greybox.box(self, Vector3(-5, 2.5, 8), Vector3(8, 5, 0.3), wall_color)
	Greybox.box(self, Vector3(5, 2.5, 8), Vector3(8, 5, 0.3), wall_color)
	Greybox.box(self, Vector3(0, 4.25, 8), Vector3(2, 1.5, 0.3), wall_color)
	door = Greybox.box(self, Vector3(0, 1.75, 8), Vector3(2, 3.5, 0.25), Color(0.55, 0.2, 0.2))
	Greybox.label(self, "CLASSROOM 0xC05\nNO FOOD. NO FUN. NO EARTH.", Vector3(0, 3.9, 8.2), 30)
	Greybox.box(self, Vector3(0, 2.5, -9.75), Vector3(9, 2.8, 0.1), Color(0.05, 0.2, 0.18), false)
	Greybox.label(self, "ALIEN CALCULUS\ncos(mos) = detention²\nToday's lesson: SURVIVE", Vector3(0, 2.7, -9.62), 42)
	clock = Greybox.label(self, "05:00", Vector3(6, 3.8, -9.6), 64)
	grid = AStarGrid2D.new()
	grid.region = Rect2i(-16, -18, 33, 34)
	grid.cell_size = Vector2(0.5, 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for row in range(4):
		for column in range(4):
			var pos := Vector3(-5.4 + column * 3.6, 0, -3.8 + row * 2.7)
			var seat := pos + Vector3(0, 0, 0.8)
			var index := seat_positions.size()
			seat_positions.append(seat)
			Greybox.box(self, pos + Vector3(0, 0.87, 0), Vector3(1.6, 0.16, 0.8), Color(0.5, 0.39, 0.28))
			for x in [-0.65, 0.65]:
				Greybox.box(self, pos + Vector3(x, 0.42, 0), Vector3(0.1, 0.84, 0.6), Color(0.23, 0.27, 0.3))
			Greybox.box(self, seat + Vector3(0, 0.45, 0), Vector3(0.65, 0.12, 0.65), Color(0.26, 0.4, 0.55), false)
			Greybox.box(self, seat + Vector3(0, 0.8, 0.28), Vector3(0.65, 0.65, 0.1), Color(0.26, 0.4, 0.55), false)
			add_interaction("seat:" + str(index), "Sit / evict clone", seat + Vector3(0, 0.55, 0), Vector3(0.8, 1.1, 0.8))
			spawn_positions.append(pos + Vector3(0, 1.15, 0))
			spawn_positions.append(pos + Vector3(0.8, 0.3, 0.7))
			mark_obstacle(pos, Vector2(1.25, 0.85))
	Greybox.box(self, Vector3(3, 0.55, -6.5), Vector3(2.5, 1.1, 1), Color(0.45, 0.3, 0.23))
	mark_obstacle(Vector3(3, 0, -6.5), Vector2(1.65, 0.9))
	Greybox.box(self, coffee_position, Vector3(0.22, 0.28, 0.22), Color.BROWN, false)
	add_interaction("coffee", "Drug coffee (hold sleeping tablets)", coffee_position, Vector3(0.5, 0.5, 0.5))
	spawn_positions.append(Vector3(3.7, 1.3, -6.5))
	Greybox.box(self, vending_position + Vector3(0, 1.4, 0), Vector3(1.8, 2.8, 1.2), Color(0.25, 0.2, 0.6))
	Greybox.box(self, vending_position + Vector3(0, 1.5, -0.66), Vector3(1.4, 1.8, 0.05), Color(0.06, 0.09, 0.13), false)
	Greybox.label(self, "COSMIC CRUNCH\n[ E ] KEYPAD\nBITCOIN ONLY", vending_position + Vector3(0, 2.25, -0.72), 32).rotation.y = PI
	add_interaction("vending", "Vending keypad", vending_position + Vector3(0, 1.3, -0.75), Vector3(1.8, 2.6, 0.3))
	Greybox.box(self, rocket_position, Vector3(3, 0.2, 3), Color(0.25, 0.65, 0.7))
	rocket_label = Greybox.label(self, "", rocket_position + Vector3(0, 3, 0), 38)
	rocket_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_interaction("rocket", "Contribute rocket part", rocket_position + Vector3(0, 0.6, 0), Vector3(2.5, 1, 2.5))
	rocket_visual = Node3D.new()
	add_child(rocket_visual)
	rocket_visual.position = rocket_position
	for x in [-0.9, 0.9]:
		Greybox.box(self, Vector3(x, 5.4, 13.8), Vector3(0.2, 3.6, 2), Color(0.4, 0.45, 0.5))
	Greybox.label(self, "TRANSFER CHUTE\nCloning fee: ₿10", Vector3(0, 3.8, 15.7), 32).rotation.y = PI
	# Geometric greybox cosmos: replace with human-made sky/planet assets later.
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.8, 1)
	env.ambient_light_energy = 0.75
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, -25, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	for i in range(35):
		var angle := i * 2.39996
		Greybox.box(self, Vector3(cos(angle) * 65, 15 + (i % 8) * 5, sin(angle) * 65), Vector3.ONE * 0.3, Color.WHITE, false)
	Greybox.box(self, Vector3(30, 30, -45), Vector3(12, 12, 12), Color(0.2, 0.4, 0.9), false)
	menu_camera = Camera3D.new()
	add_child(menu_camera)
	menu_camera.position = Vector3(7, 6, 7)
	menu_camera.look_at(Vector3(0, 1, -3))
	menu_camera.current = true

func add_interaction(id: String, text: String, at: Vector3, size: Vector3) -> void:
	var interactable := Interactable.new()
	add_child(interactable)
	interactable.position = at
	interactable.configure(id, text, size)
	interactions[id] = interactable

func mark_obstacle(pos: Vector3, half_size: Vector2) -> void:
	for cell in grid.region.size.x * grid.region.size.y:
		var id := Vector2i(grid.region.position.x + cell % grid.region.size.x, grid.region.position.y + cell / grid.region.size.x)
		var point := Vector2(id) * 0.5
		if absf(point.x - pos.x) < half_size.x and absf(point.y - pos.z) < half_size.y: grid.set_point_solid(id)

func walk_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := nearest_walkable(from)
	var end := nearest_walkable(to)
	var result := PackedVector3Array()
	for point in grid.get_point_path(start, end): result.append(Vector3(point.x, 0, point.y))
	return result

func nearest_walkable(point: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(point.x * 2), roundi(point.z * 2))
	cell.x = clampi(cell.x, -16, 16)
	cell.y = clampi(cell.y, -18, 15)
	for radius in range(12):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var test := cell + Vector2i(x, y)
				if grid.is_in_boundsv(test) and not grid.is_point_solid(test): return test
	return Vector2i.ZERO

func chute_position(index: int) -> Vector3:
	return Vector3(-0.5 + (index % 2), 3.5 + (index / 2) * 0.5, 13.4)

func _physics_process(_delta: float) -> void:
	if Net.active: ensure_players()
	var closed := Game.phase == "class"
	door.position.y = 1.75 if closed else 5.5
	clock.text = "%02d:%02d" % [int(Game.remaining) / 60, int(Game.remaining) % 60]
	rocket_label.text = "CLASS ESCAPE FUND\n%d ROCKET PARTS" % Game.rocket_parts
	if last_rocket_count != Game.rocket_parts:
		last_rocket_count = Game.rocket_parts
		for child in rocket_visual.get_children(): child.queue_free()
		for i in range(mini(20, Game.rocket_parts)):
			Greybox.box(rocket_visual, Vector3((i % 3 - 1) * 0.5, 0.4 + (i / 3) * 0.45, 0), Vector3.ONE * 0.45, Color(0.6, 0.8, 0.9), false)

func ensure_players() -> void:
	for id in Game.players:
		if not player_nodes.has(id):
			var player := StudentPlayer.new()
			player.peer_id = id
			player.name = "Player%d" % id
			add_child(player)
			player_nodes[id] = player
	for id in player_nodes.keys():
		if not Game.players.has(id):
			player_nodes[id].queue_free()
			player_nodes.erase(id)

func spawn_item(id: String, at: Vector3, kid: bool = false, dead: bool = false, seat: int = -1) -> ClassroomItem:
	serial += 1
	return create_item("item:" + str(serial), {"item": id, "transform": Transform3D(Basis.IDENTITY, at), "holder": 0,
		"kid": kid, "dead": dead, "seated": kid and not dead and seat >= 0, "home": seat, "uses": ItemDB.get_item(id).uses})

func create_item(entity_id: String, state: Dictionary) -> ClassroomItem:
	var item := ClassroomItem.new()
	item.entity_id = entity_id
	item.name = entity_id.replace(":", "_")
	item.item_id = state.item
	item.kid = state.kid
	item.dead = state.dead
	item.seated = state.seated
	item.home_seat = state.home
	item.transform = state.transform
	add_child(item)
	item.receive(state)
	items[entity_id] = item
	return item

func remove_item(id: String) -> void:
	if not items.has(id): return
	var item = items[id]
	if item.holder and Game.players.has(item.holder) and Game.players[item.holder].held == id:
		Game.players[item.holder].held = ""
	items.erase(id)
	item.queue_free()

func clear_items() -> void:
	for id in items.keys(): remove_item(id)

func serialize() -> Dictionary:
	var state: Dictionary = {}
	for id in items: state[id] = items[id].serialize()
	return {"items": state, "teacher": teacher.serialize()}

func reconcile(state: Dictionary) -> void:
	ensure_players()
	for id in state.items:
		if not items.has(id): create_item(id, state.items[id])
		else: items[id].receive(state.items[id])
	for id in items.keys():
		if not state.items.has(id): remove_item(id)
	teacher.receive(state.teacher)

func prepare_class() -> void:
	for id in items.keys():
		var item = items[id]
		if item.holder == 0 and (item.kid or items.size() > Game.config.max_loose_items / 2): remove_item(id)
	var npc_spawned := 0
	for seat in range(seat_positions.size() - 1, -1, -1):
		if npc_spawned >= Game.config.npc_count: break
		if free_seat(seat) == seat:
			spawn_item("rock", seat_positions[seat] + Vector3(0, 0.8, 0), true, false, seat)
			npc_spawned += 1
	var count := Game.players.size() * Game.config.food_spawns_per_player + 5
	for i in range(count):
		if items.size() >= Game.config.max_loose_items: break
		var point: Vector3 = spawn_positions[i % spawn_positions.size()]
		point += Vector3(randf_range(-0.25, 0.25), 0.1 + (i / spawn_positions.size()) * 0.3, randf_range(-0.12, 0.12))
		spawn_item(ItemDB.random_item(Game.grade, i < count - 4), point)
	spawn_item("drug", Vector3(0.5, 0.3, 11))
	spawn_item("tomato", Vector3(-0.5, 0.3, 11))

func free_seat(preferred: int = -1) -> int:
	var available: Array[int] = []
	for i in range(seat_positions.size()):
		var occupied := false
		for p in Game.players.values():
			if p.alive and p.seat == i: occupied = true
		for item in items.values():
			if item.kid and item.seated and item.home_seat == i: occupied = true
		if not occupied: available.append(i)
	if preferred in available: return preferred
	return -1 if available.is_empty() else available[0]

func interact(id: int, target: String) -> void:
	var p: Dictionary = Game.players[id]
	var at: Vector3
	if interactions.has(target): at = interactions[target].global_position
	elif items.has(target): at = items[target].global_position
	elif target.begins_with("player:") and Game.players.has(int(target.get_slice(":", 1))): at = Game.players[int(target.get_slice(":", 1))].position + Vector3.UP
	else: return
	if p.position.distance_to(at) > 4: return
	if not has_reach(id, at): return
	if p.eat_until > Game.elapsed: return
	if target == "vending":
		if Game.phase in ["lobby", "preparation", "break"]: Game.event.rpc("vending", {"id": id})
		return
	if target == "coffee":
		if Game.phase not in ["lobby", "preparation", "break"]: return
		if items.has(p.held) and items[p.held].data.effect == "drug":
			remove_item(p.held)
			teacher.drugs = mini(3, teacher.drugs + 1)
			Game.event.rpc("banner", {"text": "Coffee enhanced. Professor X-PEL will be very sleepy."})
		return
	if target == "rocket":
		if items.has(p.held) and items[p.held].data.effect == "rocket":
			remove_item(p.held)
			Game.rocket_parts += 1
			Game.event.rpc("banner", {"text": "One step closer to Earth! Shared rocket parts: %d" % Game.rocket_parts})
		return
	if target.begins_with("seat:"):
		var seat := int(target.get_slice(":", 1))
		for other in Game.players.values():
			if other.seat == seat: return
		if p.held.begins_with("player:"): release_hand(id)
		for item in items.values():
			if item.kid and item.seated and item.home_seat == seat:
				item.release(item.global_position + Vector3.UP, Vector3(1, 4, 2), str(id))
			if item.data.effect == "cushion" and item.global_position.distance_to(at) < 1.2:
				NoiseBus.emit_noise(at, 90, str(id), "fart")
		p.mode = "seated"
		p.seat = seat
		p.position = seat_positions[seat]
		p.epoch += 1
		return
	if p.held != "": return
	if items.has(target):
		var item = items[target]
		if item.holder != 0: return
		item.pickup(id)
		p.held = target
	elif target.begins_with("player:"):
		var other_id := int(target.get_slice(":", 1))
		var other: Dictionary = Game.players[other_id]
		if other_id == id or not other.alive or other.mode == "carried" or other.held.begins_with("player:"): return
		release_hand(other_id)
		other.mode = "carried"
		other.carrier = id
		other.seat = -1
		other.recover_at = 0.0
		other.epoch += 1
		p.held = target
	p.violation_until = Game.elapsed + 1.5
	NoiseBus.emit_noise(p.position, 10, str(id), "pickup")

func has_reach(id: int, at: Vector3) -> bool:
	var eye: Vector3 = Game.players[id].position + Vector3(0, 1.55, 0)
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at, 1)).is_empty()

func release_hand(id: int, charge: float = -1) -> void:
	if not Game.players.has(id): return
	var p: Dictionary = Game.players[id]
	var held: String = p.held
	p.held = ""
	p.eat_until = 0.0
	if held == "": return
	var direction := aim_direction(id)
	var impulse := direction * (8 + charge * 12) + Vector3.UP * 2 if charge >= 0 else direction * 1.5
	var at: Vector3 = p.position + Vector3(0, 1.4, 0) + direction * 0.8
	if items.has(held):
		var item = items[held]
		if item.kid: impulse *= 0.75
		item.release(at, impulse, str(id))
	elif held.begins_with("player:"):
		var other := int(held.get_slice(":", 1))
		if Game.players.has(other):
			Game.players[other].position = at - Vector3(0, 0.6, 0)
			Game.launch_player(other, impulse)
	if charge >= 0:
		p.violation_until = Game.elapsed + 2
		NoiseBus.emit_noise(p.position, 12, str(id), "throw")

func use_held(id: int) -> void:
	var p: Dictionary = Game.players[id]
	if not items.has(p.held): return
	var item: ClassroomItem = items[p.held]
	if item.kid: return
	var data := item.data
	p.violation_until = Game.elapsed + 2
	if data.food > 0:
		p.eat_until = Game.elapsed + 1.5
		NoiseBus.emit_noise(p.position, data.eating_noise, str(id), data.sound)
		return
	match data.effect:
		"cushion": NoiseBus.emit_noise(p.position, 80, str(id), "fart")
		"gun", "nerf", "knife":
			if item.uses <= 0: return
			if data.effect != "knife": item.uses -= 1
			var origin: Vector3 = p.position + Vector3(0, 1.5, 0)
			var direction := aim_direction(id)
			var distance := 2.2 if data.effect == "knife" else 35.0
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 15, [player_nodes[id].get_rid()]))
			NoiseBus.emit_noise(origin, 150 if data.effect == "gun" else 25, str(id), "gunshot" if data.effect == "gun" else "punch")
			Game.event.rpc("shot", {"position": origin, "end": origin + direction * distance if hit.is_empty() else hit.position})
			if not hit.is_empty(): hit_body(hit.collider, 30 if data.effect != "nerf" else 0, direction * 5 + Vector3.UP * 2, "became a group project casualty")
		"loot_box":
			remove_item(item.entity_id)
			spawn_item(ItemDB.random_item(Game.grade + 1), p.position + Vector3.UP)
		"firework":
			if item.fuse_at > 0: return
			item.fuse_at = Game.elapsed + 3
			item.thrower = str(id)
			Game.event.rpc("banner", {"text": "Firework lit. Three seconds. Throw it!"})

func aim_direction(id: int) -> Vector3:
	var p: Dictionary = Game.players[id]
	return -(Basis(Vector3.UP, p.yaw) * Basis(Vector3.RIGHT, p.pitch)).z

func punch(id: int) -> void:
	var p: Dictionary = Game.players[id]
	var origin: Vector3 = p.position + Vector3(0, 1.4, 0)
	var direction := aim_direction(id)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * 2.2, 15, [player_nodes[id].get_rid()]))
	p.violation_until = Game.elapsed + 1.5
	NoiseBus.emit_noise(origin, 35, str(id), "punch")
	if not hit.is_empty(): hit_body(hit.collider, 3, direction * 7 + Vector3.UP * 3, "lost a playground argument")

func hit_body(body: Node, damage: float, impulse: Vector3, reason: String) -> void:
	if body is StudentPlayer: Game.damage(body.peer_id, damage, reason, impulse)
	elif body is ClassroomItem:
		if body.kid and damage > 20: body.dead = true
		body.release(body.global_position, impulse, "")
	elif body is ClassroomTeacher: body.provoked("", body.global_position)

func buy(id: int, item_id: String) -> void:
	if Game.phase not in ["lobby", "preparation", "break"] or not ItemDB.items.has(item_id): return
	var p: Dictionary = Game.players[id]
	var data: ItemData = ItemDB.get_item(item_id)
	if p.position.distance_to(vending_position) > 4.5 or data.minimum_grade > Game.grade or p.money < data.price: return
	if items.size() >= Game.config.max_loose_items: return
	p.money -= data.price
	var item := spawn_item(item_id, vending_position + Vector3(0, 0.55, -1))
	item.linear_velocity = Vector3(0, 0.5, -2)
	NoiseBus.emit_noise(item.global_position, 25, str(id), "vending_dispense")

func spawn_corpse(id: int, impulse: Vector3) -> void:
	var p: Dictionary = Game.players[id]
	var corpse := spawn_item("rock", p.position + Vector3(0, 0.9, 0), true, true)
	corpse.linear_velocity = impulse
	corpse.angular_velocity = Vector3(3, 1, 2)

func targets() -> Array[String]:
	var result: Array[String] = []
	for id in Game.players:
		if Game.players[id].alive: result.append(str(id))
	for item in items.values():
		if item.kid and not item.dead: result.append(item.entity_id)
	return result

func target_position(id: String) -> Variant:
	if id.is_valid_int() and Game.players.has(int(id)) and Game.players[int(id)].alive: return Game.players[int(id)].position
	if items.has(id) and not items[id].dead: return items[id].global_position - Vector3(0, 0.8, 0)
	return null

func is_violating(id: String) -> bool:
	if id.is_valid_int() and Game.players.has(int(id)):
		var p: Dictionary = Game.players[int(id)]
		return p.mode != "seated" or p.eat_until > Game.elapsed or p.violation_until > Game.elapsed
	return items.has(id) and not items[id].seated

func on_effect(kind: String, data: Dictionary) -> void:
	if kind not in ["burst", "shot"]: return
	var at: Vector3 = data.position
	var color: Color = data.get("color", Color(1, 0.75, 0.1))
	for i in range(10):
		var particle := Greybox.box(self, at, Vector3.ONE * 0.08, color, false)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(particle, "position", at + Vector3(randf_range(-1, 1), randf_range(0, 1.4), randf_range(-1, 1)), 0.4)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.4)
		tween.chain().tween_callback(particle.queue_free)
