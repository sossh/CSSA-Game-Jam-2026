class_name ClassroomWorld
extends Node3D

const PLAYER_SCENE := preload("res://player/network_player.tscn")
const KID_SCENE := preload("res://npc/kid.tscn")
const BURST_SCENE := preload("res://effects/impact_burst.tscn")
const PARTICLE_SCENES := {
	"chew": preload("res://effects/eating.tscn"),
	"crunch": preload("res://effects/eating.tscn"),
	"slurp": preload("res://effects/eating.tscn"),
	"can_open": preload("res://effects/burp.tscn"),
	"burp": preload("res://effects/burp.tscn"),
	"sneeze": preload("res://effects/burp.tscn"),
	"fart": preload("res://effects/fart.tscn"),
	"footstep": preload("res://effects/footstep.tscn"),
	"pop_rocks": preload("res://effects/pop_rocks.tscn"),
	"impact": BURST_SCENE,
	"splat": preload("res://effects/tomato_splat.tscn"),
	"punch": BURST_SCENE,
	"firework": preload("res://effects/pop_rocks.tscn"),
	"vending_dispense": BURST_SCENE,
}
const SHOT_SCENE := preload("res://effects/shot.tscn")
const SPLAT_SCENE := preload("res://effects/tomato_splat.tscn")

var player_nodes: Dictionary = {}
var items: Dictionary = {}
var interactions: Dictionary = {}
var seat_positions: Array[Vector3] = []
var spawn_positions: Array[Vector3] = []
@onready var teacher: ClassroomTeacher = $Teacher
@onready var door: Node3D = $Room/Door
@onready var clock: Label3D = $Room/Clock
@onready var rocket_label: Label3D = $Hallway/RocketPad/ScoreLabel
@onready var rocket_visual: Node3D = $Hallway/RocketPad/Parts
@onready var menu_camera: Camera3D = $MenuCamera
var grid: AStarGrid2D
var serial: int = 0
var last_rocket_count: int = -1
@onready var vending_position: Vector3 = $Hallway/VendingMachine.global_position
@onready var coffee_position: Vector3 = $TeacherDesk/Coffee.global_position
@onready var rocket_position: Vector3 = $Hallway/RocketPad.global_position

func _enter_tree() -> void:
	Game.world = self

func _ready() -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(-16, -18, 33, 34)
	grid.cell_size = Vector2(0.5, 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for desk in $Desks.get_children():
		var seat: Interactable = desk.get_node("Seat")
		seat.interaction_id = "seat:" + str(seat_positions.size())
		seat_positions.append(desk.get_node("SitPoint").global_position)
		for marker: Marker3D in desk.get_node("LootSpawns").get_children():
			spawn_positions.append(marker.global_position)
		var obstacle = desk.get_node("NavigationObstacle")
		mark_obstacle(obstacle.global_position, obstacle.half_extents)
	var obstacle = $TeacherDesk/NavigationObstacle
	mark_obstacle(obstacle.global_position, obstacle.half_extents)
	spawn_positions.append($TeacherDesk/LootSpawn.global_position)
	for node in find_children("*", "StaticBody3D", true, false):
		if node is Interactable: interactions[node.interaction_id] = node
	teacher.board = $TeacherWaypoints/Board.global_position
	teacher.lounge = $TeacherWaypoints/Lounge.global_position
	teacher.global_position = teacher.lounge
	teacher.destination = teacher.lounge
	Game.effect.connect(on_effect)

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
	var points := $Hallway/TransferChute/SpawnPoints.get_children()
	return points[posmod(index, points.size())].global_position

func _physics_process(_delta: float) -> void:
	if Net.active: ensure_players()
	var closed := Game.phase == "class"
	door.global_position = $Room/DoorClosedPoint.global_position if closed else $Room/DoorOpenPoint.global_position
	clock.text = "%02d:%02d" % [int(Game.remaining) / 60, int(Game.remaining) % 60]
	rocket_label.text = "CLASS ESCAPE FUND\n%d ROCKET PARTS" % Game.rocket_parts
	if last_rocket_count != Game.rocket_parts:
		last_rocket_count = Game.rocket_parts
		for i in range(rocket_visual.get_child_count()):
			rocket_visual.get_child(i).visible = i < Game.rocket_parts

func ensure_players() -> void:
	for id in Game.players:
		if not player_nodes.has(id):
			var player: StudentPlayer = PLAYER_SCENE.instantiate()
			player.peer_id = id
			player.name = "Player%d" % id
			$Players.add_child(player)
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
	var scene: PackedScene = KID_SCENE if state.kid else ItemDB.get_item(state.item).scene
	var item: ClassroomItem = scene.instantiate()
	item.entity_id = entity_id
	item.name = entity_id.replace(":", "_")
	item.item_id = state.item
	item.kid = state.kid
	item.dead = state.dead
	item.seated = state.seated
	item.home_seat = state.home
	item.transform = state.transform
	$Items.add_child(item)
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
	spawn_item("drug", $Hallway/StarterSpawns/Drug.global_position)
	spawn_item("tomato", $Hallway/StarterSpawns/Tomato.global_position)

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
			Game.log_activity("%s adds extra 'decaf' to the teacher's coffee." % p.name)
			remove_item(p.held)
			teacher.drugs = mini(3, teacher.drugs + 1)
			Game.event.rpc("banner", {"text": "Coffee enhanced. Professor X-PEL will be very sleepy."})
		return
	if target == "rocket":
		if items.has(p.held) and items[p.held].data.effect == "rocket":
			Game.log_activity("%s donates a rocket part to the escape fund." % p.name)
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
		Game.log_activity("%s sits down. Suspiciously innocent." % p.name)
		return
	if p.held != "": return
	if items.has(target):
		var item = items[target]
		if item.holder != 0: return
		item.pickup(id)
		p.held = target
		Game.log_activity("%s grabs %s." % [p.name, item.display_name()])
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
		Game.log_activity("%s picks up %s. Friendship is now luggage." % [p.name, other.name])
	p.violation_until = Game.elapsed + 1.5
	NoiseBus.emit_noise(p.position, 10, str(id), "pickup")

func has_reach(id: int, at: Vector3) -> bool:
	var eye: Vector3 = Game.players[id].position + Vector3(0, 1.55, 0)
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at, 1)).is_empty()

func release_hand(id: int, charge: float = -1) -> void:
	if not Game.players.has(id): return
	var p: Dictionary = Game.players[id]
	var held: String = p.held
	var held_name := ""
	if items.has(held): held_name = items[held].display_name()
	elif held.begins_with("player:"): held_name = Game.actor_name(held.get_slice(":", 1))
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
		Game.log_activity("%s throws %s!" % [p.name, held_name])
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
		Game.log_activity("%s starts eating %s. Subtlety not included." % [p.name, data.display_name])
		p.eat_until = Game.elapsed + 1.5
		NoiseBus.emit_noise(p.position, data.eating_noise, str(id), data.sound)
		return
	match data.effect:
		"cushion": NoiseBus.emit_noise(p.position, 80, str(id), "fart")
		"gun", "nerf", "knife":
			if item.uses <= 0: return
			Game.log_activity("%s uses %s!" % [p.name, data.display_name])
			if data.effect != "knife": item.uses -= 1
			var origin: Vector3 = p.position + Vector3(0, 1.5, 0)
			var direction := aim_direction(id)
			var distance := 2.2 if data.effect == "knife" else 35.0
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 15, [player_nodes[id].get_rid()]))
			NoiseBus.emit_noise(origin, 150 if data.effect == "gun" else 25, str(id), "gunshot" if data.effect == "gun" else "punch")
			Game.event.rpc("shot", {"position": origin, "end": origin + direction * distance if hit.is_empty() else hit.position})
			if not hit.is_empty(): hit_body(hit.collider, 30 if data.effect != "nerf" else 0, direction * 5 + Vector3.UP * 2, "became a group project casualty")
		"loot_box":
			Game.log_activity("%s opens a mystery lunchbox." % p.name)
			remove_item(item.entity_id)
			spawn_item(ItemDB.random_item(Game.grade + 1), p.position + Vector3.UP)
		"firework":
			if item.fuse_at > 0: return
			Game.log_activity("%s lights an INDOOR firework. Excellent judgement." % p.name)
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
	Game.log_activity("%s throws hands." % p.name)
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
	Game.log_activity("%s buys %s for ₿%d." % [p.name, data.display_name, data.price])
	var item := spawn_item(item_id, $Hallway/VendingMachine/DispensePoint.global_position)
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
	var scene: PackedScene
	var at: Vector3 = data.get("position", Vector3.ZERO)
	var direction: Vector3 = data.get("direction", Vector3.FORWARD)
	if kind == "sound":
		var key: String = data.key
		scene = PARTICLE_SCENES.get(key)
		if scene == null: return
		if key in ["chew", "crunch", "slurp", "can_open", "burp", "sneeze", "pop_rocks"]:
			at += Vector3.UP * (1.15 if data.get("seated", false) else 1.55) + direction * 0.35
		elif key == "fart": at += Vector3.UP * 0.65 - direction * 0.25
		elif key == "footstep": at += Vector3.UP * 0.08
	elif kind == "shot":
		scene = SHOT_SCENE
		direction = (data.end - at).normalized()
	elif kind == "burst":
		scene = SPLAT_SCENE if data.get("color", Color.WHITE) == Color.TOMATO else BURST_SCENE
	else: return
	# Effects are purely local presentation of a host-authoritative event.
	# Bound their count during physics pile-ups; never add noise from particles.
	if $Effects.get_child_count() >= 100: return
	var burst: Node3D = scene.instantiate()
	$Effects.add_child(burst)
	burst.global_position = at
	if direction.length_squared() > 0.01:
		var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
		burst.look_at(at + direction, up)
