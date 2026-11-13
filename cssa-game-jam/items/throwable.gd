class_name ClassroomItem
extends RigidBody3D

var entity_id: String
@export var item_id: String = "apple"
var data: ItemData
var holder: int = 0
var thrower: String = ""
var uses: int = 1
@export var kid: bool = false
var dead: bool = false
var home_seat: int = -1
var seated: bool = false
var noise_at: float = 0
var return_at: float = 0
var fuse_at: float = 0
var last_impact: float = -10
var old_velocity := Vector3.ZERO
var destination := Transform3D.IDENTITY
@onready var label: Label3D = $NameLabel
@onready var visual: Node3D = $Visual

func _ready() -> void:
	data = ItemDB.get_item(item_id)
	uses = data.uses
	mass = 12.0 if kid else data.mass
	freeze = not Game.is_host() or seated
	if kid:
		$CloneVisual.set_color(Color(0.62, 0.65, 0.8) if not dead else Color(0.5, 0.3, 0.4))
	label.text = display_name()
	noise_at = Game.elapsed + randf_range(8, 28)
	destination = global_transform

func display_name() -> String:
	if kid: return "Expired clone" if dead else "Clone student"
	return data.display_name if data else item_id

func _physics_process(delta: float) -> void:
	if Game.is_host() and fuse_at > 0 and Game.elapsed >= fuse_at:
		detonate()
		return
	if holder != 0:
		freeze = true
		collision_layer = 0
		collision_mask = 0
		if Game.world.player_nodes.has(holder):
			global_transform = Game.world.player_nodes[holder].held_transform(kid)
		return
	collision_layer = 8 if kid else 4
	collision_mask = 15
	if not Game.is_host():
		freeze = true
		global_transform = global_transform.interpolate_with(destination, minf(1, delta * 22))
		return
	freeze = seated
	old_velocity = linear_velocity
	if global_position.y < -15:
		Game.world.remove_item(entity_id)
		return
	if not kid or dead: return
	if seated and Game.phase == "class" and Game.elapsed >= noise_at:
		noise_at = Game.elapsed + randf_range(15, 40)
		NoiseBus.emit_noise(global_position, randf_range(18, 35), entity_id, ["sneeze", "chew", "fart"].pick_random())
		if randf() < 0.2:
			seated = false
			freeze = false
			linear_velocity = Vector3(randf_range(-1, 1), 2, 1)
			return_at = Game.elapsed + 5
	if not seated and Game.elapsed >= return_at and linear_velocity.length() < 1.5:
		var seat: int = Game.world.free_seat(home_seat)
		if seat >= 0:
			home_seat = seat
			global_position = Game.world.seat_positions[seat] + Vector3(0, 0.8, 0)
			rotation = Vector3.ZERO
			seated = true
			freeze = true

func detonate() -> void:
	fuse_at = 0
	NoiseBus.emit_noise(global_position, 190, thrower, "firework")
	Game.event.rpc("burst", {"position": global_position, "color": Color.ORANGE})
	for id in Game.players:
		if Game.players[id].position.distance_to(global_position) < 3:
			Game.damage(id, 15, "failed fireworks safety", Vector3.UP * 8)
	Game.world.remove_item(entity_id)

func _impact(body: Node) -> void:
	if not Game.is_host() or holder != 0 or seated: return
	var speed := old_velocity.length()
	if speed < 1.8 or Game.elapsed - last_impact < 0.2: return
	last_impact = Game.elapsed
	# Defer changes to bodies until the physics query has completed.
	resolve_impact.call_deferred(body, speed, old_velocity)

func resolve_impact(body: Node, speed: float, hit_velocity: Vector3) -> void:
	if not is_inside_tree() or not is_instance_valid(body): return
	var loudness := minf(110, (45 if kid else data.impact_noise) * clampf(speed / 7, 0.3, 1.8))
	var sound := "splat" if data.effect == "tomato" and not kid else "impact"
	NoiseBus.emit_noise(global_position, loudness, thrower, sound)
	if thrower != "" and speed > 4 and Game.allowed(0, entity_id + ":impact_log", 1.5):
		var hit_name := "the classroom"
		if body is StudentPlayer: hit_name = Game.actor_name(str(body.peer_id))
		elif body is ClassroomTeacher: hit_name = "the teacher"
		elif body is ClassroomItem: hit_name = body.display_name()
		Game.log_activity("%s's %s hits %s." % [Game.actor_name(thrower), display_name(), hit_name])
	if body is StudentPlayer and str(body.peer_id) != thrower:
		var impulse := hit_velocity.normalized() * minf(12, speed * 0.7) + Vector3.UP * 3
		if not kid and data.effect == "tomato":
			Game.event.rpc("splat", {"id": body.peer_id})
			Game.event.rpc("burst", {"position": global_position, "color": Color.TOMATO})
			Game.world.remove_item(entity_id)
		elif not kid and data.effect == "knife": Game.damage(body.peer_id, 25, "was introduced to cutlery", impulse)
		elif speed > 5: Game.launch_player(body.peer_id, impulse)
	elif body is ClassroomTeacher:
		body.provoked(thrower, global_position)
	if not kid and data.effect == "tomato" and is_inside_tree() and speed > 4:
		Game.event.rpc("burst", {"position": global_position, "color": Color.TOMATO})
		Game.world.remove_item(entity_id)

func pickup(id: int) -> void:
	holder = id
	seated = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0

func release(at: Vector3, impulse: Vector3, source: String) -> void:
	holder = 0
	seated = false
	freeze = false
	collision_layer = 8 if kid else 4
	collision_mask = 15
	global_position = at
	linear_velocity = impulse
	angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	thrower = source
	return_at = Game.elapsed + 6
	last_impact = Game.elapsed

func serialize() -> Dictionary:
	return {"item": item_id, "transform": global_transform, "holder": holder, "kid": kid,
		"dead": dead, "seated": seated, "home": home_seat, "uses": uses}

func receive(state: Dictionary) -> void:
	destination = state.transform
	holder = state.holder
	dead = state.dead
	seated = state.seated
	uses = state.uses
