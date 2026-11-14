class_name ClassroomWorld
extends Node3D

const PLAYER_SCENE := preload("res://characters/player/network_player.tscn")
const KID_SCENE := preload("res://characters/npc/kid.tscn")
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
@onready var menu_camera: Camera3D = $MenuCamera
@onready var bell_origin: Marker3D = $Room/BellSoundOrigin
var grid: AStarGrid2D
var serial: int = 0
var next_food_drop: float = 0.0
@onready var launch_site: Node3D = $LunarLaunchSite
@onready var vending_position: Vector3 = $Hallway/VendingMachine.global_position
@onready var coffee_position: Vector3 = $TeacherDesk/Coffee.global_position

func _enter_tree() -> void:
	Game.world = self

func _ready() -> void:
	if DisplayServer.get_name() != "headless" and Sfx.config.classroom_ambiance != null:
		$AmbiancePlayer.stream = Sfx.config.classroom_ambiance
		$AmbiancePlayer.volume_db = Sfx.config.classroom_ambiance_db
		$AmbiancePlayer.play()
	if DisplayServer.get_name() != "headless":
		Sfx.stream_for_event("mogging") # warm the cache so the first sting does not hitch
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
		var desk_obstacle = desk.get_node("NavigationObstacle")
		mark_obstacle(to_local(desk_obstacle.global_position), desk_obstacle.half_extents)
	var teacher_obstacle = $TeacherDesk/NavigationObstacle
	mark_obstacle(to_local(teacher_obstacle.global_position), teacher_obstacle.half_extents)
	for decor_obstacle in $Decor.find_children("NavigationObstacle", "Marker3D", true, false):
		mark_obstacle(to_local(decor_obstacle.global_position), decor_obstacle.half_extents)
	spawn_positions.append($TeacherDesk/LootSpawn.global_position)
	for node in find_children("*", "StaticBody3D", true, false):
		if node is Interactable: interactions[node.interaction_id] = node
	teacher.board = $TeacherWaypoints/Board.global_position
	teacher.lounge = $TeacherWaypoints/Lounge.global_position
	teacher.desk = $TeacherWaypoints/Desk.global_position
	teacher.global_position = teacher.lounge
	teacher.destination = teacher.lounge
	Game.effect.connect(on_effect)

func mark_obstacle(pos: Vector3, half_size: Vector2) -> void:
	for cell in grid.region.size.x * grid.region.size.y:
		var id := Vector2i(grid.region.position.x + cell % grid.region.size.x, grid.region.position.y + int(cell / float(grid.region.size.x)))
		var point := Vector2(id) * 0.5
		if absf(point.x - pos.x) < half_size.x and absf(point.y - pos.z) < half_size.y: grid.set_point_solid(id)

func walk_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := nearest_walkable(to_local(from))
	var end := nearest_walkable(to_local(to))
	var result := PackedVector3Array()
	for point in grid.get_point_path(start, end): result.append(to_global(Vector3(point.x, 0, point.y)))
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
	if Game.is_host(): update_food_drops()
	var closed := Game.phase == "class"
	door.global_position = $Room/DoorClosedPoint.global_position if closed else $Room/DoorOpenPoint.global_position
	clock.text = "%02d:%02d" % [int(Game.remaining / 60.0), int(Game.remaining) % 60]

func update_food_drops() -> void:
	if Game.phase not in ["preparation", "class"]:
		next_food_drop = 0.0
		return
	if next_food_drop == 0.0:
		next_food_drop = Game.elapsed + food_drop_delay()
	if Game.elapsed < next_food_drop: return
	next_food_drop = Game.elapsed + food_drop_delay()
	if items.size() >= Game.config.max_loose_items: return
	# Drop just above a random living player's head so it is always visible nearby.
	var player_targets: Array = []
	for id in player_nodes:
		if Game.players.has(id) and Game.players[id].alive: player_targets.append(player_nodes[id])
	var point: Vector3
	if player_targets.is_empty():
		var points := $FoodDrops.get_children()
		point = points[randi() % points.size()].global_position
		var scatter := Game.config.food_drop_marker_scatter
		point += Vector3(randf_range(-scatter, scatter), 0, randf_range(-scatter, scatter))
	else:
		var target: Node3D = player_targets[randi() % player_targets.size()]
		# Scatter snacks in front of or behind the player.
		var forward := -target.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		var side := forward.cross(Vector3.UP)
		var distance := Game.config.food_drop_player_distance
		var scatter := Game.config.food_drop_side_scatter
		var along := randf_range(distance.x, distance.y) * (1.0 if randf() < 0.5 else -1.0)
		point = target.global_position + forward * along + side * randf_range(-scatter, scatter)
		var local_point := to_local(point)
		local_point.x = clampf(local_point.x, -8.0, 8.0)
		local_point.z = clampf(local_point.z, -9.0, 7.0)
		local_point.y = 0.3
		point = to_global(local_point)
	var item := spawn_item(ItemDB.random_item(Game.grade, true), point)
	Game.event.rpc("burst", {"position": point, "color": Color.WHITE})
	Game.log_activity("Food dropped from the ceiling: %s." % item.display_name())
	# DEBUG: remove once drops are verified.
	for id in player_nodes:
		var player: Node3D = player_nodes[id]
		print("DROPDEBUG %s at %s | player %d food_dist=%.2f teacher_dist=%.2f" % [item.item_id, point, id,
			player.global_position.distance_to(point), player.global_position.distance_to(teacher.global_position)])

# Collective room hunger: a well-fed room gets fewer free ceiling snacks, which
# pushes players toward the vending machine. A starving room gets drops sooner.
func food_drop_delay() -> float:
	var delay := randf_range(Game.config.food_drop_min_seconds, Game.config.food_drop_max_seconds)
	var total := 0.0
	var living := 0
	for p in Game.players.values():
		if p.alive:
			total += p.stomach
			living += 1
	if living == 0 or Game.config.stomach_max <= 0.0: return delay
	var fullness := clampf(total / (living * Game.config.stomach_max), 0.0, 1.0)
	return delay * lerpf(1.0, Game.config.food_drop_fed_multiplier, fullness)

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
	item.transform = $Items.global_transform.affine_inverse() * state.transform
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
	update_rocket_assembly()

func prepare_class() -> void:
	for id in items.keys():
		var item = items[id]
		if item.holder == 0 and (item.kid or items.size() > int(Game.config.max_loose_items / 2.0)): remove_item(id)
	var npc_spawned := 0
	for seat in range(seat_positions.size() - 1, -1, -1):
		if npc_spawned >= Game.config.npc_count: break
		if free_seat(seat) == seat:
			spawn_item("rock", seat_positions[seat] + Vector3(0, 0.8, 0), true, false, seat)
			npc_spawned += 1
	var count := Game.players.size() * Game.config.food_spawns_per_player + Game.config.base_loot_spawns
	var scatter := Game.config.prep_loot_scatter
	for i in range(count):
		if items.size() >= Game.config.max_loose_items: break
		var point: Vector3 = spawn_positions[i % spawn_positions.size()]
		var height := Game.config.prep_loot_base_height + int(i / float(spawn_positions.size())) * Game.config.prep_loot_stack_height
		point += Vector3(randf_range(-scatter.x, scatter.x), height, randf_range(-scatter.y, scatter.y))
		spawn_item(ItemDB.random_item(Game.grade, i < count - Game.config.mixed_loot_spawns), point)
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
	if p.position.distance_to(at) > Game.config.player.interaction_reach: return
	if not has_reach(id, at): return
	if p.eat_until > Game.elapsed: return
	if target == "rocket_console":
		use_rocket_console(id)
		return
	if target in ItemDB.VENDING_MACHINES:
		if Game.phase in ["lobby", "preparation", "break"]: Game.event.rpc("vending", {"id": id, "machine": target})
		return
	if target == "coffee":
		if Game.phase not in ["lobby", "preparation", "break"]: return
		if items.has(p.held) and items[p.held].data.effect == "drug":
			Game.log_activity("%s adds extra 'decaf' to the teacher's coffee." % p.name)
			remove_item(p.held)
			teacher.drugs = mini(Game.config.teacher.maximum_tablets, teacher.drugs + 1)
			Game.event.rpc("banner", {"text": "Coffee enhanced. Professor X-PEL will be very sleepy."})
		return
	if target.begins_with("seat:"):
		var seat := int(target.get_slice(":", 1))
		if p.mode == "seated" and p.seat == seat:
			Game.handle_action(id, "stand", {})
			return
		for other in Game.players.values():
			if other.seat == seat: return
		if p.held.begins_with("player:"): release_hand(id)
		for item in items.values():
			if item.kid and item.seated and item.home_seat == seat:
				item.release(item.global_position + Vector3.UP, Vector3(1, 4, 2), str(id))
			if item.data.effect == "cushion" and item.global_position.distance_to(at) < Game.config.interactions.cushion_seat_radius:
				NoiseBus.emit_noise(at, Game.config.interactions.cushion_seat_loudness, str(id), "fart")
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
	p.violation_until = Game.elapsed + Game.config.interactions.pickup_violation_seconds
	NoiseBus.emit_noise(p.position, Game.config.interactions.pickup_loudness, str(id), "pickup")

## Non-positional victory sting. Ducks the room ambiance while it plays; silent without a clip.
func play_mogging() -> void:
	if DisplayServer.get_name() == "headless" or $MoggingPlayer.playing: return
	var stream := Sfx.stream_for_event("mogging")
	if stream == null: return
	$MoggingPlayer.stream = stream
	$MoggingPlayer.play()
	var ambiance: AudioStreamPlayer = $AmbiancePlayer
	var base_db := Sfx.config.classroom_ambiance_db
	var tween := create_tween()
	tween.tween_property(ambiance, "volume_db", base_db - 10.0, 0.2)
	tween.tween_interval(maxf(stream.get_length() - 0.2, 0.0))
	tween.tween_property(ambiance, "volume_db", base_db, 0.6)

func update_rocket_assembly() -> void:
	launch_site.apply_assembly(Game.installed_rocket_parts, Game.rocket_launch_started_at, Game.elapsed)

func use_rocket_console(id: int) -> void:
	var player: Dictionary = Game.players[id]
	if Game.rocket_launch_started_at >= 0.0:
		Game.event.rpc("rocket_console", {"id": id, "text": "Falcon 9 has already launched."})
		return
	if Game.rocket_parts == ItemDB.FALCON_STOCK.size() and player.held.is_empty():
		Game.rocket_launch_started_at = Game.elapsed
		update_rocket_assembly()
		Game.event.rpc("banner", {"text": "Falcon 9 ignition. Stand clear of the launch pad!"})
		Game.event.rpc("mogging", {})
		return
	var item: ClassroomItem = items.get(player.held)
	if item == null or item.holder != id or item.item_id not in ItemDB.FALCON_STOCK:
		Game.event.rpc("rocket_console", {"id": id, "text": "Hold a Falcon 9 part to install it."})
		return
	if item.item_id in Game.installed_rocket_parts:
		Game.event.rpc("rocket_console", {"id": id, "text": "%s is already installed." % item.data.display_name})
		return
	var part_name := item.data.display_name
	Game.installed_rocket_parts.append(item.item_id)
	remove_item(item.entity_id)
	update_rocket_assembly()
	var status := "%s installed • %d/%d parts" % [part_name, Game.rocket_parts, ItemDB.FALCON_STOCK.size()]
	if Game.rocket_parts == ItemDB.FALCON_STOCK.size():
		status += " • Press E with an empty hand to launch"
	Game.event.rpc("banner", {"text": status})

func has_reach(id: int, at: Vector3) -> bool:
	var eye: Vector3 = Game.players[id].position + Vector3(0, 1.40 if Game.players[id].mode == "seated" else 1.55, 0)
	var dir := (at - eye)
	var dist := dir.length()
	if dist <= 0.1: return true
	var target_check := eye + dir.normalized() * maxf(0.0, dist - 0.08)
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target_check, 1)).is_empty()

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
	var tuning := Game.config.interactions
	var impulse := direction * tuning.item_drop_speed
	if charge >= 0:
		impulse = direction * (tuning.item_throw_speed + charge * tuning.item_throw_charge_bonus) + Vector3.UP * tuning.item_throw_lift
	var at: Vector3 = p.position + Vector3(0, 1.4, 0) + direction * 0.8
	if items.has(held):
		var item = items[held]
		if item.kid: impulse *= tuning.clone_throw_scale
		item.release(at, impulse, str(id))
	elif held.begins_with("player:"):
		var other := int(held.get_slice(":", 1))
		if Game.players.has(other):
			Game.players[other].position = at - Vector3(0, 0.6, 0)
			var throw_impulse := direction * tuning.player_drop_speed + Vector3.UP
			if charge >= 0:
				var lift := tuning.player_throw_lift + charge * tuning.player_throw_lift_charge_bonus
				throw_impulse = direction * (tuning.player_throw_speed + charge * tuning.player_throw_charge_bonus) + Vector3.UP * lift
			Game.launch_player(other, throw_impulse)
	if charge >= 0:
		Game.log_activity("%s throws %s!" % [p.name, held_name])
		p.violation_until = Game.elapsed + tuning.throw_violation_seconds
		NoiseBus.emit_noise(p.position, tuning.throw_loudness, str(id), "throw")

func use_held(id: int) -> void:
	var p: Dictionary = Game.players[id]
	if not items.has(p.held): return
	var item: ClassroomItem = items[p.held]
	if item.kid: return
	var data := item.data
	var tuning := Game.config.interactions
	p.violation_until = Game.elapsed + tuning.use_violation_seconds
	if data.food > 0:
		Game.log_activity("%s starts eating %s. Subtlety not included." % [p.name, data.display_name])
		p.eat_until = Game.elapsed + tuning.eat_seconds
		NoiseBus.emit_noise(p.position, data.eating_noise, str(id), data.sound)
		return
	match data.effect:
		"cushion": NoiseBus.emit_noise(p.position, tuning.cushion_use_loudness, str(id), "fart")
		"gun", "nerf", "knife":
			if item.uses <= 0: return
			Game.log_activity("%s uses %s!" % [p.name, data.display_name])
			if data.effect != "knife": item.uses -= 1
			var origin: Vector3 = p.position + Vector3(0, 1.5, 0)
			var direction := aim_direction(id)
			var distance := tuning.knife_reach if data.effect == "knife" else tuning.gun_range
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 15, [player_nodes[id].get_rid()]))
			NoiseBus.emit_noise(origin, tuning.gun_loudness if data.effect == "gun" else tuning.weapon_other_loudness, str(id), "gunshot" if data.effect == "gun" else "punch")
			Game.event.rpc("shot", {"position": origin, "end": origin + direction * distance if hit.is_empty() else hit.position})
			if not hit.is_empty():
				var damage := tuning.nerf_damage if data.effect == "nerf" else tuning.weapon_damage
				var impulse := direction * tuning.weapon_impulse + Vector3.UP * tuning.weapon_lift
				hit_body(hit.collider, damage, impulse, "became a group project casualty")
		"loot_box":
			Game.log_activity("%s opens a mystery lunchbox." % p.name)
			remove_item(item.entity_id)
			spawn_item(ItemDB.random_item(Game.grade + 1), p.position + Vector3.UP)
		"firework":
			if item.fuse_at > 0: return
			Game.log_activity("%s lights an INDOOR firework. Excellent judgement." % p.name)
			item.fuse_at = Game.elapsed + tuning.firework_fuse
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
	var tuning := Game.config.interactions
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * tuning.punch_reach, 15, [player_nodes[id].get_rid()]))
	p.violation_until = Game.elapsed + tuning.pickup_violation_seconds
	NoiseBus.emit_noise(origin, tuning.punch_loudness, str(id), "punch")
	if not hit.is_empty():
		var impulse := direction * tuning.punch_impulse + Vector3.UP * tuning.punch_lift
		hit_body(hit.collider, tuning.punch_damage, impulse, "lost a playground argument")

func hit_body(body: Node, damage: float, impulse: Vector3, reason: String) -> void:
	if body is StudentPlayer: Game.damage(body.peer_id, damage, reason, impulse)
	elif body is ClassroomItem:
		if body.kid and damage > Game.config.interactions.clone_lethal_damage: body.dead = true
		body.release(body.global_position, impulse, "")
	elif body is ClassroomTeacher: body.provoked("", body.global_position)

func buy(id: int, item_id: String, machine_id: String = "vending") -> void:
	if Game.phase not in ["lobby", "preparation", "break"] or not ItemDB.sells(item_id, machine_id): return
	if not interactions.has(machine_id): return
	var p: Dictionary = Game.players[id]
	var data: ItemData = ItemDB.get_item(item_id)
	var machine: Node3D = interactions[machine_id].get_parent()
	if p.position.distance_to(machine.global_position) > Game.config.interactions.vending_reach or p.money < data.price: return
	if items.size() >= Game.config.max_loose_items: return
	p.money -= data.price
	Game.log_activity("%s buys %s for ₿%d." % [p.name, data.display_name, data.price])
	var dispense_point: Marker3D = machine.get_node("DispensePoint")
	var item := spawn_item(item_id, dispense_point.global_position)
	NoiseBus.emit_noise(item.global_position, Game.config.interactions.vending_loudness, str(id), "vending_dispense")

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
			at += Vector3.UP * (1.40 if data.get("seated", false) else 1.55) + direction * 0.35
		elif key == "fart": at += Vector3.UP * 0.65 - direction * 0.25
		elif key == "footstep": at += Vector3.UP * 0.08
	elif kind == "shot":
		scene = SHOT_SCENE
		direction = (data.end - at).normalized()
		if teacher and teacher.global_position.distance_to(at) < 3.0:
			teacher.actual_shot_fired = true
	elif kind == "burst":
		scene = SPLAT_SCENE if data.get("color", Color.WHITE) == Color.TOMATO else BURST_SCENE
	else: return
	# Effects are purely local presentation of a host-authoritative event.
	# Bound their count during physics pile-ups; never add noise from particles.
	if $Effects.get_child_count() >= Game.config.active_effect_limit: return
	var burst: Node3D = scene.instantiate()
	burst.position = at
	$Effects.add_child(burst)
	burst.global_position = at
	if direction.length_squared() > 0.01:
		var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
		burst.look_at(at + direction, up)
